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

class appModel
  constructor: (@parent, @data) ->
    ko.mapping.fromJS @data, {}, @
    @log = ko.observable('')
    @show_log = ko.observable false

    @show_log.subscribe (v) =>
      if v is on
        @parent.client.subscribe @name(), (data) =>
          @log "#{@log()}#{data}"
      else
        @parent.client.unsubscribe @name()

    @reloading = ko.observable false
    @restarting = ko.observable false
    @pulling = ko.observable false

  reload: ->
    if @reloading() is on
      return
    @reloading true
    @parent.client.reload @name()
    .catch (err) ->
      alert '发生错误，请查看控制台'
      console.log err
    .whenComplete =>
      @reloading false

  restart: ->
    if @restarting() is on
      return
    @restarting true
    @parent.client.restart @name()
    .catch (err) ->
      alert '发生错误，请查看控制台'
      console.log err
    .whenComplete =>
      @restarting false

  pull: ->
    if @pulling() is on
      return
    @pulling true
    @parent.client.git @name()
    .then (version) =>
      @git_version version
    .catch (err) ->
      alert '发生错误，请查看控制台'
      console.log err
    .whenComplete =>
      @pulling false

  clear_log: ->
    @log ''

class viewModel
  constructor: ->
    @client = new hprose.Client.create "/api", [
      'get_app_list'
      'reload'
      'restart'
      'git'
    ]

    @app_list = ko.observableArray []
    @list_loading = ko.observable true
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