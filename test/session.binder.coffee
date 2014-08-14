# get env
try
  require "#{__dirname}/support/env"
catch e
  console.log 'Not Found: env.js'

TEST_MONGO = process.env.TEST_MONGO or 'mongodb://test:test@localhost/test'
SESSION_SECRET = process.env.SESSION_SECRET or 'sEcReT4un1ttest'
should = require 'should'
sinon = require 'sinon'
cookieParser = require 'cookie-parser'
session = require 'express-session'
memoryStore = new session.MemoryStore
signature = require 'cookie-signature'

sessionBinder = require "#{__dirname}/../src/lib/session.binder"

describe 'session binder', ->
  sessionId = null
  signedSessionId = null

  beforeEach (done)->
    sessionId = 'iamsessionidforunittest'
    signedSessionId = signature.sign sessionId, SESSION_SECRET
    memoryStore.clear()
    done()

  it 'should export', ->
    sessionBinder.http.should.be.a.Function
    sessionBinder.socket.should.be.a.Function

  describe '#http()', ->

    it 'should replace session with socket.sid', (done)->
      originalSessionId = "iamoriginalsessionid"

      req =
        cookies:
          'socket.sid': "s:#{signedSessionId}"
        headers:
          cookie: "connect.sid=originalSessionId; socket.sid=#{signedSessionId};"

      res =
        cookie: (key, value, options)->
          key.should.be.equal 'connect.sid'
          value.should.be.equal "s:#{signedSessionId}"
          options.should.have.properties
            path: '/'
            httpOnly: true
        clearCookie: (key, options)->
          key.should.be.equal 'socket.sid'
          options.should.have.property 'path', '/'

      sessionBinder.http req, res, ->
        done()

    it 'should passed without socket.sid', (done)->
      res =
        cookie: ->

      req =
        cookies: {}

      spySetCookie = sinon.spy res, 'cookie'

      sessionBinder.http req, res, ->
        spySetCookie.calledOnce.should.be.false
        done()

  describe '#findCookie() - utility', ->

    it 'should pass empty array when cookie cannot match', (done)->
      socket =
        handshake:
          headers:
            cookie: "connect.sad=s:#{signedSessionId} ;"
        emit: (key, value)->
          key.should.be.equal 'setCookie'
          signedSid = value['socket.sid'].substr 2
          sid = signature.unsign signedSid, SESSION_SECRET
          sid.should.not.equal sessionId

      spyEmit = sinon.spy socket, 'emit'

      sessionBinder.socket cookieParser, memoryStore, SESSION_SECRET, socket, ->
        spyEmit.calledOnce.should.be.true
        done()

    it 'should pass empty array when cookie cannot match', (done)->
      socket =
        handshake:
          headers:
            cookie: "connect.sid=aa ;"
        emit: (key, value)->
          key.should.be.equal 'setCookie'
          signedSid = value['socket.sid'].substr 2
          sid = signature.unsign signedSid, SESSION_SECRET

      sessionBinder.socket cookieParser, memoryStore, SESSION_SECRET, socket, ->
        done()

  describe '#socket()', ->

    it 'should passed if cookie is empty', (done)->
      socket =
        handshake:
          headers: {}
        emit: ->

      sessionBinder.socket cookieParser, memoryStore, SESSION_SECRET, socket, ->
        done()

    it 'should socket create empty session when connect.sid is empty', (done)->
      socket =
        handshake:
          headers:
            cookie: "connect.sid=s:#{signedSessionId} ;"
        emit: (key, value)->
          key.should.be.equal 'setCookie'
          signedSid = value['socket.sid'].substr 2
          sid = signature.unsign signedSid, SESSION_SECRET
          sid.should.not.equal sessionId
          memoryStore.sessions[sid].should.be.exist
          session = JSON.parse memoryStore.sessions[sid]
          session.cookie.should.have.properties
            originalMaxAge: null
            expires: null
            httpOnly: true
            path: '/'

          # Check socket
          socket.sessionID.should.be.equal sid
          socket.sessionStore.should.be.equal memoryStore
          socket.session.cookie.should.be.exist
          socket.session.cookie.should.have.properties
            originalMaxAge: null
            expires: null
            httpOnly: true
            path: '/'

      spyEmit = sinon.spy socket, 'emit'

      sessionBinder.socket cookieParser, memoryStore, SESSION_SECRET, socket, ->
        spyEmit.calledOnce.should.be.true
        done()

    it 'should socket get existed session from connect.sid', (done)->
      socket =
        handshake:
          headers:
            cookie: "connect.sid=s:#{signedSessionId} ;"

      memoryStore.set sessionId,
        cookie:
          originalMaxAge: null
          expires: null
          httpOnly: true
          path: '/'
        oldSession: true
      , ->
        sessionBinder.socket cookieParser, memoryStore, SESSION_SECRET, socket, ->
          socket.session.oldSession.should.be.true
          socket.sessionID.should.be.equal sessionId
          socket.sessionStore.should.be.equal memoryStore
          memoryStore.sessions[sessionId].should.be.exist
          session = JSON.parse memoryStore.sessions[sessionId]
          session.cookie.should.have.properties
            originalMaxAge: null
            expires: null
            httpOnly: true
            path: '/'
          done()