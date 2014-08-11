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
  handshake.secureCookies = (handshake.secureCookies[key].match(/\:(.*)\./) or []).pop() if handshake.secureCookies and handshake.secureCookies[key]
  handshake.signedCookies[key] = (handshake.signedCookies[key].match(/\:(.*)\./) or []).pop() if handshake.signedCookies and handshake.signedCookies[key]
  handshake.cookies[key] = (handshake.cookies[key].match(/\:(.*)\./) or []).pop() if handshake.cookies and handshake.cookies[key]

  return (handshake.secureCookies and handshake.secureCookies[key]) or (handshake.signedCookies and handshake.signedCookies[key]) or (handshake.cookies and handshake.cookies[key])

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
      cookieParser() handshake, {}, (err)->
        console.error 'could not look up session by key' if err
        sid = findCookie handshake
        memoryStore.get sid, (storeErr, session)->
          console.error 'could not look up session by key' if storeErr
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