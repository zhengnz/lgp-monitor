pmx = require 'pmx'


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

probe.metric {
  name: 'website'
  value: ->
    conf.website or "#{__dirname}/website.js"
}

app = require conf.website

pm2.connect (err) ->
  if err
    return console.error err.stack or err

  server = new Server()
  app.use '/api', server.server.handle

app.listen conf.port