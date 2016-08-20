hprose = require 'hprose'
_ = require 'lodash'
events = require 'events'
Promise = require 'bluebird'
exec = require('child_process').exec
pm2 = require 'pm2'
fs = require 'fs'

class Server
  constructor: ->
    @push_recorder = {}
    @server = new hprose.HttpService()
    @server.add {
      get_app_list: @get_app_list.bind @
      reload: @reload_app.bind @
      restart: @restart_app.bind @
      git: @git.bind @
    }
    @init_publish()
    @server.publish 'console'

  true_app_list: ->
    new Promise (resolve, reject) ->
      pm2.list (err, list) ->
        if err
          return reject err
        resolve _.filter list, (l) ->
          l.name isnt 'lgp-monitor'

  get_app_list: (has_cwd=false) ->
    @true_app_list()
    .then (apps) ->
      Promise.map apps, (app) ->
        path = app.pm2_env.pm_cwd
        new Promise (resolve, reject) ->
          fs.exists "#{path}/.git", (exists) ->
            obj = {
              name: app.name
              git: exists
              mode: app.pm2_env.exec_mode
            }
            if has_cwd is on
              obj.cwd = path
            resolve obj
        .then (obj) ->
          if not obj.git
            obj.git_version = ''
            return Promise.resolve obj
          else
            new Promise (resolve, reject) ->
              cmd = exec "cd #{path} && git rev-parse HEAD"
              version = ''
              cmd.stdout.on 'data', (data) ->
                version += data
              cmd.on 'exit', ->
                obj.git_version = version
                resolve obj

  start_push_log: (name) ->
    @console "开始输出#{name}的日志"
    cmd = exec "pm2 logs #{name}"
    cmd.stdout.on 'data', (data) =>
      @server.push name, data
    @push_recorder[name].cmd = cmd

  end_push_log: (name) ->
    if @push_recorder[name].cmd?
      @console "结束输出#{name}的日志"
      @push_recorder[name].cmd.kill()
      @push_recorder[name].cmd = null

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

  console: (msg) ->
    @server.push 'console', "#{msg}\n"

  reload_app: (name) ->
#    new Promise (resolve, reject) =>
#      @console "重载#{name}中，请稍等..."
#      pm2.reload name, (err) =>
#        if err
#          return reject err
#        @console "重载#{name}完成"
#        resolve()

    new Promise (resolve, reject) =>
      cmd = exec "pm2 reload #{name}"
      cmd.stdout.on 'data', (data) =>
        @console data
      cmd.on 'exit', ->
        resolve()

  restart_app: (name) ->
    new Promise (resolve, reject) =>
      @console "重启#{name}中，请稍等..."
      pm2.restart name, (err) =>
        if err
          return reject err
        @console "重启#{name}完成"
        resolve()

  git: (name) ->
    @get_app_list(true)
    .then (apps) =>
      new Promise (resolve, reject) =>
        app = _.find apps, (_app) ->
          _app.name is name and _app.git is on
        if app is undefined
          reject new Error '无匹配的应用'
        cmd = exec "cd #{app.cwd} && git pull -u origin master"
        cmd.stdout.on 'data', (data) =>
          @console data
        cmd.on 'exit', ->
          resolve()

  start: ->
    @server.start()

module.exports = Server