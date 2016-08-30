ko.bindingHandlers.trigger = {
  init: (element, valueAccessor) ->
    $(element).click ->
      value = valueAccessor()
      value !value()
      false
}

ko.bindingHandlers.textBottom = {
  update: (element, valueAccessor) ->
    value = valueAccessor()
    txt = ko.unwrap value
    e = $(element).parent()
    $(element).text txt
    e.scrollTop e[0].scrollHeight
}

class commitModel
  constructor: (@parent, @data) ->
    ko.mapping.fromJS @data, {}, @

  rollback: ->
    if confirm("确认回滚到#{@id()}?") and @parent.parent.loading() is off
      $('#commits').modal 'hide'
      @parent.parent.loading true
      @parent.parent.client.git_rollback @parent.name(), @id()
      .then (version) =>
        alert '回滚操作完成，详情请看操作日志'
        @parent.git_version version
      .catch (err) ->
        alert '发生错误，请查看控制台'
        console.log err
      .whenComplete =>
        @parent.parent.loading false

class appModel
  constructor: (@parent, @data) ->
    ko.mapping.fromJS @data, {}, @
    @log = ko.observable ''
    @output = ko.observable ''
    @pause = ko.observable false
    @pause.subscribe (v) =>
      if v is off
        @output @log()

    @log.subscribe (v) =>
      if @pause() is off
        @output v

    @show_log = ko.observable false

    @show_log.subscribe (v) =>
      if v is on
        @parent.client.subscribe @name(), (data) =>
          if data isnt 'CLIENT EXIT'
            @log "#{@log()}#{data}"
      else
        @parent.client.unsubscribe @name()
        @parent.client.client_exit @name()

  show: ->
    _.each @parent.app_list(), (app) ->
      app.show_log false
    @show_log true
    @parent.view_app @

  reload: ->
    if @parent.loading() is on
      return
    @parent.loading true
    @parent.client.reload @name()
    .catch (err) ->
      alert '发生错误，请查看控制台'
      console.log err
    .whenComplete =>
      @parent.loading false

  restart: ->
    if @parent.loading() is on
      return
    @parent.loading true
    @parent.client.restart @name()
    .catch (err) ->
      alert '发生错误，请查看控制台'
      console.log err
    .whenComplete =>
      @parent.loading false

  pull: ->
    if @parent.loading() is on
      return
    @parent.loading true
    @parent.client.git @name()
    .then (version) =>
      @git_version version
    .catch (err) ->
      alert '发生错误，请查看控制台'
      console.log err
    .whenComplete =>
      @parent.loading false

  list_commit: ->
    if @parent.loading() is on
      return
    @parent.loading true
    @parent.client.get_git_commits @name()
    .then (rows) =>
      @parent.commits _.map rows, (row) =>
        new commitModel @, row
      $('#commits').modal 'show'
    .catch (err) ->
      alert '发生错误，请查看控制台'
      console.log err
    .whenComplete =>
      @parent.loading false

  clear_log: ->
    @log ''

class viewModel
  constructor: ->
    @client = new hprose.Client.create "/api", [
      'get_app_list'
      'reload'
      'restart'
      'git'
      'get_git_commits'
      'git_rollback'
      'client_exit'
    ]

    @app_list = ko.observableArray []
    @view_app = ko.observable null
    @view_app.subscribe (v) ->
      if v?
        setTimeout ->
          $('.ui.dropdown').dropdown {
            on: 'hover'
            action: 'hide'
          }
        , 300

    @list_loading = ko.observable true
    @loading = ko.observable false

    @commits = ko.observableArray []
    @get_app_list()

    @log = ko.observable('欢迎使用lgp-monitor\n')
    @client.subscribe 'console', (data) =>
      @log "#{@log()}#{data}"

  get_app_list: ->
    @client.get_app_list()
    .then (rows) =>
      @app_list _.map rows, (row) =>
        new appModel @, row
    .catch (err) =>
      alert '发生错误，请查看控制台'
      console.log err
    .whenComplete =>
      @list_loading false

  refresh_list: ->
    if @list_loading() is on
      return
    @list_loading true
    @app_list []
    @get_app_list()

$ ->
  ko.applyBindings new viewModel()
  $('.ko-hide').removeClass 'ko-hide'