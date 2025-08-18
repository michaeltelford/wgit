# frozen_string_literal: true

require_relative "./lib/wgit/version"

Gem::Specification.new do |s|
  s.name     = "wgit"
  s.version  = Wgit::VERSION
  s.date     = Time.now.strftime("%Y-%m-%d")
  s.author   = "Michael Telford"
  s.email    = "michael.telford@live.com"
  s.homepage = "https://github.com/michaeltelford/wgit"
  s.license  = "MIT"

  s.summary = <<~TEXT
    Wgit is a HTML web crawler, written in Ruby, that allows you to programmatically extract the data you want from the web.
  TEXT
  s.description = <<~TEXT
    Wgit was primarily designed to crawl static HTML websites to index and search their content - providing the basis of any search engine; but Wgit is suitable for many application domains including: URL parsing, data mining and statistical analysis.
  TEXT

  s.require_paths = %w[lib]
  s.files = Dir[
    "./lib/**/*.rb",
    "bin/wgit",
    "*.md",
    "LICENSE.txt",
    ".yardopts"
  ]
  s.bindir = "bin"
  s.executable = "wgit"
  s.post_install_message = "Added the 'wgit' executable to $PATH"
  s.metadata = {
    "yard.run" => "yri",
    "source_code_uri" => "https://github.com/michaeltelford/wgit",
    "changelog_uri" => "https://github.com/michaeltelford/wgit/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/michaeltelford/wgit/issues",
    "documentation_uri" => "https://www.rubydoc.info/gems/wgit"
  }

  s.platform              = Gem::Platform::RUBY
  s.required_ruby_version = ">= 3", "< 4"

  s.add_runtime_dependency "addressable", "~> 2.8"
  s.add_runtime_dependency "base64", "~> 0.2"
  s.add_runtime_dependency "ferrum", "~> 0.17.1"
  s.add_runtime_dependency "mongo", "~> 2.19"
  s.add_runtime_dependency "nokogiri", "~> 1.15"
  s.add_runtime_dependency "typhoeus", "~> 1.4"

  s.add_development_dependency "byebug", "~> 11.1"
  s.add_development_dependency "dotenv", "~> 2.8"
  s.add_development_dependency "maxitest", "~> 5.4"
  s.add_development_dependency "pry", "~> 0.14"
  s.add_development_dependency "rubocop", "~> 1.57"
  s.add_development_dependency "toys", "~> 0.15"
  s.add_development_dependency "webmock", "~> 3.19"
  s.add_development_dependency "yard", "~> 0.9"

  # Only allow gem pushes to rubygems.org.
  unless s.respond_to?(:metadata)
    raise "Only RubyGems 2.0 or newer can protect against public gem pushes"
  end

  s.metadata["allowed_push_host"] = "https://rubygems.org"
end
