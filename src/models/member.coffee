mongoose = require 'mongoose'
bcrypt = require 'bcrypt-nodejs'

MemberSchema = mongoose.Schema
  email: String
  name: String
  username: String
  password: String
  facebookID: String
  facebookAccessToken: String
  scheduleHistory: [String]

# Hash Generator
MemberSchema.methods.hashPassword = (password)->
  bcrypt.hashSync password, bcrypt.genSaltSync(8), null

# Check password
MemberSchema.methods.validPassword = (password)->
  bcrypt.compaseSync password, @password

module.exports = mongoose.model "Member", MemberSchema