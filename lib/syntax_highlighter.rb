require "pygments"

class SyntaxHighlighter

  def initialize(redis=nil)
    @redis = redis
  end

  def colorize_blob(repo_name, file_type, blob)
    return "" if blob.nil?
    if @redis
      cache_key = self.key(repo_name, blob)
      cached = @redis.get(cache_key)
      return cached if cached
    end

    highlighted = self.pygmentize(file_type, blob.data)

    @redis.set(cache_key, highlighted) if @redis

    return highlighted
  end

  def pygmentize(file_type, text)
    lexer = Pygments::Lexer.find_by_name(file_type)
    return lexer.highlight(text, { :encoding => "utf-8", :nowrap => true, :stripnl => false,
        :stripall => false })
  end

  def key(repo_name, blob)
    return "#{repo_name}::#{blob.id}"
  end
end
