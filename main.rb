#!/usr/bin/env ruby

require_relative 'crawler'
require 'fileutils'

# Script which sets up a crawler and saves the indexed docs to a data source.
# @author Michael Telford

MAX_DATA_SIZE = 10485760 # 10MB

def main
    $db = Database.new
    crawler = Crawler.new
    
    while $db.length < MAX_DATA_SIZE do
        puts "Database size: #{$db.length}"
        crawler.urls = $db.get_urls
        break if crawler.urls.length < 1
        puts "Starting crawl loop for: #{crawler.urls}"
        
        docs_count = 0
        urls_count = 0
    
        crawler.crawl do |doc|
            write_doc_to_db(doc)
            docs_count += 1
            urls_count += write_urls_to_db(doc)
        end
    
        puts "Crawled and saved docs for #{docs_count} url(s)."
        puts "Found and saved #{urls_count} url(s)."
    end
end

def write_doc_to_db(doc)
    $db.insert(doc)
    $db.update(doc.url) # Updates url crawled = true.
    puts "Saved document for url: #{doc.url}"
end

# The unique url index on the urls collection prevents duplicate inserts.
def write_urls_to_db(doc, internal_only = false)
    links = internal_only ? doc.internal_links : doc.links
    count = 0
    if links.respond_to?(:each)
        links.each do |url|
            begin
                $db.insert(url)
                count += 1
                puts "Inserted url: #{url}"
            rescue
                puts "Url already exists: #{url}"
            end
        end
    end
    count
end

if __FILE__ == $0
    main
end
