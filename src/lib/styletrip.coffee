Engine = require "#{__dirname}/styletrip-engine"
Member = require "#{__dirname}/styletrip-member"
utils = require "#{__dirname}/styletrip-utils"

scheduleRequestBind = (engine)->
  return (socket, next)=>
    socket.on 'scheduleRequest', (options)=>
      {keyword, dates} = options or {}

      request = new Engine.Request
        engine: engine
        socket: socket
        conditions:
          keyword: keyword
          dates: dates or utils.recentHoliday()
      request.send()

    next()

module.exports = {
  Member: Member.Controller
  Connection: Engine.Connection
  scheduleRequestBind: scheduleRequestBind
}