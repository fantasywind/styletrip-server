FacebookStrategy = require('passport-facebook').Strategy
mongoose = require 'mongoose'
Member = mongoose.model "Member"

module.exports = (passport)->
  passport.use new FacebookStrategy
    clientID: process.env.FB_APP_ID
    clientSecret: process.env.FB_APP_SECRET
    callbackURL: process.env.FB_REDIRECT_URL
    passReqToCallback: true
  , (req, accessToken, refreshToken, profile, next)->
    
    # hijack done
    done = (err, member)->
      if err
        next err
      else
        req.session.member = member
        next null, member

    Member.findOne
      facebookID: profile.id
    , (err, member)->
      return done err if err

      # Not Found
      if !member
        # Find same mail
        if profile.email
          Member.findOne
            email: profile.email
          , (err, member)->
            return done err if err

            if !member
              member = new Member
                facebookID: profile.id
                facebookAccessToken: accessToken
                name: profile.displayName

              done null, member

            else
              member.facebookID = profile.id
              member.facebookAccessToken = accessToken
              member.name = profile.displayName if !member.name or member.name is ''
              member.save (err, member)->
                return done err if err

                done null, member

            # Combined tmp user
            member.combineGuest req.session.member if req.session.member
            
        else
          member = new Member
            facebookID: profile.id
            facebookAccessToken: accessToken
            name: profile.displayName

          # Combined tmp user
          member.combineGuest req.session.member if req.session.member

          done null, member
        
      else
        # Combined tmp user
        member.combineGuest req.session.member if req.session.member

        done null, member