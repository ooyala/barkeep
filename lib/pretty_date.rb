# This module shamelessly copy-pasted from here:
# http://stackoverflow.com/questions/195740/how-do-you-do-relative-time-in-rails
# (with adjustments)

class Time
  def to_pretty
    a = (Time.now - self).to_i

    case a
      when 0 then return 'just now'
      when 1 then return 'a second ago'
      when 2..59 then return a.to_s+' seconds ago'
      when 60..89 then return 'a minute ago' #90 = 1.5 minutes
      when 90..3569 then return (a/60.0).round.to_s+' minutes ago'
      when 3570..5399 then return 'an hour ago' # 3600 = 1 hour
      when 5400..84599 then return ((a)/3600.0).round.to_s+' hours ago'
      when 84600..129599 then return 'a day ago'
      when 129600..561599 then return (a/(60*60*24.0)).round.to_s+' days ago'
      when 561600..1036800 then return strftime("%b %d, %Y")
    end
    return strftime("%b %d, %Y")
  end
end
