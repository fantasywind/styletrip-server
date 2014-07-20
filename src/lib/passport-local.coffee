LocalStrategy = require('passport-local').Strategy
mongoose = require 'mongoose'
Member = mongoose.model "Member"

module.exports = (passport)->
  passport.use new LocalStrategy (username, password, done)->
    
    Member.findOne
      email: username
    , (err, member)->
      return done err if err

      # Not Found
      if !member
        return done null, false,
          message: 'Incorrect username.'

      # Check Password
      if !member.validPasspord password
        return done null, false,
          message: 'Incorrect pasword.'

      done null, member
    