silence_stream(STDERR) do
  require "pygments"
  RubyPython.start
  # This generates an annoying, one-time import error from within the Pygments gem. Force the import now,
  # while we're silencing this stream.
  RubyPython.import("pygments")
end

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/logging"

class SyntaxHighlighter

  WEEK = 60*60*24*7

  def initialize(redis=nil)
    @redis = redis
  end

  def colorize_blob(repo_name, file_type, blob)
    return "" if blob.nil?
    if @redis
      cache_key = SyntaxHighlighter.redis_cache_key(repo_name, blob)
      cached = @redis.get(cache_key)
      @redis.expire(cache_key, WEEK)
      return cached if cached
    end

    highlighted = SyntaxHighlighter.pygmentize(file_type, blob.data)

    begin
      if @redis
        @redis.set(cache_key, highlighted)
        @redis.expire(cache_key, WEEK)
      end
    rescue Exception => e
      Logging.logger.error("Redis failed with message: #{e.message}")
    end

    return highlighted
  end

  def self.pygmentize(file_type, text)
    Pygments.highlight(text, :lexer => file_type, :options => { :encoding => "utf-8", :nowrap => true,
        :stripnl => false, :stripall => false })
  end

  def self.redis_cache_key(repo_name, blob)
    return "#{repo_name}::#{blob.id}"
  end
end
