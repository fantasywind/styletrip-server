TEST_MONGO = process.env.TEST_MONGO
should = require 'should'
Member = require "../src/models/member.coffee"
mongoose = require 'mongoose'
Member = mongoose.model 'Member'
clearDB = require('mocha-mongoose') TEST_MONGO

# Overwrite methods
###
Member.findById = (id, callback)->
  user = new Member
    _id: id
  callback null, user

Member.schema.methods.save1 = (cb)->
  throw 'WTF'
  cb null, this
###

passport = require "#{__dirname}/../src/lib/passport"

describe 'passport', ->

  describe '#serializeUser()', ->
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

  describe '#deserializeUser()', ->

    beforeEach (done)->
      return done() if mongoose.connection.db
      mongoose.connect TEST_MONGO, done

    userId = new mongoose.Types.ObjectId

    it 'should deserializeUser return false when not found', (done)->
      passport.deserializeUser userId, (err, user)->
        should.not.exist err
        user.should.be.false
        done()

    it 'should deserializeUser find correct user id', (done)->
      guest = new Member
        _id: userId
      guest.save (err, member)->
        throw err if err

        passport.deserializeUser userId, (err, user)->
          should.not.exist err
          user._id.toString().should.be.equal userId.toString()
          done()

  describe '#generateGuest()', ->

    beforeEach (done)->
      return done() if mongoose.connection.db
      mongoose.connect TEST_MONGO, done

    it 'should #generateGuest() generate guest member', (done)->
      passport.generateGuest (err, member)->
        should.not.exist err
        member.guest.should.be.true
        member.token.secret.should.be.type 'string'
        new Date(member.token.expires).toString().should.not.equal 'Invalid Date'
        done()