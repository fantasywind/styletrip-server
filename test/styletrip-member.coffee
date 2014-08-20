# get env
try
  require "#{__dirname}/support/env"
catch e
  console.log 'Not Found: env.js'

TEST_MONGO = process.env.TEST_MONGO or 'mongodb://test:test@localhost/test'
should = require 'should'
sinon = require 'sinon'
mongoose = require 'mongoose'
Member = require "../src/models/member"
clearDB = require('mocha-mongoose') TEST_MONGO
EventEmitter = require('events').EventEmitter

passport = require "#{__dirname}/../src/lib/passport"
passportGenerateGuestOriginal = passport.generateGuest
passportGenerateGuestHooker = {}
passport.generateGuest = ->
  if passportGenerateGuestHooker.fn
    passportGenerateGuestHooker.fn.apply null, arguments
  else
    passportGenerateGuestOriginal.apply passport, arguments
styletripMember = require "#{__dirname}/../src/lib/styletrip-member"

describe 'styletrip member', ->

  it 'should styletrip member exports functions', ->
    styletripMember.Controller.should.be.a.Function

  describe 'Class: StyletripMemberController', ->

    describe '#contructor()', ->

      it 'should first arguments assign to passport', ->
        testPassport = {}
        controller = new styletripMember.Controller testPassport
        controller.passport.should.be.equal testPassport

      it 'should prototype function exists', ->
        controller = new styletripMember.Controller
        controller.socketBinder.should.be.a.Function
        controller.cookieLogin.should.be.a.Function
        controller.generateGuest.should.be.a.Function
        controller._onLoginStatus.should.be.a.Function

    describe '#socketBinder()', ->

      it 'should return a function', ->
        controller = new styletripMember.Controller
        controller.socketBinder().should.be.a.Function

      it 'should bind socket handler loginStatus with return function', (done)->
        socket = new EventEmitter
        spySocket = sinon.spy socket, 'on'

        controller = new styletripMember.Controller
        controller.socketBinder() socket, ->
          spySocket.calledWithMatch('loginStatus').should.be.true
          done()

    describe '#_onLoginStatus()', ->
      controller = socket = null

      beforeEach (done)->
        controller = new styletripMember.Controller
        socket = new EventEmitter
        socket.handshake =
          headers:
            cookie: ''
        socket.session = {}

        # mongoose
        return done() if mongoose.connection.db
        mongoose.connect TEST_MONGO, done

      it 'should emit logined when session find', (done)->
        socket.session.user =
          name: 'testUserName'
          facebookID: '397047146234'

        socket.on 'logined', (data)->
          data.name.should.be.equal 'testUserName'
          data.facebookID.should.be.equal '397047146234'
          done()

        controller._onLoginStatus socket

      it 'should generate guest when session member not found', ->
        # hook generateGuest
        controller.generateGuest = ->
        spyGenerateGuest = sinon.spy controller, 'generateGuest'
        controller._onLoginStatus socket

        spyGenerateGuest.calledWith(socket).should.be.true

      it 'should do login and throw error if session passport exist but session user id is fake', (done)->
        socket.session.member = {}
        socket.session.passport =
          user: 'iamfakeuserid'

        socket.on 'failed', (data)->
          data.should.have.properties
            status: false
            code: 401
            level: 3
            message: '伺服器資料庫錯誤。 (CastError: Cast to ObjectId failed for value "iamfakeuserid" at path "_id")'

          done()

        controller._onLoginStatus socket

      it 'should do login and throw error if session passport exist but session user id is not found', (done)->
        socket.session.member = {}
        socket.session.passport =
          user: new mongoose.Types.ObjectId

        socket.on 'failed', (data)->
          data.should.have.properties
            status: false
            code: 402
            level: 2
            message: '找不到會員資料。'

          done()

        controller._onLoginStatus socket

      it 'should do login if session passport exist', (done)->

        member = new Member
          name: 'testUser'
          facebookID: '185729753'
        member.save (err, member)->
          throw err if err
          socket.session.member = {}
          socket.session.passport =
            user: member._id

          socket.on 'logined', (data)->
            data.should.have.properties
              name: member.name
              facebookID: member.facebookID

            done()

          controller._onLoginStatus socket

      it 'should login with cookie and generateGuest when session member not found and cookie token exist but cookie token failed', (done)->
        # hooks
        controller.cookieLogin = (token, session, next)->
          next new Error

        controller.generateGuest = ->
          done()

        spyCookieLogin = sinon.spy controller, 'cookieLogin'
        memberToken = 'wef900923rf8932hwafA2Wf'
        socket.handshake.headers.cookie = "token=#{memberToken}; path=/; HttpOnly"

        controller._onLoginStatus socket
        spyCookieLogin.calledWithMatch memberToken, socket.session

      it 'should login with cookie and saving to session when session member not found and cookie token exist', (done)->
        # hooks
        controller.cookieLogin = (token, session, next)->
          next null

        spyCookieLogin = sinon.spy controller, 'cookieLogin'
        memberToken = 'wef900923rf8932hwafA2Wf'
        socket.handshake.headers.cookie = "token=#{memberToken}; path=/; HttpOnly"
        socket.sessionID = 'socketSessionID'
        socket.sessionStore =
          set: (sessionID, session)->
            sessionID.should.be.equal socket.sessionID
            session.should.be.equal socket.session
            done()

        controller._onLoginStatus socket
        spyCookieLogin.calledWithMatch memberToken, socket.session

    describe '#cookieLogin()', ->
      controller = null

      beforeEach (done)->
        controller = new styletripMember.Controller

        # mongoose
        return done() if mongoose.connection.db
        mongoose.connect TEST_MONGO, done

      it 'should interrupt if token is undefined', ->
        controller.cookieLogin().should.be.false

      it 'should set session when cookie token find correct member', (done)->
        session = {}
        memberToken = 'wa9fau230jawef2t'
        member = new Member
          token:
            secret: memberToken
            expires: Date.now() + 2000
        member.save (err, member)->
          throw err if err

          controller.cookieLogin memberToken, session, (err)->
            should.not.exist err
            session.member.token.secret.should.be.equal memberToken

            done()

      it 'should throw error when cookie token cannot not find correct member', (done)->
        session = {}
        memberToken = 'wa9fau230jawef2t'
        member = new Member
          token:
            secret: memberToken
            expires: Date.now() - 1
        member.save (err, member)->
          throw err if err

          controller.cookieLogin memberToken, session, (err)->
            err.toString().should.be.equal "Error: Not Found"

            done()

    describe '#generateGuest()', ->
      controller = socket = null

      beforeEach (done)->
        controller = new styletripMember.Controller
        socket = new EventEmitter
        socket.session = {}

        # clear hooker
        delete passportGenerateGuestHooker.fn

        # mongoose
        return done() if mongoose.connection.db
        mongoose.connect TEST_MONGO, done

      it 'should throw error if passport generateGuest failed', (done)->
        # hooks
        passportGenerateGuestHooker.fn = (next)->
          next new Error 'Test Error'

        socket.on 'failed', (data)->
          data.should.have.properties
            status: false
            code: 401
            level: 3
            message: '伺服器資料庫錯誤。 (Error: Test Error)'
          done()

        controller.generateGuest socket

      it 'should set session if passport generateGuest generated guest', (done)->
        memberToken = 'afj903jgj0flk3jwe'
        expires = Date.now()

        # hooks
        passportGenerateGuestHooker.fn = (next)->
          next null,
            token:
              secret: memberToken
              expires: expires

        socket.sessionID = 'socketSessionID'
        socket.sessionStore = 
          set: (sessionID, session, next)->
            sessionID.should.be.equal socket.sessionID
            session.should.be.equal socket.session
            next()
        socket.on 'guestLogined', (data)->
          data.sid.should.be.equal 'socketSessionID'
          done()

        controller.generateGuest socket
