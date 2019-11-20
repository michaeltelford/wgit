# frozen_string_literal: true

require_relative './lib/wgit/version'

Gem::Specification.new do |s|
  s.name     = 'wgit'
  s.version  = Wgit::VERSION
  s.date     = Time.now.strftime('%Y-%m-%d')
  s.author   = 'Michael Telford'
  s.email    = 'michael.telford@live.com'
  s.homepage = 'https://github.com/michaeltelford/wgit'
  s.license  = 'MIT'

  s.summary = <<~TEXT
    Wgit is a Ruby gem similar in nature to GNU's `wget` tool. It provides an easy to use API for programmatic URL parsing, HTML indexing and searching.
  TEXT
  s.description = <<~TEXT
    Fundamentally, Wgit is a HTTP indexer/scraper which crawls URL's to retrieve and serialise their page contents for later use. You can use Wgit to copy entire websites if required. Wgit also provides a means to search indexed documents stored in a database. Therefore, this library provides the main components of a WWW search engine. The Wgit API is easily extended allowing you to pull out the parts of a webpage that are important to you, the code snippets or tables for example. As Wgit is a library, it supports many different use cases including data mining, analytics, web indexing and URL parsing to name a few.
  TEXT

  s.require_paths = %w[lib]
  s.files = (Dir['./lib/**/*.rb'] - [
    './lib/wgit/database/database_dev_data.rb',
    './lib/wgit/database/database_helper.rb'
  ])
  s.executables = %w[]
  s.metadata = {
    'source_code_uri' => 'https://github.com/michaeltelford/wgit',
    'yard.run' => 'yri'
  }

  s.platform              = Gem::Platform::RUBY
  s.required_ruby_version = '~> 2.5'

  s.add_runtime_dependency 'addressable', '~> 2.6.0'
  s.add_runtime_dependency 'mongo', '~> 2.9.0'
  s.add_runtime_dependency 'nokogiri', '~> 1.10.3'
  s.add_runtime_dependency 'typhoeus', '~> 1.3.1'

  s.add_development_dependency 'byebug', '~> 10.0'
  s.add_development_dependency 'dotenv', '~> 2.5'
  s.add_development_dependency 'maxitest', '~> 3.3'
  s.add_development_dependency 'pry', '~> 0.12'
  s.add_development_dependency 'rubocop', '~> 0.74'
  s.add_development_dependency 'toys', '~> 0.8'
  s.add_development_dependency 'webmock', '~> 3.6'
  s.add_development_dependency 'yard', ['>= 0.9.20', '< 1.0']

  # Only allow gem pushes to rubygems.org.
  if s.respond_to?(:metadata)
    s.metadata['allowed_push_host'] = 'https://rubygems.org'
    s.metadata['changelog_uri']     = 'https://github.com/michaeltelford/wgit/blob/master/CHANGELOG.md'
    s.metadata['source_code_uri']   = 'https://github.com/michaeltelford/wgit'
    s.metadata['bug_tracker_uri']   = 'https://github.com/michaeltelford/wgit/issues'
    s.metadata['documentation_uri'] = 'https://www.rubydoc.info/gems/wgit'
  else
    raise 'Only RubyGems 2.0 or newer can protect against public gem pushes'
  end
end
