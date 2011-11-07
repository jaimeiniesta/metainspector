# -*- encoding: utf-8 -*-

$:.push File.expand_path("../lib", __FILE__)
require "meta_inspector/version"

Gem::Specification.new do |s|
  s.name        = "metainspector"
  s.version     = MetaInspector::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jaime Iniesta"]
  s.email       = ["jaimeiniesta@gmail.com"]
  s.homepage    = "https://github.com/jaimeiniesta/metainspector"
  s.summary     = %q{MetaInspector is a ruby gem for web scraping purposes, that returns a hash with metadata from a given URL}
  s.description = %q{MetaInspector lets you scrape a web page and get its title, charset, link and meta tags}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'nokogiri', '1.5.0'
  s.add_runtime_dependency 'charguess', '1.3.20110226181011'
  s.add_runtime_dependency 'rash', '0.3.0'

  s.add_development_dependency 'rspec', '2.6.0'
  s.add_development_dependency 'fakeweb', '1.3.0'
  s.add_development_dependency 'awesome_print', '0.4.0'
  s.add_development_dependency 'rake', '0.9.2'
end