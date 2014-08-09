should = require 'should'
mongoose = require 'mongoose'
Schema = mongoose.Schema

MemberSchema = new Schema
  _id: Number

MemberSchema.statics.findById = (id, callback)->
  user = new Member
    _id: id
  callback null, user

Member = mongoose.model('Member', MemberSchema);

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
      userId = 123
      passport.deserializeUser userId, (err, user)->
        should.not.exist err
        user._id.should.be.equal userId
        done()