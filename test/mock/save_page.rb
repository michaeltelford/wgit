#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to save a single web page's HTML to disk. For example,
# http://blah.com/admin/about will be saved as:
# <path_to_script>/fixtures/blah.com.html
# Call this script like: `ruby save_page.rb http://blah.com` or use toys task.

require_relative '../../lib/wgit'
require 'fileutils'

raise 'ARGV[0] must be a URL' unless ARGV[0]

url     = Wgit::Url.new(ARGV[0])
path    = "#{File.expand_path(__dir__)}/fixtures"
crawler = Wgit::Crawler.new

FileUtils.mkdir_p(path)
Dir.chdir(path)

# Save the HTML file for the page.
crawler.crawl_url(url) do |doc|
  if doc.empty?
    puts "Invalid URL: #{doc.url}"
    next
  end

  file_path = url.to_host
  file_path += '.html' unless file_path.end_with? '.html'
  puts "Saving document #{file_path}"
  File.open(file_path, 'w') { |f| f.write(doc.html) }
end
