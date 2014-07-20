class StyletripConfig
  constructor: (options)->
    {path} = options or {}

    config = require "#{__dirname}/../config/styletrip"
    for key, value of config
      @[key] = value

module.exports = StyletripConfig