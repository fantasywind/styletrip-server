chalk = require 'chalk'
Engine = require "#{__dirname}/styletrip-engine"
Member = require "#{__dirname}/styletrip-member"
utils = require "#{__dirname}/styletrip-utils"

scheduleRequestBind = (engine)->
  return (socket, next)=>

    # Schedule service request
    #
    # @param [Object] options request options
    # @option options [String] keyword keyword to search
    # @option options [Array] dates timestamp array of vacation date
    socket.on 'scheduleRequest', (options)->
      {keyword, dates} = options or {}

      request = new Engine.Request
        engine: engine
        socket: socket
        conditions:
          keyword: keyword
          dates: dates or utils.recentHoliday()
      request.send (err, result, finish = false)->
        socket.emit 'failed', err if err

        if !finish
          socket.emit 'scheduleResult',
            schedule_id: result.schedule_id
            part: result.chunk_part
            next: result.has_next
            err: result.err
            chunk: result.results
        else
          # Saving member history
          if socket.session.member
            request.saveHistory socket.session.member, (err)->
              socket.emit 'failed', err if err

    # Schedule query
    #
    # @param [Object] options query options
    # @option options [String] id schedule id to query
    # @option options [Number] version version to query
    socket.on 'scheduleQuery',(options)->
      {id, version} = options or {}

      console.log chalk.gray "[Schedule] Find By ID: #{id}" + if version then " ##{version}" else ""

      schedule = new Engine.Schedule
        id: id
        version: version

      schedule.on 'error', (err)->
        socket.emit 'failed', err

      schedule.on 'fetched', ->
        socket.emit 'scheduleResult', 
          schedule_id: id
          version: if version then version else 1
          part: 1
          next: false
          err: null
          chunk: schedule.toObject()

    next()

module.exports = {
  Member: Member.Controller
  Connection: Engine.Connection
  scheduleRequestBind: scheduleRequestBind
}