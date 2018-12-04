# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wgit/version'

# List any files that should NOT be packaged in the built gem. 
# The full file path should be provided e.g. "./lib/wgit/file.rb"
reject_files = [
  "./lib/wgit/database/database_default_data.rb", 
  "./lib/wgit/database/database_helper.rb"
]

Gem::Specification.new do |s|
  s.name          = 'wgit'
  s.version       = Wgit::VERSION
  s.date          = '2016-03-07'
  s.summary       = "Wgit is wget on steroids with an easy to use API for web scraping and indexing"
  s.description   = "Wgit is a WWW indexer/scraper which crawls URL's and retrieves their page contents for later use. Also included in this package is a means to search indexed documents stored in a database. Therefore this library provides the main components of a WWW search engine. You can also use Wgit to copy entire website's HTML making it far more powerful than wget. The Wgit API is easily extendable allowing you to easily pull out the parts of a webpage that are important to you, the CSS or JS links for example."
  s.authors       = ["Michael Telford"]
  s.email         = "michael.telford@live.com"
  s.require_paths = ["lib"]
  s.files         = Dir["./lib/**/*.rb"] - reject_files
  #s.executables << "wgit"
  s.homepage      = 'http://rubygems.org/gems/wgit'
  s.license       = 'MIT'
  
  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if s.respond_to?(:metadata)
    s.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end
end
