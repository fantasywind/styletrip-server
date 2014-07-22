mongoose = require 'mongoose'

ScheduleSchema = mongoose.Schema
  _id: String
  chunks: []

module.exports = mongoose.model "Schedule", ScheduleSchema