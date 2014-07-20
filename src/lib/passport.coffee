express = require 'express'
passport = require 'passport'
mongoose = require 'mongoose'
Member = mongoose.model 'Member'
require("#{__dirname}/passport-local") passport
require("#{__dirname}/passport-facebook") passport

passport.router = router = express.Router()

router.post '/local', passport.authenticate 'local',
  successRedirect: '/api/auth/success'
  failureRedirect: '/api/auth/failed'

router.get '/facebook', passport.authenticate 'facebook',
  scope: [
    'email'
  ]

router.get '/facebook/callback', passport.authenticate 'facebook', 
  successRedirect: '/api/auth/success'
  failureRedirect: '/api/auth/failed'

router.get '/success', (req, res)->
  res.redirect '/?facebookLogined=success'

router.get '/failed', (req, res)->
  res.redirect '/?err=facebookLogin'

passport.serializeUser (user, done)->
  done null, user.id or user._id

passport.deserializeUser (id, done)->
  Member.findById id, (err, user)->
    done err, user

passport.socket = (errorParser)->

  return (socket, next)->
    socket.on 'loginStatus', ->
      user = socket.session.user
      if user
        socket.emit 'logined',
          facebookID: user.facebookID
          name: user.name
      else if socket.session.passport and socket.session.passport.user
        Member.findById socket.session.passport.user, (err, user)->
          if err
            socket.emit 'failed', errorParser.generateError 401, err
          else if !user
            socket.emit 'failed', errorParser.generateError 402
          else
            socket.session.user = user
            socket.emit 'logined',
              facebookID: user.facebookID
              name: user.name

    next()

module.exports = passport