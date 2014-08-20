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
net = require 'net'
mongoose = require 'mongoose'
errorParser = require 'error-message-parser'
errorParser.Parser
  cwd: "#{__dirname}/../src/errorMessages"
  lang: 'zh-TW'
Member = require "../src/models/member"
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

    describe '#done()', ->

      it 'should create schedule after call done', (done)->
        request = new styletripEngine.Request {}

        request.schedule_id = '_thisisatestscheduleID'
        request.conditions =
          keyword: 'iamquerykeyword'
          dates: [
            Date.now()
          ]
        request.payload =
          place: 'taipei'
        request.schedules = []

        request.on 'end', ->
          Schedule.findById request.schedule_id, (err, schedule)->
            throw err if err
            schedule.should.be.exist
            done()

        request.done()

      it 'should throw error when call done and creating schedule', (done)->
        request = new styletripEngine.Request {}

        request.schedule_id = '_thisisatestscheduleID'
        request.conditions =
          keyword: 'iamquerykeyword'
          dates: true
        request.payload =
          place: 'taipei'
        request.schedules = []

        request.on 'error', (data)->
          data.should.have.properties
            status: false
            code: 403
            level: 1
            message: '無法記錄會員行程規劃資訊。'
          done()

        request.done()

    describe '#saveHistory()', ->

      it 'should throw error if member._id is invalid', (done)->
        request = new styletripEngine.Request {}
        member =
          _id: 'iaminvalidmemberid'

        request.saveHistory member, (err)->
          err.should.be.equal 'Cannot find member to add schedule history.'
          done()

      it 'should throw error if member not found', (done)->
        request = new styletripEngine.Request {}
        member =
          _id: new mongoose.Types.ObjectId()

        request.saveHistory member, (err)->
          err.should.be.equal 'Cannot find member to add schedule history.'
          done()

      it 'should add schedule to history list', (done)->
        request = new styletripEngine.Request {}
        member = new Member
        member.save (err, member)->
          throw err if err

          request.schedule_id = '30fs'
          request.saveHistory member, (err)->
            should.not.exist err
            done()

    describe '#prepareRequest()', ->

      it 'should generate payload', ->
        request = new styletripEngine.Request {}

        request.conditions =
          keyword: 'iamkeyword'
          dates: [Date.now()]
          place: 
            lat: 20.12471324
            lng: 122.23423451

        request.prepareRequest().should.have.property 'keyword', request.conditions.keyword
        request.prepareRequest().should.have.property 'date', request.conditions.dates
        request.prepareRequest().should.have.property 'from', request.conditions.place
        request.prepareRequest().request_id.should.be.exist
        request.prepareRequest().request_id.should.be.equal request.id

      it 'should generate payload and auto set from to empty object', ->
        request = new styletripEngine.Request {}

        request.conditions =
          keyword: 'iamkeyword'
          dates: [Date.now()]

        request.prepareRequest().should.have.property 'from', {}

  describe 'Class: StyletripScheduleConnection', ->
    server = connection = null
    SERVER_PORT = 9872

    beforeEach (done)->
      server = net.createServer()
      server.on 'listening', done
      server.on 'connection', (socket)->
        console.log 'Created Test Server'
        socket.write 'chunkTest'
      server.listen SERVER_PORT

    afterEach (done)->
      connection.conn.end()
      server.close ->
        console.log 'Closed Test Server'
        done()

    it 'should create instance and create socket', ->
      connection = new styletripEngine.Connection
        host: '127.0.0.1'
        port: SERVER_PORT
      connection.constructor.name.should.be.equal 'StyletripScheduleConnection'

    describe '#createSocket()', ->

      it 'should log info when schedule connected', (done)->
        spyConsole = sinon.spy console, 'log'
        connection = new styletripEngine.Connection
          port: SERVER_PORT
          host: '127.0.0.1'

        connection.conn.on 'connect', -> 
          spyConsole.calledWith(chalk.green "[Schedule Engine] Connection Created.").should.be.true
          spyConsole.restore()
          done()

      it 'should throw error when schedule connect failed', (done)->
        spyConsoleLog = sinon.spy console, 'log'
        connection = new styletripEngine.Connection
          port: SERVER_PORT + 1
          host: '127.0.0.1'

        connection.conn.on 'error', -> 
          connection.retryTimeout = 300000
          spyConsoleLog.calledWith(chalk.dim "[Schedule Engine] Retry connection in 1 second(s)").should.be.true
          spyConsoleLog.restore()

          done()

      it 'should throw error when schedule connect failed and retry many times', (done)->
        spyConsoleError = sinon.spy console, 'error'

        connection = new styletripEngine.Connection
          port: SERVER_PORT + 1
          host: '127.0.0.1'
        connection.retryTimeout = 300000

        connection.conn.on 'error', -> 
          spyConsoleError.calledWith(chalk.red "[Schedule Engine] Failed retry connection :(").should.be.true
          spyConsoleError.restore()

          done()

      it 'should parseScheduleResult on data', (done)->
        connection = new styletripEngine.Connection
          port: SERVER_PORT
          host: '127.0.0.1'

        connection.parseScheduleResult = ->
          connection.chunkPool.should.be.equal 'chunkTest'
          done()

    describe '#parseScheduleResult()', ->

      it 'should throw error when JSON format error', (done)->
        spyConsoleError = sinon.spy console, 'error'
        connection = new styletripEngine.Connection
          port: SERVER_PORT
          host: '127.0.0.1'

        # hook
        originalParseScheduleResult = connection.parseScheduleResult.bind connection
        connection.splitChunk = -> 'Invalid JSON'
        connection.parseScheduleResult = ->
          originalParseScheduleResult()

          spyConsoleError.calledWith(chalk.red "Invalid result! Please check engine server.").should.be.true
          spyConsoleError.restore()

          done()

      it 'should throw error when request not found', (done)->
        spyConsole = sinon.spy console, 'log'
        connection = new styletripEngine.Connection
          port: SERVER_PORT
          host: '127.0.0.1'

        # hook
        originalParseScheduleResult = connection.parseScheduleResult.bind connection
        connection.splitChunk = -> [
          '{"request_id": "notfoundrequestid"}'
        ]
        connection.parseScheduleResult = ->
          originalParseScheduleResult()

          spyConsole.calledWith(chalk.yellow "Not Found Request: notfoundrequestid").should.be.true
          spyConsole.restore()

          done()

      it 'should call chunk when request parsed', (done)->
        connection = new styletripEngine.Connection
          port: SERVER_PORT
          host: '127.0.0.1'

        # hook
        originalParseScheduleResult = connection.parseScheduleResult.bind connection
        connection.requestPool =
          existrequestid:
            chunk: (result)->
              result.should.have.property 'request_id', 'existrequestid'

              done()
        connection.splitChunk = -> [
          '{"request_id": "existrequestid"}'
        ]

      it 'should call done when request failed', (done)->
        spyConsole = sinon.spy console, 'log'
        connection = new styletripEngine.Connection
          port: SERVER_PORT
          host: '127.0.0.1'

        # hook
        originalParseScheduleResult = connection.parseScheduleResult.bind connection
        connection.requestPool =
          existrequestid:
            done: (err)->
              err.toString().should.be.equal 'Error: Engine Error: (404) errorfortest'
              spyConsole.restore()

              done()
        connection.splitChunk = -> [
          '{"request_id": "existrequestid", "err": "errorfortest", "code": 404}'
        ]

      it 'should call done and set for code 405 when request failed without error code', (done)->
        spyConsole = sinon.spy console, 'log'
        connection = new styletripEngine.Connection
          port: SERVER_PORT
          host: '127.0.0.1'

        # hook
        connection.requestPool =
          existrequestid:
            done: (err)->
              err.toString().should.be.equal 'Error: Engine Error: (405) errorfortest'
              spyConsole.calledWith(chalk.red 'Error: Engine Error: (405) errorfortest').should.be.true
              spyConsole.restore()

              done()
        connection.splitChunk = -> [
          '{"request_id": "existrequestid", "err": "errorfortest"}'
        ]

    describe '#splitChunk()', ->

      it 'should return false if chunkPool is undefined', (done)->
        connection = new styletripEngine.Connection
          port: SERVER_PORT
          host: '127.0.0.1'
        connection.parseScheduleResult = ->
          connection.chunkPool = undefined
          connection.splitChunk().should.be.false

          done()

      it 'should split chunkPool', (done)->
        connection = new styletripEngine.Connection
          port: SERVER_PORT
          host: '127.0.0.1'
        connection.parseScheduleResult = ->
          connection.chunkPool = '{"request_id": "testrequestid"}' + String.fromCharCode(5)
          result = connection.splitChunk()
          result.should.length 1
          result[0].should.be.equal '{"request_id": "testrequestid"}'
          connection.chunkPool.should.be.equal ''

          done()

    describe '#schedule()', ->

      it 'should log request sent and write JSON to socket', (done)->
        spyConsole = sinon.spy console, 'log'

        connection = new styletripEngine.Connection
          port: SERVER_PORT
          host: '127.0.0.1'

        connection.conn.write = (requestJSON)->
          requestJSON.should.match new RegExp String.fromCharCode(5)

        connection.parseScheduleResult = ->
          dateStamp = Date.now()

          request =
            id: 'requestID'
            payload:
              keyword: 'iamkeyword'
              date: [dateStamp]

          connection.schedule request

          connection.requestPool['requestID'].payload.should.have.properties
            keyword: 'iamkeyword'
            date: [dateStamp]

          spyConsole.calledWith(chalk.dim "Send Request: iamkeyword when #{dateStamp}").should.be.true
          spyConsole.restore()

          done()