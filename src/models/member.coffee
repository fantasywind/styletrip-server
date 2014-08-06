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
  bcrypt.compaseSync password, @password

MemberSchema.methods.combineGuest = (guest)->
  return if !guest or !guest._id

  return console.log chalk.gray "Same combined guest request! Abort." if guest._id is @_id

  Member.findById guest._id, (err, guestAccount)=>
    console.error chalk.red "Find guest member data failed (#{err})" if err

    if !guestAccount
      console.log chalk.gray "Not found guest member to combined."
    else
      # Schedule History
      @scheduleHistory.addToSet guestAccount.scheduleHistory
      @save (err, member)->
        return console.error chalk.red "Update member document error." if err

        Member.findByIdAndRemove guest._id, (err)->
          return console.error chalk.red "Remove guest document error." if err

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