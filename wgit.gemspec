# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wgit/version'

# Returns all files to be packaged within the gem.
def get_gem_files
  rb_files = Dir["./lib/**/*.rb"]
  non_rb_files = ['README.md', 'TODO.txt', 'LICENSE.txt']

  # List any ruby files that should NOT be packaged in the built gem.
  # The full file path should be provided e.g. "./lib/wgit/file.rb".
  ignore_files = [
    "./lib/wgit/database/database_default_data.rb",
    "./lib/wgit/database/database_helper.rb",
  ]

  files = ((rb_files + non_rb_files) - ignore_files).uniq
  raise 'A file path is incorrect' if files.any? { |f| !File.exist? f }
  raise 'An ignored file path is incorrect' if files.any? { |f| ignore_files.include? f }

  files
end

Gem::Specification.new do |s|
  s.name                  = 'wgit'
  s.version               = Wgit::VERSION
  s.date                  = '2016-03-07'
  s.summary               = "Wgit is a Ruby gem similar in nature to GNU's `wget` tool. It provides an easy to use API for programmatic web scraping, indexing and searching."
  s.description           = "Fundamentally, Wgit is a WWW indexer/scraper which crawls URL's, retrieves and serialises their page contents for later use. You can use Wgit to copy entire websites if required. Wgit also provides a means to search indexed documents stored in a database. Therefore, this library provides the main components of a WWW search engine. The Wgit API is easily extended allowing you to pull out the parts of a webpage that are important to you, the code snippets or tables for example. As Wgit is a library, it has uses in many different application types."
  s.author                = "Michael Telford"
  s.email                 = "michael.telford@live.com"
  s.require_paths         = ["lib"]
  s.files                 = get_gem_files
  #s.executables          << "wgit"
  s.homepage              = 'https://github.com/michaeltelford/wgit'
  s.license               = 'MIT'
  s.metadata              = {
    "source_code_uri" => "https://github.com/michaeltelford/wgit",
    "yard.run" => "yri", # use "yard" to build full HTML docs.
  }
  s.required_ruby_version = '~> 2.5' # Only works with ruby 2.5.x

  s.add_development_dependency "minitest", "~> 5.11"
  s.add_development_dependency "yard", ">= 0.9.20"
  s.add_development_dependency "byebug", "~> 10.0"
  s.add_development_dependency "pry", "~> 0.12"
  s.add_development_dependency "dotenv", "~> 2.5"
  s.add_development_dependency "rake", "~> 12.3"
  s.add_development_dependency "httplog", "~> 1.3"
  s.add_development_dependency "webmock", "~> 3.6"
  s.add_development_dependency "rack", "~> 2.0"

  s.add_runtime_dependency "nokogiri", "~> 1.10.3"
  s.add_runtime_dependency "mongo", "~> 2.9.0"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if s.respond_to?(:metadata)
    s.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end
end
