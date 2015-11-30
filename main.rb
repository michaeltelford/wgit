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
    count = 0
    $docs = []
    
    crawler.crawl do |doc|
        $docs << doc
        #write_to_file_system(doc)
        write_to_db(doc)
        count += 1
    end
    
    puts "Finished. Crawled and saved data for #{count} url(s)."
end

# Prepare the file system.
def init_file_system
    tmp = ENV['TMPDIR'] ? ENV['TMPDIR'] : ENV['TEMP']
    dir = tmp + "crawler/"
    FileUtils.remove_dir(dir) if Dir.exists?(dir)
    Dir.mkdir(dir)
    puts "Using dir: #{dir}"
    $dir = dir
end

# Prepare the DB.
def init_db
    $db = Database.new
    $db.insert $urls
    puts "Inserted #{$urls.length} urls into the database."
end

# Save the doc to the file system.
def write_to_file_system(doc)
    name = doc.url.host.split('/').join('.') + ".html"
    File.open($dir + name, 'w') { |f| f.write(doc.html) }
    puts "Created file: #{name} for url: #{doc.url}"
end

# Save the doc to the database.
def write_to_db(doc)
    $db.insert(doc)
    $db.update_url(doc.url)
    puts "Saved document for url: #{doc.url}"
end

if __FILE__ == $0
    main
end
