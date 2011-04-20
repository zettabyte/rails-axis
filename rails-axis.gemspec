# vim: set fileencoding=utf-8:
$:.push File.expand_path("../lib", __FILE__)
require "axis/version"

Gem::Specification.new do |s|
  s.name        = "rails-axis"
  s.version     = Axis::Version::STRING
  s.authors     = ["Kendall Gifford"]
  s.email       = ["kendall@titlemanagers.com"]
  s.homepage    = "http://todo.tld/rails-axis"
  s.license     = "TODO"
  s.summary     = "TODO: write awesome summary"
  s.description = <<-END.gsub(/^\s+/, "")
    TODO: write awesome description
  END

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "rails", "~> 3.0.7"
end
