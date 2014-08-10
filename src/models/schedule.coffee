mongoose = require 'mongoose'

ScheduleSchema = mongoose.Schema
  _id: String
  keyword: String
  dates: [Number]
  from: {}
  chunks: []

module.exports = mongoose.model "Schedule", ScheduleSchema