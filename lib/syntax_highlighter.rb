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

  def initialize(redis = nil)
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

    highlighted = SyntaxHighlighter.global_highlighting(SyntaxHighlighter.pygmentize(file_type, blob.data))

    begin
      if @redis
        @redis.set(cache_key, highlighted)
        @redis.expire(cache_key, WEEK)
      end
    rescue Exception => e
      Logging.logger.error("Redis failed with message: #{e.message}")
    end

    highlighted
  end

  def self.pygmentize(file_type, text)
    Pygments.highlight(text, :lexer => file_type, :options => {
      :encoding => "utf-8", :nowrap => true, :stripnl => false, :stripall => false
    })
  end

  # Apply further filtering to the pygmentized source. Right now we're just using it to highlight trailing
  # whitespace.
  # NOTE(caleb): It might be possible/better to do this in Python. However, that will probably involve
  # modifying Pygments (monkey-patching isn't so simple in Python) and in general will be more work.
  def self.global_highlighting(pygmentized_text)
    pygmentized_text.gsub(/[ \t]+$/) { |whitespace| "<span class='trailingWhitespace'>#{whitespace}</span>" }
  end

  def self.redis_cache_key(repo_name, blob)
    "#{repo_name}::#{blob.id}"
  end
end
