# -*- encoding: utf-8 -*-
require File.expand_path('../lib/meta_inspector/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jaime Iniesta"]
  gem.email         = ["jaimeiniesta@gmail.com"]
  gem.description   = %q{MetaInspector lets you scrape a web page and get its title, charset, link and meta tags}
  gem.summary       = %q{MetaInspector is a ruby gem for web scraping purposes, that returns a hash with metadata from a given URL}
  gem.homepage      = "http://jaimeiniesta.github.io/metainspector/"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {spec}/*`.split("\n")
  gem.name          = "metainspector"
  gem.require_paths = ["lib"]
  gem.version       = MetaInspector::VERSION

  gem.add_dependency 'nokogiri', '~> 1.6'
  gem.add_dependency 'faraday'
  gem.add_dependency 'faraday_middleware'
  gem.add_dependency 'addressable', '~> 2.3.5'

  gem.add_development_dependency 'rspec', '2.14.1'
  gem.add_development_dependency 'fakeweb', '1.3.0'
  gem.add_development_dependency 'awesome_print', '~> 1.2.0'
  gem.add_development_dependency 'rake', '~> 10.1.0'
  gem.add_development_dependency 'pry'
end
