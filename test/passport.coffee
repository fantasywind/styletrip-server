TEST_MONGO = process.env.TEST_MONGO
request = require 'supertest'
express = require 'express'
cookieParser = require 'cookie-parser'
session = require 'express-session'
errorParser = require 'error-message-parser'
bodyParser = require 'body-parser'
should = require 'should'
sessionSecret = 'TESTER_SESSION_SECRET_KEY'
memoryStore = new session.MemoryStore
Member = require "../src/models/member.coffee"
mongoose = require 'mongoose'
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

describe 'passport-router', ->
  req = null

  beforeEach ->
    app = express()
    app.use cookieParser()
    app.use session
      secret: sessionSecret
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

  describe '/updateToken', ->

    it 'should response error when empty body', (done)->
      req
        .post '/updateToken'
        .expect 200
        .end (err, res)->
          throw err if err

          errObj = errorParser.generateError 408

          res.body.should.have.properties
            status: false
            code: 408
            level: errObj.level
            message: errObj.message

          done()

    it 'should response error when session not found', (done)->
      req
        .post '/updateToken'
        .send
          sid: 'sessionidforunittest'
        .expect 200
        .end (err, res)->
          throw err if err

          errObj = errorParser.generateError 406

          res.body.should.have.properties
            status: false
            code: 406
            level: errObj.level
            message: errObj.message

          done()

    it 'should response error when session token missing', (done)->
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
          .post '/updateToken'
          .send
            sid: sessionId
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

    it 'should response error when session token expired', (done)->
      sessionId = 'sessionidforunittest'
      memoryStore.set sessionId,
        token: 'logintokenforunittest'
        expires: Date.now() - 10
        cookie: 
            originalMaxAge: null
            expires: null
            httpOnly: true
            path: '/'
      , (err)->
        throw err if err

        req
          .post '/updateToken'
          .send
            sid: sessionId
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

    it 'should temporarily token session will be clean', (done)->
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

        req
          .post '/updateToken'
          .send
            sid: sessionId
          .expect 200
          .end (err, res)->
            throw err if err

            res.body.should.have.property 'status', true

            memoryStore.get sessionId, (err, session)->

              should.not.exist err
              should.not.exist session

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

        req
          .post '/updateToken'
          .send
            sid: sessionId
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

  describe '/failed', ->

    it 'should route /failed redirect to /?err=facebookLogin', (done)->
      req
        .get '/failed'
        .expect 'Location', '/?err=facebookLogin'
        .expect 302
        .end (err, res)->
          throw err if err

          done()