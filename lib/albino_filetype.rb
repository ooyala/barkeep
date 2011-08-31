class AlbinoFiletype
  EXTENSION_TO_FILETYPE = {
    ".rb" => "Ruby",
    "Rakefile" => "Ruby",
    ".erb" => "RHTML",
    ".xml" => "XML",
    ".js" => "JavaScript",
    ".coffee" => "CoffeeScript",
    ".sh" => "Bash",
    ".css" => "CSS",
    ".less" => "CSS",
    ".py" => "Python",
    ".c" => "C",
    ".h" => "C",
    ".as" => "ActionScript",
    ".scala" => "Scala",
    ".sbt" => "Scala"
  }
  def self.detect_filetype(filename)
    # if path, separate file from path
    filename = filename.include?("/") ? filename[filename.index(%r{/[^/]+$})..-1] : filename
    return "Text only" unless filename.include?(".")
    extension = filename[filename.index(/\.[^\.]+$/)..-1]
    filetype = extension ? EXTENSION_TO_FILETYPE[extension] : EXTENSION_TO_FILETYPE[filename]
    filetype || "Text only"
  end
end
