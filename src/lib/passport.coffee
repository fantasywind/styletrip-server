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
  res.redirect '/?facebookLogined=success'

router.get '/failed', (req, res)->
  res.redirect '/?err=facebookLogin'

passport.serializeUser (user, done)->
  done null, user.id or user._id

passport.deserializeUser (id, done)->
  Member.findById id, (err, user)->
    done err, user

module.exports = passport