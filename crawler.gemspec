Gem::Specification.new do |s|
  s.name        = 'crawler'
  s.version     = '0.1.0'
  s.date        = '2016-03-07'
  s.summary     = "Crawler is a simple web indexer and searcher."
  s.description = "Crawler provides the main components of a search engine, a web indexer and a database searcher."
  s.authors     = ["Michael Telford"]
  s.email       = "michael.telford@live.com"
  s.files       = Dir["./lib/*.rb", "./lib/crawler/*.rb", "./lib/crawler/database/*.rb"]
  s.executables << "crawl"
  s.executables << "search"
  s.homepage    = 'http://rubygems.org/gems/crawler'
  s.license     = 'MIT'
end
