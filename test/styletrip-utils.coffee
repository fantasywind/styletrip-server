should = require 'should'

utils = require "#{__dirname}/../src/lib/styletrip-utils"

describe 'styletrip.utils', ->
  it 'should recentHoliday function exported', ->
    utils.recentHoliday.should.be.type 'function'

describe 'styletrip.utils.recentHoliday', ->
  it 'should return array', ->
    utils.recentHoliday().should.be.an.Array

  it 'should return timestamp in array', ->
    for result in utils.recentHoliday()
      result.should.be.a.Number
      new Date(result).toString().should.not.equal "Invalid Date"