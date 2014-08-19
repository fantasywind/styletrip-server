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
querystring = require 'querystring'
originPassport = require 'passport'
clearDB = require('mocha-mongoose') TEST_MONGO

passport = require "#{__dirname}/../src/lib/passport"
FacebookWrapper = require "#{__dirname}/../src/lib/passport-facebook"

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

  describe 'facebook strategy GET /facebook/callback', ->

    it 'should redirect to correct facebook oauth page', (done)->
      req
        .get '/facebook/callback'
        .expect 302
        .end (err, res)->
          throw err if err

          unescape(res.headers.location).should.match /^https:\/\/www\.facebook\.com\/dialog\/oauth\?(.*)/
          qs = querystring.parse RegExp.$1
          qs.should.have.properties
            response_type: 'code'
            redirect_uri: 'http://sys.infinitibeat.com/auth/facebook/callback'
            client_id: '287808734725360'

          done()

  describe 'facebook strategy wrapper callback', ->
    facebookWrapper = null
    accessToken = 'iamaccesstoken'
    refreshToken = 'iamrefreshtoken'

    beforeEach ->
      facebookWrapper = new FacebookWrapper originPassport

    it 'should facebook wrapper function exported', ->
      facebookWrapper.callback.should.be.a.Function
      facebookWrapper.done.should.be.a.Function

    it 'should facebook wrapper done function export error', (done)->
      error = new Error 'Test Error'
      next = facebookWrapper.done {}, (err, member)->
        err.should.be.an.Error
        err.toString().should.be.equal error.toString()
        done()
      next error

    it 'should facebook wrapper return created member when session member is missing and find exists facebook account', (done)->
      req =
        session: {}
      profile =
        id: 238571040192
      member = new Member
        facebookID: profile.id
      member.save (err, member)->
        throw err if err

        facebookWrapper.callback req, accessToken, refreshToken, profile, (err, member)->
          should.not.exist err
          member.facebookID.should.be.equal '238571040192'
          done()

    it 'should facebook wrapper return combine exists member when session member is missing and find exists facebook account', (done)->
      req =
        session:
          member:
            guest: false
      profile =
        id: 238571040192
      member = new Member
        facebookID: profile.id
      member.save (err, member)->
        throw err if err

        facebookWrapper.callback req, accessToken, refreshToken, profile, (err, newMember)->
          should.not.exist err
          member._id.toString().should.be.equal newMember._id.toString()
          newMember.facebookID.should.be.equal '238571040192'
          done()

    it 'should facebook wrapper combine guest member when find exists facebook account', (done)->
      req =
        session:
          member:
            guest: true
      profile =
        id: 2385710412323
      member = new Member
        facebookID: 2385710412323
      member.save (err, member)->
        throw err if err

        guest = new Member
          guest: true
        guest.save (err, guest)->
          req.session.member._id = guest._id

          facebookWrapper.callback req, accessToken, refreshToken, profile, (err, newMember)->
            should.not.exist err
            member._id.toString().should.be.equal newMember._id.toString()
            done()

    it 'should create a new member when cannot find a match facebook account without combind if session member is undefined', (done)->
      req =
        session: {}
      profile =
        id: 2385710412323
        displayName: 'iamdisplayname'
      
      facebookWrapper.callback req, accessToken, refreshToken, profile, (err, newMember)->
        should.not.exist err
        newMember.facebookID.should.be.equal profile.id.toString()
        newMember.facebookAccessToken.should.be.equal accessToken
        newMember.name.should.be.equal profile.displayName
        done()

    it 'should create a new member and combined guest data when cannot find a match facebook account', (done)->
      req =
        session:
          member:
            guest: true
      profile =
        id: 2385710412323
        displayName: 'iamdisplayname'
      guest = new Member
        guest: true
        scheduleHistory: ['1d3', 'ywer']
      guest.save (err, guest)->
        throw err if err
        req.session.member._id = guest._id
      
        facebookWrapper.callback req, accessToken, refreshToken, profile, (err, newMember)->
          should.not.exist err
          newMember.facebookID.should.be.equal profile.id.toString()
          newMember.facebookAccessToken.should.be.equal accessToken
          newMember.name.should.be.equal profile.displayName
          newMember.scheduleHistory.should.containEql '1d3'
          newMember.scheduleHistory.should.containEql 'ywer'
          newMember.scheduleHistory.should.not.containEql '1d3a'
          done()

    it 'should create a new member when cannot find a match facebook account but match a exist member with matched email', (done)->
      req =
        session: {}
      profile =
        id: 2385710412323
        displayName: 'iamdisplayname'
        email: 'sample@abc.com'
      member = new Member
        email: 'sample@abc.com'
        name: 'defaultName'
        scheduleHistory: ['1d3', 'ywer']
      member.save (err, member)->
        throw err if err
        facebookWrapper.callback req, accessToken, refreshToken, profile, (err, newMember)->
          should.not.exist err
          newMember.facebookID.should.be.equal profile.id.toString()
          newMember.facebookAccessToken.should.be.equal accessToken
          newMember.name.should.be.equal 'defaultName'
          done()

    it 'should combind guest when get invalid email and cannot find a match facebook account but match a exist member with matched email', (done)->
      req =
        session:
          member:
            guest: true
      profile =
        id: 2385710412323
        displayName: 'iamdisplayname'
        email: 'sample@abc.com'
      member = new Member
        email: 'sample@abc.com'
        scheduleHistory: ['1d3', 'ywer']
      member.save (err, member)->
        throw err if err
        guest = new Member
          guest: true
        guest.save (err, guest)->
          throw err if err

          req.session.member._id = guest._id
          facebookWrapper.callback req, accessToken, refreshToken, profile, (err, newMember)->
            should.not.exist err
            newMember.facebookID.should.be.equal profile.id.toString()
            newMember.facebookAccessToken.should.be.equal accessToken
            newMember.name.should.be.equal profile.displayName
            done()

    it 'should create member when facebook account matched and email matched member not found', (done)->
      req =
        session:
          member:
            guest: true
      profile =
        id: 2385710412323
        displayName: 'iamdisplayname'
        email: 'sample123@abc.com'
      member = new Member
        email: 'sample@abc.com'
        scheduleHistory: ['1d3', 'ywer']
      member.save (err, member)->
        throw err if err
        guest = new Member
          guest: true
        guest.save (err, guest)->
          throw err if err

          req.session.member._id = guest._id
          facebookWrapper.callback req, accessToken, refreshToken, profile, (err, newMember)->
            should.not.exist err
            newMember.facebookID.should.be.equal profile.id.toString()
            newMember.facebookAccessToken.should.be.equal accessToken
            newMember.name.should.be.equal profile.displayName
            done()

