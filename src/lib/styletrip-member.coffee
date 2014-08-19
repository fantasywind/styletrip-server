errorParser = require 'error-message-parser'
mongoose = require 'mongoose'
chalk = require 'chalk'
cookie = require 'cookie'
Member = mongoose.model 'Member'
passport = require "./passport"

generateGuest = (socket)->
  passport.generateGuest (err, guest)->
    if err
      socket.emit 'failed', errorParser.generateError 401, err
    else
      console.log chalk.dim "Generated guest: #{guest._id}"
      member = guest
      socket.session.member = member
      socket.session.token = guest.token.secret
      socket.session.expires = guest.token.expires
      socket.sessionStore.set socket.sessionID, socket.session, ->
        socket.emit 'guestLogined',
          sid: socket.sessionID

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
          userId = socket.session.member._id or socket.session.passport.user
          Member.findById userId, (err, member)->
            if err
              socket.emit 'failed', errorParser.generateError 401, err
            else if !member
              socket.emit 'failed', errorParser.generateError 402
            else
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
        session.member = member
        console.log chalk.dim "Cookie Logined: #{session.member.id}"
        cb null if cb
      else
        cb 'Not Found' if cb

module.exports = 
  Controller: StyletripMemberController