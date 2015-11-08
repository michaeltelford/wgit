#!/usr/bin/env ruby

require_relative 'crawler'
require 'fileutils'

# Script which sets up a crawler and saves the indexed docs to the file system.

def main
    # Prepare the file system.
    tmp = ENV['TMPDIR']
    dir = tmp + "crawler/"
    FileUtils.remove_dir(dir) if Dir.exists?(dir)
    Dir.mkdir(dir)
    puts "Using dir: #{dir}"
    
    # Init the urls to crawl.
    urls = ["https://en.wikipedia.org/wiki/Main_Page", "https://en.wikipedia.org/wiki/Antonov_An-12"]
    
    # Init the crawler.
    crawler = Crawler.new
    #crawler.urls = urls
    crawler << "http://www.belfastcommunityacupuncture.com"
    puts "Using urls: #{crawler.urls}"
    
    # Crawl and provide a block for writing to the file system.
    count = 0
    docs = []
    crawler.crawl do |url, doc|
        docs << doc
        name = url.to_host.split('/').join('.') + ".html"
        File.open(dir + name, 'w') { |f| f.write(doc.html) }
        count += 1
        puts "Created file: #{name} for url: #{url}"
    end
    
    puts "Finished. Crawled and created file(s) for #{count} url(s)."
    
    docs.each do |doc|
        puts "\nPrinting details about #{doc.url}"
        #puts doc.to_hash(false)
        puts doc.length
    end
    
    docs
end

if __FILE__ == $0
    main
end
