require File.expand_path('../lib/meta_inspector/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jaime Iniesta"]
  gem.email         = ["jaimeiniesta@gmail.com"]
  gem.description   = %q{MetaInspector lets you scrape a web page and get its links, images, texts, meta tags...}
  gem.summary       = %q{MetaInspector is a ruby gem for web scraping purposes, that returns metadata from a given URL}
  gem.homepage      = "https://github.com/jaimeiniesta/metainspector"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {spec}/*`.split("\n")
  gem.name          = "metainspector"
  gem.require_paths = ["lib"]
  gem.version       = MetaInspector::VERSION

  gem.add_dependency 'nokogiri', '~> 1.7'
  gem.add_dependency 'faraday', '~> 0.11'
  gem.add_dependency 'faraday_middleware', '~> 0.11'
  gem.add_dependency 'faraday-cookie_jar', '~> 0.0'
  gem.add_dependency 'faraday-http-cache', '~> 2.0'
  gem.add_dependency 'faraday-encoding', '~> 0.0'
  gem.add_dependency 'addressable', '~> 2.5'
  gem.add_dependency 'fastimage', '~> 2.1'
  gem.add_dependency 'nesty', '~> 1.0'

  gem.add_development_dependency 'rspec', '~> 3.0'
  gem.add_development_dependency 'webmock'
  gem.add_development_dependency 'awesome_print'
  gem.add_development_dependency 'rake', '~> 10.1.0'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'rubocop'
end
