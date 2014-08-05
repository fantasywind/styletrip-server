errorParser = require 'error-message-parser'
passport = require "./passport"
mongoose = require 'mongoose'
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
        socket.emit 'failed', errorParser.generateError 401, err
      else if !member
        socket.emit 'failed', errorParser.generateError 402
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
        else if socket.session.passport and socket.session.passport.user
          Member.findById socket.session.passport.user, (err, member)->
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
              member = new StyletripMember guest
              socket.session.member = member
              socket.emit 'guestLogined'

      next()

module.exports = StyletripMemberController