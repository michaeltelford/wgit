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
    #init_file_system
    init_db
    
    # Init the crawler.
    crawler = Crawler.new
    crawler.urls = $urls
    puts "Using urls: #{crawler.urls}"
    
    # Crawl and provide a block for writing to the data source.
    $docs = []
    urls_count = 0
    crawler.crawl do |doc|
        $docs << doc
        #write_doc_to_file_system(doc)
        write_doc_to_db(doc)
        urls_count += write_urls_to_db(doc)
    end
    
    puts "Crawled and saved docs for #{$docs.length} url(s)."
    puts "Found and saved #{urls_count} url(s)."
    puts "Finished."
end

def init_file_system
    tmp = ENV['TMPDIR'] ? ENV['TMPDIR'] : ENV['TEMP']
    dir = tmp + "crawler/"
    FileUtils.remove_dir(dir) if Dir.exists?(dir)
    Dir.mkdir(dir)
    puts "Using dir: #{dir}"
    $dir = dir
end

def init_db
    $db = Database.new
    $db.insert $urls
    puts "Inserted #{$urls.length} urls into the database."
end

def write_doc_to_file_system(doc)
    name = doc.url.host.split('/').join('.') + ".html"
    File.open($dir + name, 'w') { |f| f.write(doc.html) }
    puts "Created file: #{name} for url: #{doc.url}"
end

def write_doc_to_db(doc)
    $db.insert(doc)
    $db.update_url(doc.url)
    puts "Saved document for url: #{doc.url}"
end

# The unique url index on the urls collection prevents duplicate inserts.
def write_urls_to_db(doc, internal_only = false)
    links = internal_only ? doc.internal_links : doc.links
    count = 0
    links.each do |url|
        puts "Inserting url: #{url}"
        begin
            $db.insert(Url.new(url, doc.url))
            count += 1
        rescue
            puts "Url already exists: #{url}"
        end
    end
    count
end

if __FILE__ == $0
    main
end
