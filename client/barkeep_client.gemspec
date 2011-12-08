# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "barkeep-client"
  s.version     = "0.0.1"
  s.authors     = ["Caleb Spare"]
  s.email       = ["caleb@ooyala.com"]
  s.homepage    = ""
  s.summary     = %q{Who is the barkeep?}
  s.description = %q{Who is the barkeep?}

  s.rubyforge_project = "barkeep-client"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
