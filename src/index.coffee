express = require 'express'
path = require 'path'
logger = require 'morgan'
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
dbConfig = require "#{__dirname}/config/db.json"

# MySQL Connection
mysqlConn = mysql.createConnection "mysql://#{dbConfig.mysql.user}:#{dbConfig.mysql.pass}@#{dbConfig.mysql.host}:#{dbConfig.mysql.port}/#{dbConfig.mysql.database}"
mysqlConn.connect()

# MongoDB Connection
mongoConnectArr = []
for mongo in dbConfig.mongo
  mongoConnectArr.push "mongodb://#{mongo.user}:#{mongo.pass}@#{mongo.host}:#{mongo.port}/#{mongo.database}"
mongoose.connect mongoConnectArr.join(',')

# Load MongoDB Models
MemberModel = require "./models/member"
# End MongoDB Models
passport = require "#{__dirname}/config/passport.coffee"

app = express()

app.set 'port', process.env.PORT || 3030
app.use compression()
app.use logger('dev')
app.use session
  secret: 'SESSION_SECRET_KEY'
  resave: true
  saveUninitialized: true
  store: memoryStore
app.use bodyParser.json()
app.use bodyParser.urlencoded
  extended: true
app.use cookieParser()
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
io.use (socket, next)-> sessionBinder cookieParser, memoryStore, socket, next
io.use passport.socket(errorParser)

# Socket Connection
io.on 'connection', (socket)->
  console.log 'User Connected.'
  socket.on 'error', (err)->
    console.log 'Socket Error:', err
  socket.on 'disconnect', ->
    console.log 'Client disconnected.'
server.listen app.get('port'), ->
  console.log "Express API server listening on port #{server.address().port}"
