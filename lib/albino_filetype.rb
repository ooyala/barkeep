class AlbinoFiletype
  EXTENSION_TO_FILETYPE = {
    ".rb" => :ruby,
    "Rakefile" => :ruby,
    "Capfile" => :ruby,
    "Gemfile" => :ruby,
    "Makefile" => :make,
    ".erb" => :rhtml,
    ".xml" => :xml,
    ".js" => :javascript,
    ".coffee" => :coffeescript,
    ".sh" => :bash,
    ".css" => :css,
    ".less" => :scss,
    ".py" => :python,
    ".c" => :c,
    ".h" => :cpp,
    ".hpp" => :cpp,
    ".cpp" => :cpp,
    ".inl" => :cpp,
    ".as" => :actionscript,
    ".scala" => :scala,
    ".sbt" => :scala,
    ".java" => :java,
    ".jsp" => :jsp
  }
  def self.detect_filetype(filename)
    # if path, separate file from path
    filename = filename.include?("/") ? filename[(filename.index(%r{/[^/]+$}) + 1)..-1] : filename
    extension_index = filename.index(/\.[^\.]+$/)
    extension = extension_index ? filename[extension_index..-1] : nil
    filetype = extension ? EXTENSION_TO_FILETYPE[extension] : EXTENSION_TO_FILETYPE[filename]
    filetype || :text
  end
end
