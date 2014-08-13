mongoose = require 'mongoose'
chalk = require 'chalk'
bcrypt = require 'bcrypt-nodejs'

MemberSchema = mongoose.Schema
  email: String
  guest: Boolean
  name: String
  username: String
  password: String
  facebookID: String
  facebookAccessToken: String
  facebookData:
    location:
      id: String
      name: String
    hometown:
      id: String
      name: String
    birthday: String
    favorite_athletes: []
    favorite_teams: []
    sports: []
    likes: []
  scheduleHistory: []
  token:
    secret: String
    expires: Date

# Hash Generator
MemberSchema.methods.hashPassword = (password)->
  bcrypt.hashSync password, bcrypt.genSaltSync(8), null

# Check password
MemberSchema.methods.validPassword = (password)->
  bcrypt.compareSync password, @password

MemberSchema.methods.combineGuest = (guest, done)->
  return done new Error "Please pass guest." if !guest or !guest._id

  if guest._id is @_id
    done new Error "Same combined guest request! Abort."
  else
    Member.findById guest._id, (err, guestAccount)=>
      if err
        done new Error "Find guest member data failed (#{err})" 
      else
        if !guestAccount
          done new Error "Not found guest member to combined."
        else
          # Schedule History
          @scheduleHistory.addToSet scheduleID for scheduleID in guestAccount.scheduleHistory
          @save (err, member)->
            if err
              done err
            else
              Member.findByIdAndRemove guest._id, (err)-> done err, member

MemberSchema.methods.publicInfo = ->
  return {
    name: @name
    facebookID: @facebookID
  }

MemberSchema.methods.addSchedule = (scheduleID, done)->
  @scheduleHistory.push scheduleID
  @save (err, member)->
    return done err if err

    done null

module.exports = Member = mongoose.model "Member", MemberSchema