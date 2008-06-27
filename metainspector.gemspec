Gem::Specification.new do |s|
  s.name = "metainspector"
  s.version = "1.0.3"
  s.date = "2008-06-27"
  s.summary = "Ruby gem for web scraping"
  s.email = "jaimeiniesta@gmail.com"
  s.homepage = "http://code.jaimeiniesta.com/metainspector"
  s.description = "MetaInspector is a ruby gem for web scraping purposes, that returns a hash with metadata from a given URL"
  s.has_rdoc = false
  s.authors = ["Jaime Iniesta"]
  s.files = ["README", "metainspector.gemspec", "lib/metainspector.rb", "test/test_metainspector.rb"]
  s.test_files = []
  s.rdoc_options = []
  s.extra_rdoc_files = []
  s.add_dependency("hpricot", ["> 0.5"])
end
