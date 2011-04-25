# vim: set fileencoding=utf-8:
$:.push File.expand_path("../lib", __FILE__)
require "axis/version"

Gem::Specification.new do |s|
  s.name        = "rails-axis"
  s.version     = Axis::Version::STRING
  s.authors     = ["Kendall Gifford"]
  s.email       = ["kendall@titlemanagers.com"]
  s.homepage    = "http://gems.titlemanagers.com/rails-axis"
  s.license     = "PROPRIETARY"
  s.summary     = "Search, sort, and sub-form design-pattern for rails"
  s.description = <<-END.gsub(/^\s+/, "")
    Search, sort, and sub-form design-pattern for rails.

    This gem helps to build "index" forms that follow an MS-Access-inspired
    design-pattern. An "index" form becomes one that allows you to search and
    sort an associated resource. It integrates search-form construction
    helpers, pagination, and record sorting.

    This gem additionally facilitates the concept of having one of the listed
    records "selected" so its details can be displayed (and edited) on the
    same form (on another "panel"). It also supports embedding "sub-forms"
    that follow the same pattern, displaying, searching and sorting sub-
    resource records related to the currently selected "parent" record.

    Copyright (c) 2011, Title Managers Inc. - All Rights Reserved
  END

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "rails", "~> 3.0.7"
end
