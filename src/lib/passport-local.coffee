LocalStrategy = require('passport-local').Strategy
mongoose = require 'mongoose'
Member = mongoose.model "Member"

module.exports = (passport)->
  passport.use new LocalStrategy
    passReqToCallback: true
  , (req, username, password, done)->
    
    Member.findOne
      email: username
    , (err, member)->
      # Not Found
      if !member
        return done err, false,
          message: 'Incorrect username.'

      # Check Password
      if !member.validPassword password
        return done err, false,
          message: 'Incorrect pasword.'

      # Combined tmp user
      if req.session.member and req.session.member.guest
        member.combineGuest req.session.member, (err, member)-> done err, member
      else
        done err, member
    