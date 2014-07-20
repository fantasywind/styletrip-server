Engine = require "#{__dirname}/styletrip-engine"
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
  Connection: Engine.Connection
  scheduleRequestBind: scheduleRequestBind
}