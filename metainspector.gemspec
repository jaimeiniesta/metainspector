Gem::Specification.new do |s|
  s.name = "metainspector"
  s.version = "1.1.4"
  s.date = "2009-06-04"
  s.summary = "Ruby gem for web scraping"
  s.email = "jaimeiniesta@gmail.com"
  s.homepage = "http://github.com/jaimeiniesta/metainspector/tree/master"
  s.description = "MetaInspector is a ruby gem for web scraping purposes, that returns a hash with metadata from a given URL"
  s.has_rdoc = false
  s.authors = ["Jaime Iniesta"]
  s.files = [
    "README.rdoc",
    "CHANGELOG.rdoc",
    "MIT-LICENSE",
    "metainspector.gemspec",
    "lib/metainspector.rb",
    "samples/basic_scraping.rb",
    "samples/spider.rb"]
  s.test_files = ["test/test_metainspector.rb"]
  s.rdoc_options = []
  s.extra_rdoc_files = []
  s.add_dependency("nokogiri", ["> 1.2"])
end
