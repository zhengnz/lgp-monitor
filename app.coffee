pmx = require 'pmx'
express = require 'express'
pm2 = require 'pm2'
Server = require './server'

probe = pmx.probe()

conf = pmx.initModule {
  widget:
    type: 'generic'
    logo: 'http://www.creativetechs.com/iq/tip_images/TerminalApp-Icon.png'

    theme: ['#111111', '#1B2228', '#807C7C', '#807C7C']

    el:
      probes: false
      actions: false

    block:
      actions: false
      issues: false
      meta: false
      cpu: false
      mem: false
      main_probes : ['Port']
}

probe.metric {
  name: 'Port'
  value: ->
    conf.port
}

session_opts = {
  key: 'lgp-monitor'
  secret: '$W%VDwe3r4wf#$EQ'
  resave: true
  saveUninitialized: true
  cookie: {maxAge: 86400 * 1000 * 7}
}

app = express()
app.set 'views', "#{__dirname}/views"
app.set 'view engine', 'jade'
app.use '/static', express.static "#{__dirname}/static"
app.use cookieParser()
app.use session session_opts
app.use bodyParser.urlencoded {extended: false}
app.use bodyParser.json()

app.get '/', (req, res) ->
  res.render 'index'

pm2.connect (err) ->
  if err
    return console.error err.stack or err

  server = new Server()
  app.use '/api', server.server.handle

app.listen conf.port