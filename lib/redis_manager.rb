require "redis"

class RedisManager
  @@redis = nil
  def self.get_redis_instance
    return @@redis if @@redis
    begin
      @@redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)
      @@redis.ping
    rescue
      warn "Cannot connect to Redis"
      @@redis = nil
    end
    @@redis
  end
end
