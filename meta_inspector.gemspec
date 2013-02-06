# -*- encoding: utf-8 -*-
require File.expand_path('../lib/meta_inspector/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jaime Iniesta"]
  gem.email         = ["jaimeiniesta@gmail.com"]
  gem.description   = %q{MetaInspector lets you scrape a web page and get its title, charset, link and meta tags}
  gem.summary       = %q{MetaInspector is a ruby gem for web scraping purposes, that returns a hash with metadata from a given URL}
  gem.homepage      = "https://github.com/jaimeiniesta/metainspector"

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {spec}/*`.split("\n")
  gem.name          = "metainspector"
  gem.require_paths = ["lib"]
  gem.version       = MetaInspector::VERSION

  gem.add_dependency 'nokogiri', '~> 1.5'
  gem.add_dependency 'rash', '0.3.2'
  gem.add_dependency 'open_uri_redirections', '~> 0.1.0'
  gem.add_dependency 'addressable', '~> 2.3.2'

  gem.add_development_dependency 'rspec', '2.12.0'
  gem.add_development_dependency 'fakeweb', '1.3.0'
  gem.add_development_dependency 'awesome_print', '1.1.0'
  gem.add_development_dependency 'rake', '~> 10.0.3'
end
