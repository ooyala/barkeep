class AlbinoFiletype
  EXTENSION_TO_FILETYPE = {
    ".rb" => :ruby,
    "Rakefile" => :ruby,
    "Capfile" => :ruby,
    "Gemfile" => :ruby,
    ".erb" => :rhtml,
    ".xml" => :xml,
    ".js" => :javascript,
    ".coffee" => :coffeescript,
    ".sh" => :bash,
    ".css" => :css,
    ".less" => :scss,
    ".py" => :python,
    ".c" => :c,
    ".h" => :c,
    ".as" => :actionscript,
    ".scala" => :scala,
    ".sbt" => :scala,
    ".java" => :java,
    ".jsp" => :jsp
  }
  def self.detect_filetype(filename)
    # if path, separate file from path
    filename = filename.include?("/") ? filename[filename.index(%r{/[^/]+$})..-1] : filename
    return :text unless filename.include?(".")
    extension = filename[filename.index(/\.[^\.]+$/)..-1]
    filetype = extension ? EXTENSION_TO_FILETYPE[extension] : EXTENSION_TO_FILETYPE[filename]
    filetype || :text
  end
end
