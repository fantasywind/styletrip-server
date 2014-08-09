should = require 'should'
Member = require "../src/models/member.coffee"
mongoose = require 'mongoose'
Member = mongoose.model 'Member'

# Overwrite methods
Member.findById = (id, callback)->
  user = new Member
    _id: id
  callback null, user

passport = require "#{__dirname}/../src/lib/passport"

describe 'passport', ->

  describe 'passport.serializeUser', ->
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

  describe 'passport.deserializeUser', ->
    it 'should deserializeUser find correct user id', (done)->
      userId = new mongoose.Types.ObjectId
      passport.deserializeUser userId, (err, user)->
        should.not.exist err
        user._id.should.be.equal userId
        done()