require_relative 'url'
require_relative 'documents'
require_relative 'document'
require 'net/http'

# @author Michael Telford
# Crawler class provides a means of crawling (GET'ting) web URL's.
class Crawler
	attr_reader :urls, :docs

	def initialize(*urls)
		self.urls = urls unless urls.nil?
        @docs = Documents.new
	end
    
    def urls=(urls)
        raise "Must be an array of urls" unless urls.respond_to?(:each)
        @urls = []
        urls.each do |url|
            @urls << Url.new(url)
        end
    end
    
    def add_url(url)
        @urls = [] if @urls.nil?
        @urls << Url.new(url)
    end
	
	def crawl_urls(urls = @urls)
        raise "No urls to crawl" if @urls.count < 1
		if urls.respond_to?(:each)
			urls.each do |url|
                raise unless url.respond_to?(:to_url)
				@docs[url.to_url] = Document.new(crawl_url(url.to_s))
			end
		else
            raise unless url.respond_to?(:to_url)
			@docs[url.to_url] = Document.new(crawl_url(urls.to_s))
		end
	end
	
	# Crawl the url and return the response markup.
	def crawl_url(url)
		raise unless url.respond_to?(:to_s)
        url = url.to_s
		Net::HTTP.get(url, '/index.html')
	end
    
    alias :crawl :crawl_urls
end
