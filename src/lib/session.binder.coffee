# session binder from: session.socket.io 
# source: https://github.com/wcamarao/session.socket.io
# Copyright (c) 2012 Wagner Camarao <functioncallback@gmail.com>
# Copyright (c) 2014 Chia Yu Pai <fantasyatelier@gmail.com>
# license: MIT
signature = require 'cookie-signature'
uid = require('uid-safe').sync

findCookie = (handshakeInput)->
  key = 'connect.sid'
  handshake = JSON.parse JSON.stringify handshakeInput
  return if handshake.cookies[key] then (handshake.cookies[key].match(/\:(.*)\./) or []).pop() else null

module.exports = 
  http: (req, res, next)->
    if req.cookies['socket.sid']
      req.headers.cookie = req.headers.cookie.replace /connect\.sid=(.*);?/, "connect.sid=#{req.cookies['socket.sid']};"
      req.headers.cookie = req.headers.cookie.replace /socket\.sid=(.*);?/, ""
      res.cookie 'connect.sid', req.cookies['socket.sid'],
        path: '/'
        httpOnly: true
      res.clearCookie 'socket.sid',
        path: '/'
    next()

  socket: (cookieParser, memoryStore, secret, socket, next)->
    handshake = socket.handshake
    if handshake.headers.cookie
      cookieParser() handshake, {}, ->
        sid = findCookie handshake
        memoryStore.get sid, (alwaysNull, session)->
          
          if session
            socket.sessionID = sid
            socket.sessionStore = memoryStore
            socket.session = session
            memoryStore.set sid, socket.session, ->
              next()
          else
            sid = uid 24
            socket.sessionID = sid
            socket.sessionStore = memoryStore
            socket.session = 
              cookie: 
                originalMaxAge: null
                expires: null
                httpOnly: true
                path: '/'

            memoryStore.set sid, socket.session, ->
              socket.emit 'setCookie',
                "socket.sid": 's:' + signature.sign sid, secret
              next()
    else
      next()