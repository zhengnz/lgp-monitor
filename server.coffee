hprose = require 'hprose'
_ = require 'lodash'
events = require 'events'
Promise = require 'bluebird'
exec = require('child_process').exec
pm2 = require 'pm2'
fs = require 'fs'
os = require 'os'
Promise.promisifyAll pm2

class Server
  constructor: ->
    @push_recorder = {} #保存日志推送的app
    @server = new hprose.HttpService()
    @server.add {
      get_app_list: @get_app_list.bind @ #获取app列表
      reload: @reload_app.bind @ #重载
      restart: @restart_app.bind @ #重启
      git: @git.bind @ #pull git
      git_rollback: @git_rollback.bind @ #git回滚到指定版本
      get_git_commits: @get_git_commits.bind @ #获取git历史
      client_exit: @client_exit.bind @
    }
    @init_publish() #初始化各app日志推送监听
    @server.publish 'console' #开启操作日志推送

    @forbid_restart = false
    process.on 'SIGINT', =>
      @forbid_restart = true
      _.each _.keys(@push_recorder), (name) =>
        @end_push_log name

  cmd: (msg, cwd=__dirname) ->
    new Promise (resolve, reject) ->
      exec msg, {cwd: cwd}, (err, stdout, stderr) ->
        if err
          return reject err
        resolve [stdout, stderr]

  true_app_list: ->
    pm2.listAsync().then (list) ->
      Promise.resolve _.filter list, (l) ->
        l.name isnt 'lgp-monitor'

  get_git_version: (path) ->
    @cmd "cd #{path} && git rev-parse HEAD"
    .spread (stdout, stderr) ->
      if stderr
        return Promise.reject new Error stderr
      Promise.resolve stdout

  get_git_source: (path) ->
    @cmd "cd #{path} && git config --get remote.origin.url"
    .spread (stdout, stderr) ->
      if stderr
        return Promise.reject new Error stderr
      Promise.resolve stdout

  get_app_list: (has_cwd=false) ->
    @true_app_list()
    .then (apps) =>
      Promise.map apps, (app) =>
        path = app.pm2_env.pm_cwd
        new Promise (resolve, reject) ->
          fs.exists "#{path}/.git", (exists) ->
            obj = {
              name: app.name
              git: exists
              mode: app.pm2_env.exec_mode
            }
            if _.has app.pm2_env.env, 'MONITOR_GROUP'
              obj.group = app.pm2_env.env.MONITOR_GROUP
            if has_cwd is on
              #has_cwd指定为true是返回包含目录的object，安全性措施
              obj.cwd = path
            resolve obj
        .then (obj) =>
          if not obj.git
            obj.git_version = ''
            Promise.resolve obj
          else
            Promise.all [
              @get_git_version path
              @get_git_source path
            ]
            .then (results) ->
              [version, source] = results
              obj.git_version = version
              obj.git_source = source
              Promise.resolve obj

  start_push_log: (name) ->
    if @push_recorder[name].cmd is null
      @console "开始输出#{name}的日志"
    cmd = exec "pm2 logs #{name}"
    cmd.stdout.on 'data', (data) =>
      @server.push name, data
    cmd.on 'exit', =>
      if @server.idlist(name) > 0 and @forbid_restart is off
        @start_push_log name
      else
        @push_recorder[name].cmd = null
    @push_recorder[name].cmd = cmd

  end_push_log: (name) ->
    if @push_recorder[name].cmd?
      @console "结束输出#{name}的日志"
      if os.platform() is 'win32'
        exec "taskkill /pid #{@push_recorder[name].cmd.pid} /T /F"
      else
        @push_recorder[name].cmd.kill()

  init_publish: ->
    @true_app_list()
    .then (apps) =>
      _.map apps, (app) =>
        name = app.name
        @push_recorder[name] = {
          pushing: false
          cmd: null
        }
        push_events = new events.EventEmitter()
        push_events.on 'subscribe', (id, context) =>
          if @push_recorder[name].pushing is on
            return
          @push_recorder[name].pushing = true
          @start_push_log name

        push_events.on 'unsubscribe', (id, context) =>
          @console "#{id}退订，剩余#{@server.idlist(name).length}个客户端"
          if @server.idlist(name).length is 0
            @push_recorder[name].pushing = false
            @end_push_log name

        @server.publish name, {events: push_events}

  client_exit: (name) ->
    @server.push name, 'CLIENT EXIT'
    true

  console: (msg) ->
    @server.push 'console', "#{msg}\n"

  reload_app: (name) ->
    @console "重载#{name}中，请稍等..."
    pm2.reloadAsync name
    .then =>
      @console "重载#{name}完成"
      Promise.resolve()

#    new Promise (resolve, reject) =>
#      @console "重载#{name}中，请稍等..."
#      pm2.reload name, (err) =>
#        if err
#          return reject err
#        @console "重载#{name}完成"
#        resolve()

  restart_app: (name) ->
    @console "重启#{name}中，请稍等..."
    pm2.restartAsync name
    .then =>
      @console "重启#{name}完成"
      Promise.resolve()

#    new Promise (resolve, reject) =>
#      @console "重启#{name}中，请稍等..."
#      pm2.restart name, (err) =>
#        if err
#          return reject err
#        @console "重启#{name}完成"
#        resolve()

  get_git_path: (name) ->
    @get_app_list(true)
    .then (apps) =>
      new Promise (resolve, reject) =>
        app = _.find apps, (_app) ->
          _app.name is name and _app.git is on
        if app is undefined
          reject new Error '无匹配的应用'
        resolve app.cwd

  git: (name) ->
    path = null
    @get_git_path name
    .then (p) =>
      path = p
      cmd = 'git pull -u origin master'
      @console "开始git同步, 目录: #{path}"
      @console cmd
      @cmd cmd, path
    .spread (stdout, stderr) =>
      @console stderr
      @console stdout
      @get_git_version path

  get_git_commits: (name) ->
    @get_git_path name
    .then (path) =>
      format = '{\\"id\\": \\"%H\\", \\"msg\\": \\"%s\\", \\"time\\": \\"%cd\\"}'
      @cmd "cd #{path} && git log --pretty=format:\"#{format}\" -10"
    .spread (stdout, stderr) =>
      if stderr
        return Promise.reject new Error stderr
      arr = _.split stdout, /\n/g
      arr = _.filter arr, (obj) ->
        obj isnt ''
      arr = _.map arr, (obj) ->
        JSON.parse obj
      Promise.resolve arr

  git_rollback: (name, commit_id) ->
    @console "#{name}开始回滚到#{commit_id}"
    path = null
    @get_git_path name
    .then (p) =>
      path = p
      @cmd "cd #{path} && git reset --hard #{commit_id}"
    .spread (stdout, stderr) =>
      @console stderr
      @console stdout
      @get_git_version path
    .then (version) =>
      @console "#{name}当前版本: #{version}"
      Promise.resolve version

  start: ->
    @server.start()

module.exports = Server