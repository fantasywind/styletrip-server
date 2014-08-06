errorParser = require 'error-message-parser'
passport = require "./passport"
mongoose = require 'mongoose'
chalk = require 'chalk'
cookie = require 'cookie'
Member = mongoose.model 'Member'

generateGuest = (socket)->
  passport.generateGuest (err, guest)->
    if err
      socket.emit 'failed', errorParser.generateError 401, err
    else
      console.log chalk.gray "Generated guest: #{guest._id}"
      member = new StyletripMember guest
      socket.session.member = member
      socket.session.token = guest.token.secret
      socket.session.expires = guest.token.expires
      socket.sessionStore.set socket.sessionID, socket.session, -> socket.emit 'guestLogined'

class StyletripMember
  constructor: (options)->
    {@facebookAccessToken, @facebookID, @name, @id, _id, done} = options
    @id ?= _id
    @syncDocument = false

    if @id
      @queues = []

      Member.findById @id, (err, member)=>
        if err
          done errorParser.generateError 401, err
        else if !member
          @createDocument (err, member)=>
            if err
              done err
            else
              @syncDocument = true
              @$document = member
        else
          @document = member
          @syncDocument = true

          for queue in @queues
            queue.call @

  queue: ->
    if @syncDocument
      for fn in arguments
        fn.call @
    else
      for fn in arguments
        @queues.push fn

  publicInfo: -> {
    facebookID: @facebookID
    name: @name
  }

  addSchedule: (scheduleID, done)->
    @queue ->
      @document.scheduleHistory.push scheduleID
      @document.save (err, member)->
        return done err if err

        done null

  createDocument: (done)->
    member = new Member
      facebookID: profile.id
      facebookAccessToken: accessToken
      name: profile.displayName
    member.save (err, member)->
      return done err if err

      done null, member

class StyletripMemberController
  constructor: (@passport)->

  socketBinder: ->
    return (socket, next)=>
      socket.on 'loginStatus', =>
        user = socket.session.user
        cookies = cookie.parse socket.handshake.headers.cookie

        if user
          socket.emit 'logined',
            facebookID: user.facebookID
            name: user.name
        else if (socket.session.passport and socket.session.passport.user) or socket.session.member
          userId = socket.session.member or socket.session.passport.user
          Member.findById userId, (err, member)->
            if err
              socket.emit 'failed', errorParser.generateError 401, err
            else if !member
              socket.emit 'failed', errorParser.generateError 402
            else
              member = new StyletripMember member
              socket.session.member = member
              socket.emit 'logined', member.publicInfo()
        else if cookies.token
          # Cookie Login
          @cookieLogin cookies.token, socket.session, (err)->
            if err
              generateGuest socket
            else
              socket.sessionStore.set socket.sessionID, socket.session
        else
          # Generate Guest
          generateGuest socket

      next()

  cookieLogin: (token, session, cb)->
    return false if !token or token is ''

    Member.findOne
      "token.secret": token
      "token.expires":
        $gte: Date.now()
    , (err, member)->
      return console.error chalk.red "Cookie login error" if err

      if member
        session.member = new StyletripMember member
        console.log chalk.gray "Cookie Logined: #{session.member.id}"
        cb null if cb
      else
        cb 'Not Found' if cb

module.exports = 
  Controller: StyletripMemberController
  Member: StyletripMember