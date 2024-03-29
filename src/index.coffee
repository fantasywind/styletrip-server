try
  require "#{__dirname}/config/env.coffee"
catch e
  console.error "Warn: Cannot load env setting file."

express = require 'express'
path = require 'path'
logger = require 'morgan'
chalk = require 'chalk'
cookieParser = require 'cookie-parser'
session = require 'express-session'
errorhandler = require 'errorhandler'
csrf = require 'csurf'
favicon = require 'serve-favicon'
compression = require 'compression'
bodyParser = require 'body-parser'
mongoose = require 'mongoose'
mysql = require 'mysql'
socketIO = require 'socket.io'
errorParser = require 'error-message-parser'
memoryStore = new session.MemoryStore
sessionBinder = require "#{__dirname}/lib/session.binder"

# MySQL Connection
mysqlConn = mysql.createConnection "mysql://#{process.env.MYSQL_USER}:#{process.env.MYSQL_PASS}@#{process.env.MYSQL_HOST}:#{process.env.MYSQL_PORT}/#{process.env.MYSQL_DATABASE}"
mysqlConn.connect()

# MongoDB Connection
mongoose.connect "mongodb://#{process.env.MONGO_USER}:#{process.env.MONGO_PASS}@#{process.env.MONGO_HOST}:#{process.env.MONGO_PORT}/#{process.env.MONGO_DATABASE}"

mongoose.connection.on 'connected', (e)->
  console.log chalk.gray "MongoDB connected."

mongoose.connection.on 'error', (e)->
  console.error chalk.red "MongoDB connect error: #{e}"

# Load MongoDB Models
MemberModel = require "./models/member"
ScheduleModel = require "./models/schedule"
# End MongoDB Models

passport = require "#{__dirname}/lib/passport.coffee"
st = require "#{__dirname}/lib/styletrip"
stEngine = new st.Connection
  port: process.env.ENGINE_PORT
  host: process.env.ENGINE_HOST
stMember = new st.Member passport

app = express()
sessionSecret = process.env.SESSION_SECRET or 'SESSION_SECRET_KEY'

app.set 'port', process.env.PORT || 3030
app.use compression()
app.use logger('dev')
app.use cookieParser()
app.use sessionBinder.http
app.use session
  secret: sessionSecret
  resave: true
  saveUninitialized: true
  store: memoryStore
app.use bodyParser.json()
app.use bodyParser.urlencoded
  extended: true
app.use passport.initialize()
app.use passport.session()
app.use csrf()
app.use favicon("#{__dirname}/public/favicon.ico")
app.use express.static(path.join(__dirname, 'public'))
app.use errorParser.Parser
  cwd: "#{__dirname}/errorMessages"
  lang: 'zh-TW'

# Passport Middleware
app.use '/auth', passport.router

app.get '/csrf', (req, res)->
  try
    token = req.csrfToken()
    res.json
      status: true
      token: token
  catch e
    res.sendError 1

app.use '/', (req, res)->
  res.json
    status: true
    msg: 'api server is running'

app.use (req, res, next)->
  err = new Error 'Not Found'
  err.status = 404
  next err

if app.get('env') is 'development'
  app.use errorhandler()
  app.use (err, req, res, next)->
    res.status err.status or 500
    res.render 'error',
      message: err.message
      error: err

app.use (err, req, res, next)->
  res.status err.status or 500
  res.render 'error',
    message: err.message
    error: {}


server = require('http').Server app
io = socketIO server

# Bind Session
io.use (socket, next)-> sessionBinder.socket cookieParser, memoryStore, sessionSecret, socket, next
io.use stMember.socketBinder()
io.use st.scheduleRequestBind stEngine
io.use (socket, next)-> socket.sessionStore.set socket.sessionID, socket.session, -> next()

# Socket Connection
io.on 'connection', (socket)->
  console.log 'User Connected.'
  socket.on 'error', (err)->
    console.log 'Socket Error:', err
  socket.on 'disconnect', ->
    console.log 'Client disconnected.'
server.listen app.get('port'), ->
  console.log "Express API server listening on port #{server.address().port}"
