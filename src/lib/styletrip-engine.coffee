uuid = require 'node-uuid'
net = require 'net'
chalk = require 'chalk'
mongoose = require 'mongoose'
errorParser = require 'error-message-parser'
ScheduleModel = mongoose.model 'Schedule'

class StyletripScheduleRequest
  constructor: (options)->
    {@socket, @conditions, @engine} = options or {}

  send: ->
    throw new Error "You have to initial request object." if !@engine or !@socket or !@conditions

    @prepareRequest()
    @engine.schedule @

  done: (err, result)->
    if err
      @socket.emit 'failed', errorParser.generateError err.code
    else
      @socket.emit 'scheduleResult', result

      # Caching Schedule Result
      schedule = new ScheduleModel
        _id: result.schedule_id
        chunks: result.results
      schedule.save (err, schedule)=>
        if err
          @socket.emit 'failed', errorParser.generateError 403 if err
          console.log chalk.red "Create schedule cache failed: #{err}"
        else
          # Saving member history
          if @socket.session.member
            @socket.session.member.addSchedule result.schedule_id, (err)->
              @socket.emit 'failed', errorParser.generateError 403 if err

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
      console.log chalk.green "Schedule Engine Connection Created."

    @conn.on 'error', (msg)=>
      console.error chalk.red msg
      @conn.destroy()

      @retryTimeout = @retryTimeout * 2
      if @retryTimeout < 300000
        console.log chalk.gray "Retry connection in #{@retryTimeout / 1000} second(s)"
        setTimeout =>
          @createSocket port, host
        , @retryTimeout
      else
        console.error chalk.red "Failed retry connect to engine..."
        throw new Error 'Error on connect to engine.'

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

      if @requestPool[result.request_id]
        if result.status
          @requestPool[result.request_id].done null, result
        else
          err = new Error "Engine Error: (#{result.code}) #{result.msg}"
          err.code = result.code or 405
          console.log chalk.red err.toString()
          @requestPool[result.request_id].done err
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
}