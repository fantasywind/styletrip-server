FacebookStrategy = require('passport-facebook').Strategy
mongoose = require 'mongoose'
Member = mongoose.model "Member"

class StrategyWrapper
  constructor: (passport)->
    @strategy = new FacebookStrategy
      clientID: process.env.FB_APP_ID
      clientSecret: process.env.FB_APP_SECRET
      callbackURL: process.env.FB_REDIRECT_URL
      passReqToCallback: true
    , @callback

    passport.use @strategy

  done: (session, next)->
    return (err, member)->
      if err
        next err
      else
        session.member = member
        next null, member

  callback: (req, accessToken, refreshToken, profile, next)->
    # hijack done
    done = @done req.session, next

    Member.findOne
      facebookID: profile.id
    , (err, member)->
      # Not Found
      if !member
        # Find same mail
        if profile.email
          Member.findOne
            email: profile.email
          , (err, member)->

            if !member
              member = new Member
                facebookID: profile.id
                facebookAccessToken: accessToken
                name: profile.displayName

              done err, member

            else
              member.facebookID = profile.id
              member.facebookAccessToken = accessToken
              member.name = if !!member.name then member.name else profile.displayName
              member.save (err, member)->
                # Combined tmp user
                if req.session.member and req.session.member.guest
                  member.combineGuest req.session.member, (err, member)-> done err, member
                else
                  done err, member
            
        else
          member = new Member
            facebookID: profile.id
            facebookAccessToken: accessToken
            name: profile.displayName

          # Combined tmp user
          if req.session.member and req.session.member.guest
            member.combineGuest req.session.member, (err, member)-> done err, member
          else
            done err, member
        
      else
        # Combined tmp user
        if req.session.member and req.session.member.guest
          member.combineGuest req.session.member, (err, member)-> done err, member
        else if req.session.member and !req.session.member.guest
          member.combineExist profile.id, accessToken, profile.displayName, (err, member)-> done err, member
        else
          done err, member


module.exports = StrategyWrapper