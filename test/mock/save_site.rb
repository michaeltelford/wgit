#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to save an entire website's HTML to disk. For example,
# http://blah.com/admin/about will be saved as:
# <path_to_script>/fixtures/blah.com/admin/about.html
# Call this script like: `ruby save_site.rb http://blah.com` or use toys task.

require_relative '../../lib/wgit'
require 'fileutils'

raise 'ARGV[0] must be a URL' unless ARGV[0]

base_url = Wgit::Url.new(ARGV[0])
path     = "#{File.expand_path(__dir__)}/fixtures/#{base_url.to_host}"
crawler  = Wgit::Crawler.new

Dir.mkdir(path) unless Dir.exist?(path)
Dir.chdir(path)

# Save the site to disk.
crawler.crawl_site(base_url) do |doc|
  url = doc.url

  if doc.empty?
    puts "Invalid URL: #{url}"
    next
  end

  # Save the index.html file to disk.
  if url.omit_slashes == base_url.omit_slashes
    puts "Saving document #{base_url.to_host}/index.html"
    File.open('index.html', 'w') { |f| f.write(doc.html) }
    next
  end

  # Work out the file structure on disk.
  segs = url.omit_base.split('/').reject(&:empty?)
  dir = ''
  if segs.length == 1
    file_name = segs[0]
  else
    file_name = segs.pop
    segs.each { |seg| dir += "#{seg}/" }
    dir.chop! # Remove trailing slash.
  end

  # Create the directory if necessary.
  if dir != ''
    FileUtils.mkdir_p(dir)
    dir += '/'
  end

  file_path = dir + file_name
  file_path += '.html' unless file_path.end_with? '.html'

  # Save the HTML file for the page.
  puts "Saving document #{base_url.to_host}/#{file_path}"
  File.open(file_path, 'w') { |f| f.write(doc.html) }
end
