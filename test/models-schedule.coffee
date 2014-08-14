# get env
try
  require "#{__dirname}/support/env"
catch e
  console.log 'Not Found: env.js'

TEST_MONGO = process.env.TEST_MONGO or 'mongodb://test:test@localhost/test'
should = require 'should'
sinon = require 'sinon'
mongoose = require 'mongoose'
Schedule = require "../src/models/schedule"
clearDB = require('mocha-mongoose') TEST_MONGO

describe 'model-schedule', ->
  testSchedule = null

  beforeEach (done)->
    testSchedule = new Schedule
      _id: '08c'
      keyword: 'Taipei'
      dates: [Date.now()]
      from: {}
      chunks: []

    return done() if mongoose.connection.db
    mongoose.connect TEST_MONGO, done

  it 'should schema is matched', ->
    testSchedule._id.should.be.a.String
    testSchedule.keyword.should.be.a.String
    testSchedule.dates.should.be.an.Array
    testSchedule.dates[0].should.be.a.Number
    testSchedule.chunks.should.be.an.Array
    testSchedule.dates.should.be.a.Object