express = require 'express'
pm2 = require 'pm2'
cookieParser = require 'cookie-parser'
session = require 'express-session'
bodyParser = require 'body-parser'

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

module.exports = app