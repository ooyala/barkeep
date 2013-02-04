require "redis"

class RedisManager
  @@redis = nil

  def self.redis_instance
    return @@redis if @@redis
    begin
      @@redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT,
                          :db => REDIS_DB)
      timeout(4) { @@redis.ping }
    rescue Timeout::Error
      warn "Timed out while connecting to Redis."
      @@redis = nil
    rescue StandardError
      warn "Cannot connect to Redis"
      @@redis = nil
    end
    @@redis
  end

  def self.reconnect
    @@redis = nil
    redis_instance
  end
end
