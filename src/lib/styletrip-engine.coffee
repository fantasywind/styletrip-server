_ = require 'lodash'
uuid = require 'node-uuid'
net = require 'net'
chalk = require 'chalk'
XDate = require 'xdate'
mongoose = require 'mongoose'
EventEmitter = require('events').EventEmitter
errorParser = require 'error-message-parser'
Schedule = mongoose.model 'Schedule'
Member = mongoose.model 'Member'

viewType =
  VIEW: 'VIEW'
  DINNING: 'DINNING'
  ACCOMMODATION: 'ACCOMMODATION'
  ROUTE: 'ROUTE'

class StyletripSchedule extends EventEmitter
  constructor: (options)->
    {@id, @version} = options or {}

    @fetchData() if @id

  fetchData: ->
    @emit 'error', errorParser.generateError 409 if !@id

    scheduleId = if @version then "#{id}-#{version}" else @id

    Schedule.findById scheduleId, (err, schedule)=>
      @emit 'error', errorParser.generateError 401 if err

      if !schedule
        @emit 'error', errorParser.generateError 409
      else
        @data = schedule
        @emit 'fetched'

  toObject: ->
    if !@data
      @emit 'error', errorParser.generateError 410
      return false
    
    return @data.chunks

class StyletripFootprint
  constructor: ->

class StyletripView extends StyletripFootprint
  constructor: (options)->
    {@gps, @name, @profile, @region, @serial, @spend_time, @start_time, @type, @view_id} = options or {}

class StyletripRoute extends StyletripFootprint
  constructor: (options)->
    {@transport, @serial, @spend_time, @start_time, @type} = options or {}

class StyletripDailySchedule
  constructor: (options)->
    {date, @main_view, @from, daily_cost, schedule} = options or {}
    
    date = parseInt date, 10
    @date = new XDate(date).toString "yyyy-MM-dd"
    @cost = daily_cost
    @footprints = []

    @add.apply @, schedule

  add: ->
    for print in arguments
      footprint = if print.type is viewType.ROUTE then new StyletripRoute print else new StyletripView print
      @footprints.push footprint

class StyletripScheduleRequest extends EventEmitter
  constructor: (options)->
    {@conditions, @engine} = options or {}

    @schedules = []

  send: ->
    throw new Error "You have to initial request object." if !@engine or !@conditions

    @prepareRequest()
    @engine.schedule @

  chunk: (chunk)->
    console.log chalk.gray "[Engine] ReqID: #{chunk.schedule_id}, Part: #{chunk.chunk_part}, hasNext: #{chunk.has_next}"
    @schedule_id ?= chunk.schedule_id

    chunkSchedules = []
    for result in chunk.results
      dailySchedule = new StyletripDailySchedule result 
      @schedules.push dailySchedule
      chunkSchedules.push dailySchedule

    _.extend chunk,
      dailySchedules: chunkSchedules
    
    @emit 'receivedChunked', chunk

    @done() if !chunk.has_next

  done: ->
    # Caching Schedule Result
    schedule = new Schedule
      _id: @schedule_id
      keyword: @conditions.keyword
      dates: @conditions.dates
      from: @payload.place
      chunks: @schedules
    schedule.save (err, schedule)=>
      if err
        @emit 'error', errorParser.generateError 403
        console.log chalk.red "Create schedule cache failed: #{err}"
      else
        @emit 'end'

  saveHistory: (member, done)->
    console.log chalk.gray "[Engine] Save to member history (Member: #{member._id})"
    Member.findById member._id, (err, member)=>
      done 'Cannot find member to add schedule history.' if err

      if member
        member.addSchedule @schedule_id, (err)=>
          done errorParser.generateError 403 if err

          done()
      else
        done "Cannot find member to add schedule history."

  prepareRequest: ->
    @id = uuid.v4()

    @payload =
      request_id: @id
      keyword: @conditions.keyword
      date: @conditions.dates
      from: @conditions.place or {}

class StyletripScheduleConnection
  constructor: (options)->
    {port, host} = options or {}

    @createSocket port, host

  createSocket: (port, host)->
    @retryTimeout ?= 500
    @conn = new net.Socket

    @conn.bufferSize = 1024
    @conn.setEncoding 'utf-8'
    @conn.connect port, host

    @requestPool = {}

    # Listen callback
    @chunkPool = ''

    @conn.on 'connect', =>
      @retryTimeout = 500
      console.log chalk.green "[Schedule Engine] Connection Created."

    @conn.on 'error', (msg)=>
      console.error chalk.red msg
      @conn.destroy()

      @retryTimeout = @retryTimeout * 2
      if @retryTimeout < 300000
        console.log chalk.gray "[Schedule Engine] Retry connection in #{@retryTimeout / 1000} second(s)"
        setTimeout =>
          @createSocket port, host
        , @retryTimeout
      else
        console.error chalk.red "[Schedule Engine] Failed retry connection :("
        throw new Error '[Schedule Engine] Error on connect.'

    @conn.on 'data', (chunk)=>
      @chunkPool += chunk
      @parseScheduleResult()

  parseScheduleResult: ->
    results = @splitChunk()

    for result in results
      try
        result = JSON.parse result
      catch e
        throw new Error 'Invalid result! Please check engine server.'

      request = @requestPool[result.request_id]

      if request
        if result.err
          result.code ?= 405
          err = new Error "Engine Error: (#{result.code}) #{result.err}"
          err.code = result.code
          console.log chalk.red err.toString()
          return @requestPool[result.request_id].done err

        request.chunk result
          
      else
        console.log chalk.yellow "Not Found Request: #{result.request_id}"
      
  splitChunk: ->
    return false if !@chunkPool

    resultArr = []
    while ~(idx = @chunkPool.indexOf String.fromCharCode(5))
      resultArr.push @chunkPool.substr(0, idx)
      @chunkPool = @chunkPool.substr idx + 1

    return resultArr

  schedule: (request)->
    @requestPool[request.id] = request
    @conn.write JSON.stringify(request.payload) + String.fromCharCode(5)
    console.log chalk.gray "Send Request: #{request.payload.keyword} when #{request.payload.date.join(', ')}"

module.exports = {
  Connection: StyletripScheduleConnection
  Request: StyletripScheduleRequest
  Schedule: StyletripSchedule
}