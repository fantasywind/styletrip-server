FacebookStrategy = require('passport-facebook').Strategy
passportConfig = require "#{__dirname}/../config/passport"
mongoose = require 'mongoose'
Member = mongoose.model "Member"

module.exports = (passport)->
  passport.use new FacebookStrategy
    clientID: passportConfig.facebookAppID
    clientSecret: passportConfig.facebookAppSecret
    callbackURL: passportConfig.facebookRedirectUrl
  , (accessToken, refreshToken, profile, done)->
    
    Member.findOne
      facebookID: profile.id
    , (err, member)->
      return done err if err

      createMember = ->
        member = new Member
          facebookID: profile.id
          facebookAccessToken: accessToken
          name: profile.displayName
        member.save (err, member)->
          return done err if err

          done null, member

      # Not Found
      if !member
        # Find same mail
        if profile.email
          Member.findOne
            email: profile.email
          , (err, member)->
            return done err if err

            if !member
              createMember()
            else
              member.facebookID = profile.id
              member.facebookAccessToken = accessToken
              member.name = profile.displayName if !member.name or member.name is ''
              member.save (err, member)->
                return done err if err

                done null, member
        else
          createMember()
      else
        done null, member