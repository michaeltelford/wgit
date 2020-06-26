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
    Wgit is a HTML web crawler, written in Ruby, that allows you to extract the data you want from the web.
  TEXT
  s.description = <<~TEXT
    Wgit was primarily designed to crawl static HTML websites to index and search their content - providing the basis of any search engine; but Wgit is suitable for many application domains including: URL parsing, data mining and statistical analysis.
  TEXT

  s.require_paths = %w[lib]
  s.files = Dir[
    './lib/**/*.rb',
    'bin/wgit',
    '*.md',
    'LICENSE.txt',
    '.yardopts'
  ]
  s.bindir = 'bin'
  s.executable = 'wgit'
  s.post_install_message = "Added the 'wgit' executable to $PATH"
  s.metadata = {
    'yard.run' => 'yri',
    'source_code_uri' => 'https://github.com/michaeltelford/wgit',
    'changelog_uri' => 'https://github.com/michaeltelford/wgit/blob/master/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/michaeltelford/wgit/issues',
    'documentation_uri' => 'https://www.rubydoc.info/github/michaeltelford/wgit/master'
  }

  s.platform              = Gem::Platform::RUBY
  s.required_ruby_version = '~> 2.5'

  s.add_runtime_dependency 'addressable', '~> 2.6'
  s.add_runtime_dependency 'mongo', '~> 2.9'
  s.add_runtime_dependency 'nokogiri', '~> 1.10'
  s.add_runtime_dependency 'typhoeus', '~> 1.3'
  s.add_runtime_dependency 'ferrum', '~> 0.8'

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
  else
    raise 'Only RubyGems 2.0 or newer can protect against public gem pushes'
  end
end
