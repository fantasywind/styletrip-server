express = require 'express'
passport = require 'passport'
require("#{__dirname}/passport-local") passport
require("#{__dirname}/passport-facebook") passport

passport.router = router = express.Router()
router.post '/local', passport.authenticate 'local',
  successRedirect: '/auth/success'
  failureRedirect: '/auth/failed'
router.post '/facebook', passport.authenticate 'facebook',
  scope: [
    'email'
  ]
  successRedirect: '/auth/success'
  failureRedirect: '/auth/failed'

module.exports = passport