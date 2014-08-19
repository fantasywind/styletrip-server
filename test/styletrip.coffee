should = require 'should'
async = require 'async'
sinon = require 'sinon'
EventEmitter = require('events').EventEmitter

styletrip = require "#{__dirname}/../src/lib/styletrip"

describe "styletrip", ->

  it 'should exported correct functions', ->
    styletrip.Member.should.be.a.Function
    styletrip.Connection.should.be.a.Function
    styletrip.scheduleRequestBind.should.be.a.Function

  describe '#scheduleRequestBind()', ->
    scheduleRequestBind = null

    beforeEach ->
      engine = {}
      scheduleRequestBind = new styletrip.scheduleRequestBind engine

    it 'should socket event will be binded', (done)->
      eventList = [
        'scheduleRequest'
        'scheduleQuery'
      ]
      socket =
        on: (name, cb)->
          eventList.splice eventList.indexOf(name), 1

      scheduleRequestBind socket, ->
        eventList.length.should.be.equal 0
        done()

    describe 'Event: scheduleRequest', ->

    describe 'Event: scheduleQuery', ->

      it 'should query event (with version) will print on console', (done)->
        socket = new EventEmitter

        scheduleRequestBind socket, ->

          spyConsole = sinon.spy console, 'log'
          (->
            try
              socket.emit 'scheduleQuery',
                id: '_notfoundscheduleid'
                version: 1
            catch e
              throw new Error()
          ).should.throw()
          spyConsole.calledWith("\u001b[2m[Schedule] Find By ID: _notfoundscheduleid #1\u001b[22m").should.be.true
          spyConsole.restore()
          done()

      it 'should query event (without version) will print on console', (done)->
        socket = new EventEmitter

        scheduleRequestBind socket, ->

          spyConsole = sinon.spy console, 'log'
          socket.emit 'scheduleQuery',
            id: '_notfoundscheduleid'
          spyConsole.calledWith("\u001b[2m[Schedule] Find By ID: _notfoundscheduleid\u001b[22m").should.be.true
          spyConsole.restore()
          done()