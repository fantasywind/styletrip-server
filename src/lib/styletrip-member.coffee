errorParser = require 'error-message-parser'
passport = require "./passport"
mongoose = require 'mongoose'
chalk = require 'chalk'
Member = mongoose.model 'Member'

class StyletripMember
  constructor: (options)->
    {@facebookID, @name, @id, _id} = options
    @id ?= _id

  publicInfo: -> {
    facebookID: @facebookID
    name: @name
  }

  addSchedule: (scheduleID, done)->
    Member.findById @id, (err, member)->
      if err
        done errorParser.generateError 401, err
      else if !member
        done errorParser.generateError 402
      else
        member.scheduleHistory.push scheduleID
        member.save (err, member)->
          return done err if err

          done null

class StyletripMemberController
  constructor: (@passport)->

  socketBinder: ->
    return (socket, next)=>
      socket.on 'loginStatus', ->
        user = socket.session.user
        if user
          socket.emit 'logined',
            facebookID: user.facebookID
            name: user.name
        else if (socket.session.passport and socket.session.passport.user) or socket.session.member
          userId = socket.session.passport.user or socket.session.member
          Member.findById userId, (err, member)->
            if err
              socket.emit 'failed', errorParser.generateError 401, err
            else if !member
              socket.emit 'failed', errorParser.generateError 402
            else
              member = new StyletripMember member
              socket.session.member = member
              socket.emit 'logined', member.publicInfo()
        else
          # Generate Guest
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

      next()

  cookieLogin: (token, session)->
    return false if !token or token is ''

    Member.findOne
      "token.secret": token
      "token.expires":
        $gte: Date.now()
    , (err, member)->
      return console.error chalk.red "Cookie login error" if err

      if member
        session.user = member
        console.log chalk.gray "Cookie Logined: #{session.user._id}"

module.exports = 
  Controller: StyletripMemberController
  Member: StyletripMember