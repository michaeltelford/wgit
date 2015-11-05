#!/usr/bin/env ruby

require_relative 'crawler'
require 'fileutils'

# Script which sets up a crawler and saves the indexed docs to the file system.
if __FILE__ == $0
    # Prepare the file system.
    tmp = ENV['TMPDIR']
    dir = tmp + "crawler/"
    FileUtils.remove_dir(dir) if Dir.exists?(dir)
    Dir.mkdir(dir)
    puts "Using dir: #{dir}"
    
    # Init the urls to crawl.
    urls = ["www.facebook.com", "www.google.co.uk", "www.youtube.com", "www.yahoo.co.uk", "http://www.nokogiri.org/tutorials/searching_a_xml_html_document.html"]
    puts "Using urls: #{urls}"
    
    # Init the crawler.
    crawler = Crawler.new
    crawler.urls = urls
    
    # Crawl and provide a block for writing to the file system.
    count = 0
    docs = []
    crawler.crawl do |url, doc|
        docs << doc
        name = url.to_host.split('/').join('.') + ".html"
        File.open(dir + name, 'w') { |f| f.write(doc.html) }
        count += 1
        puts "Created file: #{name} for url: #{url.to_url}"
    end
    
    puts "Finished. Crawled and created files for #{count} urls."
    
    docs.each do |doc|
        puts "URL: #{doc.url}, LINKS: #{doc.links}, TEXT: #{doc.text}"
    end
end
