# get env
try
  require "#{__dirname}/support/env"
catch e
  console.log 'Not Found: env.js'

TEST_MONGO = process.env.TEST_MONGO or 'mongodb://test:test@localhost/test'
should = require 'should'
XDate = require 'xdate'
sinon = require 'sinon'
chalk = require 'chalk'
mongoose = require 'mongoose'
errorParser = require 'error-message-parser'
errorParser.Parser
  cwd: "#{__dirname}/../src/errorMessages"
  lang: 'zh-TW'
Schedule = require "../src/models/schedule"
clearDB = require('mocha-mongoose') TEST_MONGO
EventEmitter = require('events').EventEmitter

styletripEngine = require "#{__dirname}/../src/lib/styletrip-engine"

describe 'styletrip engine', ->

  it 'should styletrip member exports functions', ->
    styletripEngine.Connection.should.be.a.Function
    styletripEngine.Request.should.be.a.Function
    styletripEngine.Schedule.should.be.a.Function
    styletripEngine.Footprint.should.be.a.Function
    styletripEngine.View.should.be.a.Function
    styletripEngine.Route.should.be.a.Function
    styletripEngine.DailySchedule.should.be.a.Function

  describe 'Class: Footprint', ->

    it 'should make a footprint instance', ->
      footprint = new styletripEngine.Footprint
      footprint.constructor.name.should.be.equal 'StyletripFootprint'

  describe 'Class: View', ->

    it 'should make a view instance and saving meta', ->
      view = new styletripEngine.View
        gps: 'iamgps'
        name: 'iamaview'
        profile: 'testprofile'
        region: 'taipei'
        serial: 2
        spend_time: 40
        start_time: 120
        type: 'VIEW'
        view_id: 1

      view.should.have.properties
        gps: 'iamgps'
        name: 'iamaview'
        profile: 'testprofile'
        region: 'taipei'
        serial: 2
        spend_time: 40
        start_time: 120
        type: 'VIEW'
        view_id: 1

  describe 'Class: Route', ->

    it 'should make a route instance and saving meta', ->
      route = new styletripEngine.Route
        transport: 'CAR'
        serial: 4
        spend_time: 24
        start_time: 80
        type: 'ROUTE'

      route.should.have.properties
        transport: 'CAR'
        serial: 4
        spend_time: 24
        start_time: 80
        type: 'ROUTE'

  describe 'Class: DailySchedule', ->

    it 'should make a daily schedule instance and saving meta', ->
      date = Date.now()

      spyAdd = sinon.spy styletripEngine.DailySchedule::, 'add'

      testSchedule = [
        'testSchedule'
      ]
      schedule = new styletripEngine.DailySchedule
        date: date
        main_view: new styletripEngine.View {}
        from: 'taipei'
        daily_cost: 2000
        schedule: testSchedule

      schedule.should.have.properties
        cost: 2000
        date: new XDate(date).toString 'yyyy-MM-dd'
        from: 'taipei'

      schedule.main_view.constructor.name.should.be.equal 'StyletripView'
      spyAdd.calledOnce.should.be.true
      spyAdd.restore()

    describe '#add()', ->

      it 'should add schedule to footprint and make instance with its type', ->
        view =
          type: 'VIEW'

        route =
          type: 'ROUTE'

        testSchedule = [
          view
          route
        ]
        schedule = new styletripEngine.DailySchedule
          main_view: new styletripEngine.View {}
          schedule: testSchedule

        schedule.footprints.should.have.length 2
        schedule.footprints[0].constructor.name.should.be.equal 'StyletripView'
        schedule.footprints[1].constructor.name.should.be.equal 'StyletripRoute'

  describe 'Class: StyletripSchedule', ->

    it 'should throw a warning when init without id', ->
      spyConsole = sinon.spy console, 'log'

      schedule = new styletripEngine.Schedule {}

      spyConsole.calledWith chalk.yellow '[Engine] init schedule instance without id'
      spyConsole.restore()

    describe '#toObject()', ->

      it 'should throw error when schedule data is empty', (done)->
        schedule = new styletripEngine.Schedule {}
        schedule.on 'error', (data)->
          data.should.have.properties
            status: false
            code: 410
            level: 1
            message: '找不到排程資訊。'
          done()

        schedule.toObject().should.be.false

      it 'should retrun data chunks', ->
        testChunk = {}

        schedule = new styletripEngine.Schedule {}
        schedule.data =
          chunks: testChunk

        schedule.toObject().should.be.equal testChunk

    describe '#fetchData()', ->

      beforeEach (done)->
        # mongoose
        return done() if mongoose.connection.db
        mongoose.connect TEST_MONGO, done

      it 'should throw error if id is missing', (done)->
        schedule = new styletripEngine.Schedule {}
        schedule.on 'error', (data)->
          data.should.have.properties
            status: false
            code: 409
            level: 2
            message: '找不到排程 ID。'
          done()

        schedule.fetchData()

      it 'should throw error if schedule not found', (done)->
        schedule = new styletripEngine.Schedule {}

        schedule.on 'error', (data)->
          data.should.have.properties
            status: false
            code: 409
            level: 2
            message: '找不到排程 ID。'
          done()

        schedule.id = '_invalidID'
        schedule.fetchData()

      it 'should emit schedule data', (done)->
        s = new Schedule
          _id: 'iamexistschedule'
        s.save (err, s)->
          throw err if err

          schedule = new styletripEngine.Schedule {}

          schedule.on 'fetched', (data)->
            schedule.data._id.toString().should.be.equal s._id.toString()
            done()

          schedule.id = s._id
          schedule.fetchData()

  describe 'Class: StyletripScheduleRequest', ->

    it 'should exported functions', ->
      request = new styletripEngine.Request {}
      request.send.should.be.a.Function
      request.chunk.should.be.a.Function
      request.done.should.be.a.Function
      request.saveHistory.should.be.a.Function
      request.prepareRequest.should.be.a.Function

    it 'should constructor saving meta and correct make instance', ->
      conditions = {}
      engine = {}
      request = new styletripEngine.Request
        conditions: conditions
        engine: engine

      request.constructor.name.should.be.equal 'StyletripScheduleRequest'
      request.conditions.should.be.equal conditions
      request.engine.should.be.equal engine
      request.schedules.should.be.an.Array

    describe '#send()', ->

      it 'should throw error when engine is undefined or conditions is undefined', ->
        request = new styletripEngine.Request
          conditions: {}

        (->
          request.send()
        ).should.throw("You have to initial request object.")

        request = new styletripEngine.Request
          engine: {}

        (->
          request.send()
        ).should.throw("You have to initial request object.")

      it 'should call prepareRequest and engine.schedule', (done)->
        request = new styletripEngine.Request
          conditions: {}
          engine:
            schedule: (req)->
              req.should.be.equal request
              done()

        request.prepareRequest = ->

        spyPrepareRequest = sinon.spy request, 'prepareRequest'
        request.send()
        spyPrepareRequest.calledOnce.should.be.true

    describe '#chunk()', ->

      it 'should emit receivedChunked', (done)->
        request = new styletripEngine.Request {}

        spyConsole = sinon.spy console, 'log'

        request.on 'receivedChunked', (data)->
          spyConsole.restore()
          done()

        request.schedule_id = 'originalScheduleID'

        request.chunk
          schedule_id: 'scheduleID'
          has_next: true
          chunk_part: 1
          results: []

        spyConsole.calledWith(chalk.dim "[Engine] ReqID: originalScheduleID, Part: 1, hasNext: true").should.be.true

      it 'should get schedule_id from chunk', (done)->
        request = new styletripEngine.Request {}

        spyConsole = sinon.spy console, 'log'

        request.on 'receivedChunked', (data)->
          spyConsole.restore()
          done()

        request.chunk
          schedule_id: 'scheduleID'
          has_next: true
          chunk_part: 1
          results: []

        spyConsole.calledWith(chalk.dim "[Engine] ReqID: scheduleID, Part: 1, hasNext: true").should.be.true

      it 'should push schedule get from chunks', ->
        request = new styletripEngine.Request {}

        request.chunk
          schedule_id: 'scheduleID'
          has_next: true
          chunk_part: 1
          results: [{
            from: 'taipei'
            date: Date.now()
          }, {
            from: 'taoyuan'
            date: Date.now()
          }]

        request.schedules.should.length 2
        request.schedules[0].from.should.be.equal 'taipei'
        request.schedules[1].from.should.be.equal 'taoyuan'

      it 'should call done if has_next is true', (done)->
        request = new styletripEngine.Request {}

        request.done = ->
          done()

        request.chunk
          schedule_id: 'scheduleID'
          has_next: false
          chunk_part: 1
          results: []

