#!/usr/bin/env ruby
#
# Script to save an entire website's HTML to disk. For example,
# http://blah.com/admin/about will be saved as:
# <path_to_script>/fixtures/blah.com/admin/about.html
# Call this script like: `ruby save_site.rb http://blah.com` etc.

require 'wgit'
require 'fileutils'

url = ARGV[0] || raise('ARGV[0] must be a URL')
url = Wgit::Url.new(url)
path = "#{File.expand_path(__dir__)}/fixtures/#{url.host}"
crawler = Wgit::Crawler.new(url)

Dir.mkdir(path) unless Dir.exists?(path)
Dir.chdir(path)

# Save the site to disk.
crawler.crawl_site do |doc|
  next if doc.empty?

  # Save the index.html file to disk.
  uri = doc.url.to_uri
  if uri.path == '' || uri.path == '/'
    puts "Saving document #{url.host}/index.html"
    File.open('index.html', 'w') { |f| f.write(doc.html) }
    next
  end

  # Work out the file structure on disk.
  segs = uri.path.split('/').reject { |s| s.empty? }
  dir = ''
  if segs.length == 1
    file_name = segs[0]
  else
    file_name = segs.pop
    segs.each { |seg| dir += "#{seg}/" }
    dir = dir[0..-2] # Remove trailing slash.
  end

  # Create the directory if necessary.
  if dir != ''
    FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
    dir += '/'
  end

  # Save the HTML file for the page.
  file_path = "#{dir}#{file_name}.html"
  puts "Saving document #{url.host}/#{file_path}"
  File.open(file_path, 'w') { |f| f.write(doc.html) }
end
