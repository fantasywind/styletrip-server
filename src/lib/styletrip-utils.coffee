XDate = require 'xdate'

recentHoliday = ->
  today = new XDate()

  # If Sunday Morning
  if today.getDay() is 0 and today.getHours() <= 10
    return [today.clearTime().setHours(8).getTime()]

  # If Saturday Morning
  if today.getDay() is 6 and today.getHours() <= 10
    return [
      today.clearTime().setHours(8).getTime()
      today.addDays(1).clearTime().setHours(8).getTime()
    ]

  # If Saturday Evening
  if today.getDay() is 6 and today.getHours() > 10
    return [today.addDays(1).clearTime().setHours(8).getTime()]

  # Else -> Next Sat. + Sun.
  day = today.getDay()
  nextSat = today.addDays(6 - day)
  return [
    nextSat.clearTime().setHours(8).getTime()
    nextSat.addDays(1).clearTime().setHours(8).getTime()
  ]

module.exports = {
  recentHoliday: recentHoliday
}