#!/usr/bin/env ruby
#
# Script to save a single web page's HTML to disk. For example,
# http://blah.com/admin/about will be saved as:
# <path_to_script>/fixtures/blah.com.html
# Call this script like: `ruby save_page.rb http://blah.com` etc.

require_relative '../../lib/wgit'

raise 'ARGV[0] must be a URL' unless ARGV[0]

url = Wgit::Url.new(ARGV[0])
crawler = Wgit::Crawler.new(url)

Dir.chdir("#{File.expand_path(__dir__)}/fixtures")

# Save the HTML file for the page.
crawler.crawl_url do |doc|
  next if doc.empty?
  file_path = "#{url.host}.html"
  puts "Saving document #{file_path}"
  File.open(file_path, 'w') { |f| f.write(doc.html) }
end
