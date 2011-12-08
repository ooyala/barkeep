# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "barkeep-client"
  s.version     = "0.0.4"
  s.authors     = ["Caleb Spare"]
  s.email       = ["caleb@ooyala.com"]
  s.homepage    = "https://github.com/ooyala/barkeep"
  s.summary     = %q{Barkeep command-line client}
  s.description = %q{A command-line client for Barkeep's REST API.}

  s.rubyforge_project = "barkeep-client"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "trollop", "~> 1.16.2"
  s.add_dependency "dedent", "~> 0.0.2"
end
