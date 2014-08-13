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

describe 'model-member', ->
  testMember = null

  beforeEach (done)->
    testMember = new Member

    return done() if mongoose.connection.db
    mongoose.connect TEST_MONGO, done

  describe '#hashPassword()', ->

    it 'should hashPassword return string', ->
      testMember.hashPassword('testPassword').should.be.type 'string'

  describe '#validPassword()', ->

    it 'should valid password', ->
      testMember.password = testMember.hashPassword 'testPassword'
      testMember.validPassword('testPassword').should.be.true
      testMember.validPassword('testWrongPassword').should.be.false

  describe '#publicInfo()', ->

    it 'should return limit public scope data', ->
      testMember.name = 'Test Member'
      testMember.facebookID = '15979823465986'

      testMember.publicInfo().should.have.properties
        name: testMember.name
        facebookID: testMember.facebookID

  describe '#addSchedule()', ->

    it 'should add scheduleID to history list', (done)->

      testMember.addSchedule 'a3d', (err, member)->
        should.not.exist err
        member.scheduleHistory.should.containEql 'a3d'
        done()

  describe '#combineGuest()', ->

    it 'should throw error if guest id is undefined', (done)->
      testMember.combineGuest null, (err, member)->
        err.should.be.an.Error
        err.toString().should.be.equal 'Error: Please pass guest.'

        testMember.combineGuest {}, (err, member)->
          err.should.be.an.Error
          err.toString().should.be.equal 'Error: Please pass guest.'

          done()

    it 'should throw error if guest id is equal with combined member id', (done)->
      testMember.combineGuest
        _id: testMember._id
      , (err, member)->
        err.should.be.an.Error
        err.toString().should.be.equal 'Error: Same combined guest request! Abort.'

        done()

    it 'should throw error if find guest member data failed', (done)->
      testMember.combineGuest
        _id: 'iamfakememberid'
      , (err, member)->
        err.should.be.an.Error
        err.toString().should.be.equal 'Error: Find guest member data failed (CastError: Cast to ObjectId failed for value \"iamfakememberid\" at path \"_id\")'

        done()

    it 'should throw error if guest member data not found', (done)->
      objectId = mongoose.Types.ObjectId()
      testMember.combineGuest
        _id: objectId
      , (err, member)->
        err.should.be.an.Error
        err.toString().should.be.equal 'Error: Not found guest member to combined.'

        done()

    it 'should throw error when save combined member failed', (done)->
      sinon.stub testMember, 'save', (cb)->
        cb new Error 'Failed saving combined member'

      guest = new Member
        guest: true
      guest.save (err, guest)->
        throw err if err

        testMember.combineGuest
          _id: guest._id
        , (err, member)->
          err.should.be.an.Error
          err.toString().should.be.equal 'Error: Failed saving combined member'
          testMember.save.restore()

          done()

    it 'should add schedule history and remove guest member after combined.', (done)->
      guest = new Member
        guest: true
        scheduleHistory: [
          'a9d'
          'k32f'
        ]
      guest.save (err, guest)->
        throw err if err

        testMember.combineGuest
          _id: guest._id
        , (err, member)->
          should.not.exist err
          member.scheduleHistory.should.containEql 'a9d'
          member.scheduleHistory.should.containEql 'k32f'

          Member.findById guest._id, (err, guest)->
            throw err if err
            should.not.exist guest

            done()