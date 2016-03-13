#!/usr/bin/env ruby

require_relative 'crawler'
require_relative 'database/database'

# Script which sets up a crawler and saves the indexed docs to a data source.
# @author Michael Telford

NUM_SITES_TO_CRAWL = 1 # Use -1 for infinite crawling.
MAX_DATA_SIZE = 10485760 # 10MB
DB = Database.new

def main
    crawler = Crawler.new
    loop_count = 0
    
    while DB.size < MAX_DATA_SIZE do
        break if loop_count == NUM_SITES_TO_CRAWL
        loop_count += 1
        
        puts "Database size: #{DB.size}"
        crawler.urls = DB.urls

        if crawler.urls.length < 1
            puts "No urls to crawl, exiting."
            break
        end
        puts "Starting crawl loop for: #{crawler.urls}"
        
        docs_count = 0
        urls_count = 0
        
        crawler.urls.each do |url|
            url.crawled = true
            raise unless DB.update(url) > 0
            
            site_docs_count = 0
            ext_links = crawler.crawl_site(url) do |doc|
                unless doc.empty?
                    if write_doc_to_db(doc)
                        docs_count += 1
                        site_docs_count += 1
                    end
                end
            end
            
            urls_count += write_urls_to_db(ext_links)
            puts "Crawled and saved #{site_docs_count} docs for the site: #{url}"
        end
    
        puts "Crawled and saved docs for #{docs_count} url(s) overall for this iteration."
        puts "Found and saved #{urls_count} external url(s) for the next iteration."
    end
end

# The unique url index on the documents collection prevents duplicate inserts.
def write_doc_to_db(doc)
    DB.insert(doc)
    puts "Saved document for url: #{doc.url}"
    true
rescue Mongo::Error::OperationFailure
    puts "Document already exists: #{doc.url}"
    false
end

# The unique url index on the urls collection prevents duplicate inserts.
def write_urls_to_db(urls)
    count = 0
    if urls.respond_to?(:each)
        urls.each do |url|
            begin
                DB.insert(url)
                count += 1
                puts "Inserted url: #{url}"
            rescue Mongo::Error::OperationFailure
                puts "Url already exists: #{url}"
            end
        end
    end
    count
end

if __FILE__ == $0
    main
end
