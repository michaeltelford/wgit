require_relative 'url'
require_relative 'documents'
require_relative 'document'
require 'net/http' # requires 'uri'

# @author Michael Telford
# Crawler class provides a means of crawling web URL's.
class Crawler
	attr_reader :urls, :docs

	def initialize(*urls)
		self.urls = urls unless urls.nil?
        @docs = Documents.new
	end
    
    def urls=(urls)
        raise "urls must #respond_to? :each" unless urls.respond_to?(:each)
        @urls = []
        urls.each do |url|
            @urls << Url.new(url)
        end
    end
    
    def [](*urls)
        self.urls = urls
    end
    
    def <<(url)
        @urls = [] if @urls.nil?
        @urls << Url.new(url)
    end
	
	def crawl_urls(urls = @urls, &block)
        raise "No urls to crawl" if urls.nil? or urls.length < 1
        @docs = {}
		if urls.respond_to?(:each)
			urls.each do |url|
                handle_crawl_block(url, &block)
			end
		else
            handle_crawl_block(urls, &block)
		end
        urls
	end
	
	# Crawl the url and return the response document.
    # Also yield if a block is provided.
	def crawl_url(url = @urls[0], &block)
		markup = fetch(url)
        return nil if markup.nil?
        doc = Document.new(url, markup)
        block.call(url, doc) unless block.nil?
        doc
	end
    
private
    
    # Add the document to the hash for later processing
    # or let the block process it here and now.
    def handle_crawl_block(url, &block)
        if block.nil?
		    @docs[url] = crawl_url(url)
        else
            crawl_url(url, &block)
        end
    end
    
    def fetch(url)
        Net::HTTP.get(url.to_uri)
    rescue SocketError
        nil
    end
    
    alias :crawl :crawl_urls
end
