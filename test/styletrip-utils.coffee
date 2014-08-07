should = require 'should'
XDate = require 'xdate'

rewire = require 'rewire'
utils = rewire "#{__dirname}/../src/lib/styletrip-utils"

describe 'styletrip.utils', ->
  it 'should recentHoliday function exported', ->
    utils.recentHoliday.should.be.type 'function'

  describe '#recentHoliday()', ->

    it 'should return array', ->
      utils.recentHoliday().should.be.an.Array

    it 'should return timestamp in array', ->
      for result in utils.recentHoliday()
        result.should.be.a.Number
        new Date(result).toString().should.not.equal "Invalid Date"

    it 'should 8 a.m. when sunday morning', ->
      utils.__set__ 'XDate', ->
        date = new XDate
        day = date.getDay()
        date.addDays -day
        date.setHours 9
        return date

      utils.recentHoliday().should.be.an.Array
      startTime = new XDate utils.recentHoliday()[0]
      startTime.getDay().should.be.equal 0
      startTime.getHours().should.be.equal 8
      startTime.getMinutes().should.be.equal 0
      startTime.getSeconds().should.be.equal 0
      startTime.getMilliseconds().should.be.equal 0

    it 'should twice 8 a.m. weekend when saturday morning', ->
      utils.__set__ 'XDate', ->
        date = new XDate
        day = date.getDay()
        date.addDays 6 - day
        date.setHours 9
        return date

      utils.recentHoliday().should.be.an.Array
      startTime1 = new XDate utils.recentHoliday()[0]
      startTime1.getDay().should.be.equal 6
      startTime1.getHours().should.be.equal 8
      startTime1.getMinutes().should.be.equal 0
      startTime1.getSeconds().should.be.equal 0
      startTime1.getMilliseconds().should.be.equal 0
      startTime2 = new XDate utils.recentHoliday()[1]
      startTime2.getDay().should.be.equal 0
      startTime2.getHours().should.be.equal 8
      startTime2.getMinutes().should.be.equal 0
      startTime2.getSeconds().should.be.equal 0
      startTime2.getMilliseconds().should.be.equal 0

    it 'should 8 a.m. next day when saturday evening', ->
      utils.__set__ 'XDate', ->
        date = new XDate
        day = date.getDay()
        date.addDays 6 - day
        date.setHours 11
        return date

      utils.recentHoliday().should.be.an.Array
      startTime = new XDate utils.recentHoliday()[0]
      startTime.getDay().should.be.equal 0
      startTime.getHours().should.be.equal 8
      startTime.getMinutes().should.be.equal 0
      startTime.getSeconds().should.be.equal 0
      startTime.getMilliseconds().should.be.equal 0


    it 'should next weekend when week day', ->
      utils.__set__ 'XDate', ->
        date = new XDate
        day = date.getDay()
        date.addDays -day + 2
        date.setHours 11
        return date

      weekday = new XDate
      day = weekday.getDay()
      weekday.addDays -day + 2

      utils.recentHoliday().should.be.an.Array
      startTime1 = new XDate utils.recentHoliday()[0]
      startTime1.getTime().should.be.greaterThan weekday.getTime()
      startTime1.getDay().should.be.equal 6
      startTime1.getHours().should.be.equal 8
      startTime1.getMinutes().should.be.equal 0
      startTime1.getSeconds().should.be.equal 0
      startTime1.getMilliseconds().should.be.equal 0
      startTime2 = new XDate utils.recentHoliday()[1]
      startTime2.getTime().should.be.greaterThan weekday.getTime()
      startTime2.getDay().should.be.equal 0
      startTime2.getHours().should.be.equal 8
      startTime2.getMinutes().should.be.equal 0
      startTime2.getSeconds().should.be.equal 0
      startTime2.getMilliseconds().should.be.equal 0