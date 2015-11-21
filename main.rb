#!/usr/bin/env ruby

require_relative 'crawler'
require 'fileutils'

# Script which sets up a crawler and saves the indexed docs to the file system.
# @author Michael Telford
def main
    # Prepare the file system.
    tmp = ENV['TMPDIR'] ? ENV['TMPDIR'] : ENV['TEMP']
    dir = tmp + "crawler/"
    FileUtils.remove_dir(dir) if Dir.exists?(dir)
    Dir.mkdir(dir)
    puts "Using dir: #{dir}"
    
    # Init the urls to crawl.
    urls = [
        "http://www.belfastcommunityacupuncture.com", 
        "http://www.altitudejunkies.com/index.html",
    ]
    
    # Init the crawler.
    crawler = Crawler.new
    crawler.urls = urls
    puts "Using urls: #{crawler.urls}"
    
    # Crawl and provide a block for writing to the file system.
    count = 0
    docs = Documents.new
    crawler.crawl do |url, doc|
        docs[url] = doc
        name = url.to_host.split('/').join('.') + ".html"
        File.open(dir + name, 'w') { |f| f.write(doc.html) }
        count += 1
        puts "Created file: #{name} for url: #{url}"
    end
    
    puts "Finished. Crawled and created file(s) for #{count} url(s)."
    
    docs.each do |url, doc|
        puts doc.stats
    end
    
    docs
end

if __FILE__ == $0
    main
end
