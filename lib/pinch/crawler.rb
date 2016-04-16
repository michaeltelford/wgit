require_relative 'url'
require_relative 'document'
require_relative 'utils'
require_relative 'assertable'
require 'net/http' # requires 'uri'

# @author Michael Telford
# Crawler class provides a means of crawling web URL's.
class Crawler
    include Assertable
    
	attr_reader :urls, :docs

	def initialize(*urls)
		self.urls = urls unless urls.nil?
        @docs = []
	end
    
    def urls=(urls)
        @urls = []
        Utils.each(urls) { |url| add_url(url) }
    end
    
    def [](*urls)
        self.urls = urls unless urls.nil?
    end
    
    def <<(url)
        add_url(url)
    end
	
    # Crawls individual urls, not entire sites.
    # Returns the last crawled doc.
    # Yields each doc to the provided block or adds each doc to @docs.
	def crawl_urls(urls = @urls, &block)
        raise "No urls to crawl" unless urls
        @docs = []
        doc = nil
        Utils.each(urls) { |url| doc = handle_crawl_block(url, &block) }
        doc ? doc : @docs.last
	end
	
	# Crawl the url and return the response document or nil.
    # Also yield(doc) if a block is provided. The doc is passed to the block 
    # regardless of the crawl success so the doc.url can be used if needed. 
	def crawl_url(url = @urls.first, &block)
		markup = fetch(url)
        url.crawled = true
        doc = Document.new(url, markup)
        block.call(doc) unless block.nil?
        doc.empty? ? nil : doc
	end
    
    # Crawls an entire site by recursively going through its internal_links.
    # Also yield(doc) for each crawled doc if a block is provided.
    # A block is the only way to interact with the crawled docs.
    # Returns a unique array of external urls collected from the site
    # or nil if the base_url could not be crawled successfully.
    def crawl_site(base_url = @urls.first, &block)
        assert_type(base_url, Url)
        
        doc = crawl_url(base_url, &block)
        return nil if doc.nil?
        
        crawled_urls  = []
        external_urls = []
        internal_urls = doc.internal_links
        
        return doc.external_links if internal_urls.empty?
        
        loop do
            unless internal_urls.uniq.nil?
                internal_urls.uniq!
            end
            
            links = internal_urls - crawled_urls
            break if links.length < 1
            
            links.each do |link|
                doc = crawl_url(Url.concat(base_url.to_base, link), &block)
                crawled_urls << link
                next if doc.nil?
                internal_urls.concat(doc.internal_links)
                external_urls.concat(doc.external_links)
            end
        end
        
        external_urls.uniq
    end
    
private
    
    # Add the document to the @docs array for later processing
    # or let the block process it here and now.
    def handle_crawl_block(url, &block)
        if block.nil?
		    @docs << crawl_url(url)
            nil
        else
            crawl_url(url, &block)
        end
    end
    
    def fetch(url)
        raise unless url.respond_to?(:to_uri)
        res = Net::HTTP.get_response(url.to_uri)
        res.body.empty? ? nil : res.body
    rescue
        nil
    end
    
    def add_url(url)
        @urls = [] if @urls.nil?
        if url.instance_of?(Url)
            @urls << url
        else
            @urls << Url.new(url)
        end
    end
    
    alias :crawl :crawl_urls
end
