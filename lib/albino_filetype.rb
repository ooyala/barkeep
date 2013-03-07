class AlbinoFiletype
  EXTENSION_TO_FILETYPE = {
    ".as"         => :actionscript,
    ".aspx"       => :"aspx-cs",
    ".c"          => :c,
    ".cc"         => :cpp,
    ".clj"        => :clojure,
    ".coffee"     => :coffeescript,
    ".cpp"        => :cpp,
    ".cs"         => :csharp,
    ".css"        => :css,
    ".erb"        => :rhtml,
    ".go"         => :go,
    ".god"        => :ruby,
    ".h"          => :cpp,
    ".hpp"        => :cpp,
    ".inl"        => :cpp,
    ".java"       => :java,
    ".js"         => :javascript,
    ".json"       => :json,
    ".jsp"        => :jsp,
    ".less"       => :scss,
    ".py"         => :python,
    ".rake"       => :ruby,
    ".rb"         => :ruby,
    ".sbt"        => :scala,
    ".scala"      => :scala,
    ".scss"       => :scss,
    ".sh"         => :bash,
    ".vb"         => :vbnet,
    ".xml"        => :xml,
    "Cakefile"    => :coffeescript,
    "Capfile"     => :ruby,
    "Gemfile"     => :ruby,
    "Makefile"    => :make,
    "Rakefile"    => :ruby,
    "Vagrantfile" => :ruby
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
