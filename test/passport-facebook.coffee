# get env
try
  require "#{__dirname}/support/env"
catch e
  console.log 'Not Found: env.js'

TEST_MONGO = process.env.TEST_MONGO or 'mongodb://test:test@localhost/test'
SESSION_SECRET = process.env.SESSION_SECRET or 'sEcReT4un1ttest'
async = require 'async'
request = require 'supertest'
express = require 'express'
cookieParser = require 'cookie-parser'
session = require 'express-session'
errorParser = require 'error-message-parser'
bodyParser = require 'body-parser'
should = require 'should'
memoryStore = new session.MemoryStore
Member = require "../src/models/member"
signature = require 'cookie-signature'
mongoose = require 'mongoose'
clearDB = require('mocha-mongoose') TEST_MONGO

passport = require "#{__dirname}/../src/lib/passport"

describe 'passport-facebook', ->
  req = null
  sessionCached = null

  beforeEach (done)->
    # server
    app = express()
    app.use cookieParser()
    app.use session
      secret: SESSION_SECRET
      resave: true
      saveUninitialized: true
      store: memoryStore
    app.use bodyParser.json()
    app.use bodyParser.urlencoded
      extended: true
    app.use passport.initialize()
    app.use passport.session()
    app.use errorParser.Parser
      cwd: "#{__dirname}/../src/errorMessages"
      lang: 'zh-TW'
    app.use (req, res, next)->
      sessionCached = req.session
      next()
    app.use passport.router
    req = request app

    # mongoose
    return done() if mongoose.connection.db
    mongoose.connect TEST_MONGO, done

  describe 'facebook strategy GET /facebook', ->

    it 'should redirect to facebook login page', (done)->
      req
        .get '/facebook'
        .expect 302
        .expect 'Location', 'https://www.facebook.com/dialog/oauth?response_type=code&redirect_uri=http%3A%2F%2Fsys.infinitibeat.com%2Fauth%2Ffacebook%2Fcallback&scope=email%2Cuser_tagged_places%2Cuser_location%2Cuser_friends%2Cuser_hometown%2Cuser_interests%2Cuser_likes%2Cuser_birthday&client_id=287808734725360'
        .end (err, res)->
          throw err if err

          done()

  ###
  describe 'facebook strategy GET /facebook/callback', ->

    it 'should ', (done)->
      req
        .get '/facebook/callback'
        .expect 302
        #.expect 'Location'
        .end (err, res)->
          throw err if err

          console.log res.headers.location
          done()
  ###