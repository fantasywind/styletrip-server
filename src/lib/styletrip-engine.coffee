uuid = require 'node-uuid'
net = require 'net'
chalk = require 'chalk'
mongoose = require 'mongoose'
errorParser = require 'error-message-parser'
Schedule = mongoose.model 'Schedule'
Member = mongoose.model 'Member'

class StyletripSchedule
  constructor: (options)->
    {@id} = options or {}

    fetchData() if @id

  fetchData: ->

  toObject: ->


class StyletripView
  constructor: (options)->

class StyletripDailySchedule
  constructor: (options)->
    {date, @view, @from, daily_cost} = options or {}

    @date = new Date date
    @cost = daily_cost

  add: ->
    @view = @view.concat arguments

class StyletripScheduleRequest
  constructor: (options)->
    {@conditions, @engine} = options or {}

    @schedules = []

  send: (@callback)->
    throw new Error "You have to initial request object." if !@engine or !@conditions

    @prepareRequest()
    @engine.schedule @

  chunk: (chunk)->
    console.log chalk.gray "[Engine] ReqID: #{chunk.schedule_id}, Part: #{chunk.chunk_part}, hasNext: #{chunk.has_next}"
    @schedule_id ?= chunk.schedule_id

    @schedules.push new StyletripDailySchedule result for result in chunk.results
    @callback null, chunk

    @done() if !chunk.has_next

  done: ->
    # Caching Schedule Result
    schedule = new Schedule
      _id: @schedule_id
      chunks: @schedules
    schedule.save (err, schedule)=>
      if err
        @callback errorParser.generateError 403
        console.log chalk.red "Create schedule cache failed: #{err}"
      else
        @callback null, schedule, true

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