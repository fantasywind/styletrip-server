Config = require "#{__dirname}/styletrip-config"
Engine = require "#{__dirname}/styletrip-engine"
utils = require "#{__dirname}/styletrip-utils"

class Styletrip
  constructor: ->
    @config = new Config

    if !@config.engine or !@config.engine.HOST or !@config.engine.PORT
      return throw new Error "Invalid Styletrip Engine Config. Check ./config/styletrip.json setting."

    @engine = new Engine.Connection
      host: @config.engine.HOST
      port: @config.engine.PORT

  scheduleRequestBind: ->
    return (socket, next)=>
      socket.on 'scheduleRequest', (options)=>
        {keyword, dates} = options or {}

        request = new Engine.Request
          engine: @engine
          socket: socket
          conditions:
            keyword: keyword
            dates: dates or utils.recentHoliday()
        request.send()

      next()

module.exports = new Styletrip