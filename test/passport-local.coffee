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

describe 'passport-local', ->

  describe 'local strategy', ->
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

    it 'should redirect to /api/auth/failed when member not found', (done)->
      member = new Member
        email: 'test@infinitibeat.com'
      member.password = member.hashPassword 'dontlook'

      member.save (err, member)->
        throw err if err

        req
          .post '/local'
          .send
            username: 'boss@infinitibeat.com'
            password: 'wrongpass'
          .expect 302
          .expect 'Location', '/api/auth/failed'
          .end (err, res)->
            throw err if err

            done()

    it 'should redirect to /api/auth/failed when member password invalid', (done)->
      member = new Member
        email: 'test@infinitibeat.com'
      member.password = member.hashPassword 'dontlook'

      member.save (err, member)->
        throw err if err

        req
          .post '/local'
          .send
            username: 'test@infinitibeat.com'
            password: 'wrongpass'
          .expect 302
          .expect 'Location', '/api/auth/failed'
          .end (err, res)->
            throw err if err

            done()

    it 'should redirect to /api/auth/failed when parameter invalid', (done)->
      req
        .post '/local'
        .expect 302
        .expect 'Location', '/api/auth/failed'
        .end (err, res)->
          throw err if err

          done()


    it 'should redirect /api/auth/success if logined', (done)->
      member = new Member
        email: 'right@infinitibeat.com'
      member.password = member.hashPassword 'dontlook'

      member.save (err, member)->
        throw err if err

        req
          .post '/local'
          .send
            username: 'right@infinitibeat.com'
            password: 'dontlook'
          .expect 302
          .expect 'Location', '/api/auth/success'
          .end (err, res)->
            throw err if err

            sessionCached.should.have.property 'passport'
            sessionCached.passport.user.should.be.equal member._id.toString()

            done()

    it 'should combined guest account and clean it', (done)->
      sessionCached = null

      guest = new Member
        guest: true
        scheduleHistory: [
          'schedulea'
          'testHistory'
        ]

      member = new Member
        email: 'existed@infinitibeat.com'
      member.password = member.hashPassword 'dontlook'

      # save sync
      async.parallel
        guest: (cb)-> guest.save cb
        member: (cb)-> member.save cb
      , (err, results)->
        throw err if err

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
          req.session.member = results.guest[0]
          sessionCached = req.session
          next()
        app.use passport.router
        req = request app

        req
          .post '/local'
          .send
            username: 'existed@infinitibeat.com'
            password: 'dontlook'
          .expect 302
          .expect 'Location', '/api/auth/success'
          .end (err, res)->
            throw err if err

            
            sessionCached.should.have.property 'passport'
            sessionCached.passport.user.should.be.equal member._id.toString()
            
            
            checkClear = (cb)->
              Member.findById results.guest[0]._id, (err, guest)->
                throw err if err

                should.not.exist guest
                cb()

            checkScheduleCombine = (cb)->
              Member.findById results.member[0]._id, (err, member)->
                throw err if err

                should.exist member
                member.scheduleHistory.should.containEql 'schedulea'
                member.scheduleHistory.should.containEql 'testHistory'
                cb()

            async.parallel
              clear: checkClear
              combind: checkScheduleCombine
            , (err, results)->
              throw err if err

              done()

    it 'should overwrite login account', (done)->
      sessionCached = null

      anotherMember = new Member
        scheduleHistory: [
          'schedulea'
          'testHistory'
        ]

      member = new Member
        email: 'existed@infinitibeat.com'
      member.password = member.hashPassword 'dontlook'

      # save sync
      async.parallel
        anotherMember: (cb)-> anotherMember.save cb
        member: (cb)-> member.save cb
      , (err, results)->
        throw err if err

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
          req.session.member = results.anotherMember[0]
          sessionCached = req.session
          next()
        app.use passport.router
        req = request app

        req
          .post '/local'
          .send
            username: 'existed@infinitibeat.com'
            password: 'dontlook'
          .expect 302
          .expect 'Location', '/api/auth/success'
          .end (err, res)->
            throw err if err

            sessionCached.should.have.property 'passport'
            sessionCached.passport.user.should.be.equal member._id.toString()
            
            done()