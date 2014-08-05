mongoose = require 'mongoose'
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
  scheduleHistory: [String]
  token:
    secret: String
    expires: Date

# Hash Generator
MemberSchema.methods.hashPassword = (password)->
  bcrypt.hashSync password, bcrypt.genSaltSync(8), null

# Check password
MemberSchema.methods.validPassword = (password)->
  bcrypt.compaseSync password, @password

module.exports = mongoose.model "Member", MemberSchema