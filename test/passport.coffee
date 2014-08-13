# get env
try
  require "#{__dirname}/support/env"
catch e
  console.log 'Not Found: env.js'

TEST_MONGO = process.env.TEST_MONGO or 'mongodb://test:test@localhost/test'
SESSION_SECRET = process.env.SESSION_SECRET or 'sEcReT4un1ttest'
request = require 'supertest'
express = require 'express'
sinon = require 'sinon'
cookieParser = require 'cookie-parser'
session = require 'express-session'
errorParser = require 'error-message-parser'
bodyParser = require 'body-parser'
should = require 'should'
memoryStore = new session.MemoryStore
MemberModel = require "../src/models/member"
mongoose = require 'mongoose'
signature = require 'cookie-signature'
Member = mongoose.model 'Member'
clearDB = require('mocha-mongoose') TEST_MONGO

passport = require "#{__dirname}/../src/lib/passport"

describe 'passport', ->

  describe '#serializeUser()', ->
    it 'should serializeUser return user id', (done)->
      user =
        id: 123
      passport.serializeUser user, (err, userId)->
        should.not.exist err
        userId.should.be.equal user.id
        done()

    it 'should serializeUser return user _id when user.id is undefined', (done)->
      user =
        _id: 123
      passport.serializeUser user, (err, userId)->
        should.not.exist err
        userId.should.be.equal user._id
        done()

  describe '#deserializeUser()', ->

    beforeEach (done)->
      return done() if mongoose.connection.db
      mongoose.connect TEST_MONGO, done

    userId = new mongoose.Types.ObjectId

    it 'should deserializeUser return false when not found', (done)->
      passport.deserializeUser userId, (err, user)->
        should.not.exist err
        user.should.be.false
        done()

    it 'should deserializeUser find correct user id', (done)->
      guest = new Member
        _id: userId
      guest.save (err, member)->
        throw err if err

        passport.deserializeUser userId, (err, user)->
          should.not.exist err
          user._id.toString().should.be.equal userId.toString()
          done()

  describe '#generateGuest()', ->

    beforeEach (done)->
      return done() if mongoose.connection.db
      mongoose.connect TEST_MONGO, done

    it 'should #generateGuest() generate guest member', (done)->
      passport.generateGuest (err, member)->
        should.not.exist err
        member.guest.should.be.true
        member.token.secret.should.be.type 'string'
        new Date(member.token.expires).toString().should.not.equal 'Invalid Date'
        done()

    it 'should log error when guest member saving to database failed', (done)->

      # Hook for model error
      Member.prototype._save = Member.prototype.save
      Member.prototype.save = (cb)->
        cb 'save member document error', this

      spyLog = sinon.spy console, 'log'

      passport.generateGuest (err, member)->
        should.exist err
        spyLog.calledOnce.should.be.true

        spyLog.restore()

        # Clean Hook
        Member.prototype.save = Member.prototype._save
        delete Member.prototype._save
        done()
      

describe 'passport-router', ->
  req = null
  app = null

  beforeEach ->
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
    app.use errorParser.Parser
      cwd: "#{__dirname}/../src/errorMessages"
      lang: 'zh-TW'
    app.use passport.router
    req = request app

  describe 'POST /local', ->

    it 'should bind to passport strategy', (done)->
      hooker =
        name: 'local'
        authenticate: (req, options)->
          this.redirect 302, '/api/auth/failed'

      spyStrategy = sinon.spy hooker, 'authenticate'
      passport.use hooker

      req
        .post '/local'
        .expect 302
        .expect 'Location', '/api/auth/failed'
        .end (err, res)->
          throw err if err

          spyStrategy.calledOnce.should.be.true

          done()

  describe 'GET /facebook', ->

    it 'should bind to passport strategy', (done)->
      hooker =
        name: 'facebook'
        authenticate: (req, options)->
          this.redirect 302, '/api/auth/failed'

      spyStrategy = sinon.spy hooker, 'authenticate'
      passport.use hooker

      req
        .get '/facebook'
        .expect 302
        .expect 'Location', '/api/auth/failed'
        .end (err, res)->
          throw err if err

          spyStrategy.calledOnce.should.be.true

          done()

  describe 'GET /facebook/callback', ->

    it 'should bind to passport strategy', (done)->
      hooker =
        name: 'facebook'
        authenticate: (req, options)->
          this.redirect 302, '/api/auth/failed'

      spyStrategy = sinon.spy hooker, 'authenticate'
      passport.use hooker

      req
        .get '/facebook/callback'
        .expect 302
        .expect 'Location', '/api/auth/failed'
        .end (err, res)->
          throw err if err

          spyStrategy.calledOnce.should.be.true

          done()

  describe 'GET /success', ->

    it 'should response error when user session is missing', (done)->
      req
        .get '/success'
        .expect 200
        .end (err, res)->
          throw err if err

          errObj = errorParser.generateError 407

          res.body.should.have.properties 
            status: false
            code: 407
            level: errObj.level
            message: errObj.message

          done()

    it 'should generate and save user token to database, store in cookie and redirect to /?facebookLogined=success', (done)->
      # Spy member
      member = new Member
      spySave = sinon.spy member, 'save'
      
      # Hook express
      app = express()
      app.use errorParser.Parser
        cwd: "#{__dirname}/../src/errorMessages"
        lang: 'zh-TW'
      app.use (req, res, next)->
        req.user = member
        next()
      app.use passport.router

      req = request app

      req
        .get '/success'
        .expect 302
        .expect 'Location', '/?facebookLogined=success'
        .end (err, res)->
          throw err if err

          spySave.calledOnce.should.be.true

          should.exist res.header['set-cookie']

          setCookie = false
          for cookie in res.header['set-cookie']
            if cookie.match /^token/g
              cookie.should.match /^token=.*; Path=\/; Expires=.*; HttpOnly$/g
              setCookie = true

          setCookie.should.be.true

          done()

    it 'should response error when user token store failed', (done)->
      # Spy member
      member = new Member
      member._save = member.save
      member.save = (cb)->
        cb 'iamerroronmodelsaving', this

      # Hook express
      app = express()
      app.use errorParser.Parser
        cwd: "#{__dirname}/../src/errorMessages"
        lang: 'zh-TW'
      app.use (req, res, next)->
        req.user = member
        next()
      app.use passport.router

      req = request app

      req
        .get '/success'
        .expect 200
        .end (err, res)->
          throw err if err

          errObj = errorParser.generateError 407

          res.body.should.have.properties 
            status: false
            code: 407
            level: errObj.level
            message: errObj.message

          done()

  describe 'GET /updateToken', ->

    it 'should response error when session member token missing', (done)->
      sessionId = 'sessionidforunittest'
      memoryStore.set sessionId,
        token: null
        cookie: 
            originalMaxAge: null
            expires: null
            httpOnly: true
            path: '/'
      , (err)->
        throw err if err

        req
          .get '/updateToken'
          .expect 200
          .end (err, res)->
            throw err if err

            errObj = errorParser.generateError 407

            res.body.should.have.properties 
              status: false
              code: 407
              level: errObj.level
              message: errObj.message

            done()

    it "should token will be set on user's cookie", (done)->
      sessionId = 'sessionidforunittest'
      memoryStore.set sessionId,
        token: 'logintokenforunittest'
        expires: Date.now() + 2000
        cookie: 
          originalMaxAge: null
          expires: null
          httpOnly: true
          path: '/'
      , (err)->
        throw err if err

        signedSessionId = signature.sign(sessionId, SESSION_SECRET)
        req
          .get '/updateToken'
          .set 'Cookie', ["connect.sid=s:#{signedSessionId}"]
          .expect 200
          .end (err, res)->
            throw err if err

            res.body.should.have.property 'status', true
            should.exist res.header['set-cookie']

            setCookie = false
            for cookie in res.header['set-cookie']
              if cookie.match /^token/g
                cookie.should.match /^token=logintokenforunittest; Path=\/; Expires=.*; HttpOnly$/g
                setCookie = true

            setCookie.should.be.true

            done()

  describe 'GET /failed', ->

    it 'should route /failed redirect to /?err=facebookLogin', (done)->
      req
        .get '/failed'
        .expect 'Location', '/?err=facebookLogin'
        .expect 302
        .end (err, res)->
          throw err if err

          done()