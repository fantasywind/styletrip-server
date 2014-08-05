express = require 'express'
passport = require 'passport'
mongoose = require 'mongoose'
randtoken = require 'rand-token'
chalk = require 'chalk'
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
    'user_tagged_places'
    'user_location'
    'user_friends'
    'user_hometown'
    'user_interests'
    'user_likes'
    'user_birthday'
  ]

router.get '/facebook/callback', passport.authenticate 'facebook', 
  successRedirect: '/api/auth/success'
  failureRedirect: '/api/auth/failed'

router.get '/success', (req, res)->
  token = randtoken.generate 60
  expires = new Date Date.now() + 1209600000 # Two week

  req.user.token.secret = token
  req.user.token.expires = expires
  req.user.save (err, user)-> console.error chalk.red "Update user token error" if err

  res.cookie 'token', token,
    path: '/'
    expires: expires
    httpOnly: true
  res.redirect '/?facebookLogined=success'

router.get '/failed', (req, res)->
  res.redirect '/?err=facebookLogin'

router.get '/updateToken', (req, res)->
  if req.session.token
    expires = new Date req.session.expires
    if req.session.token and expires.getTime() >= Date.now()
      res.cookie 'token', req.session.token,
        path: '/'
        expires: expires
        httpOnly: true
      res.json
        status: true
    else
      res.sendError 407
  else
    res.sendError 406

passport.serializeUser (user, done)->
  done null, user.id or user._id

passport.deserializeUser (id, done)->
  Member.findById id, (err, user)->
    done err, user

# Generate Guest
passport.generateGuest = (cb)->
  token = randtoken.generate 60
  expires = new Date Date.now() + 1209600000 # Two week

  guest = new Member
    guest: true
    token:
      secret: token
      expires: expires

  guest.save (err, guest)->
    chalk.red "Create guest member failed: #{err}" if err

    cb err, guest

module.exports = passport