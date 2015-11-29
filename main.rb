#!/usr/bin/env ruby

require_relative 'crawler'
require 'fileutils'

# Script which sets up a crawler and saves the indexed docs to a data source.
# @author Michael Telford

# Init the urls to crawl.
$urls = [
    Url.new("http://www.belfastcommunityacupuncture.com"),
    Url.new("http://www.altitudejunkies.com/index.html"),
]

def main
    dir = init_file_system
    
    # Init the crawler.
    crawler = Crawler.new
    crawler.urls = $urls
    puts "Using urls: #{crawler.urls}"
    
    # Crawl and provide a block for writing to the file system.
    count = 0
    $docs = []
    
    crawler.crawl do |url, doc|
        $docs << doc
        name = url.host.split('/').join('.') + ".html"
        File.open(dir + name, 'w') { |f| f.write(doc.html) }
        count += 1
        puts "Created file: #{name} for url: #{url}"
    end
    
    puts "Finished. Crawled and created file(s) for #{count} url(s)."
end

# Prepare the file system.
def init_file_system
    tmp = ENV['TMPDIR'] ? ENV['TMPDIR'] : ENV['TEMP']
    dir = tmp + "crawler/"
    FileUtils.remove_dir(dir) if Dir.exists?(dir)
    Dir.mkdir(dir)
    puts "Using dir: #{dir}"
    dir
end

if __FILE__ == $0
    main
end
