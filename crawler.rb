require_relative 'url'
require_relative 'document'
require_relative 'utils'
require 'net/http' # requires 'uri'

# @author Michael Telford
# Crawler class provides a means of crawling web URL's.
class Crawler
	attr_reader :urls, :docs

	def initialize(*urls)
		self.urls = urls unless urls.nil?
        @docs = []
	end
    
    def urls=(urls)
        raise "urls must #respond_to? :each" unless urls.respond_to?(:each)
        @urls = []
        urls.each do |url|
            add_url(url)
        end
    end
    
    def [](*urls)
        self.urls = urls unless urls.nil?
    end
    
    def <<(url)
        add_url(url)
    end
	
    # Returns the last crawled doc.
    # Yields each doc to the provided block or adds the docs to @docs.
	def crawl_urls(urls = @urls, &block)
        raise "No urls to crawl" if urls.nil? or urls.length < 1
        @docs = []
        doc = nil
		if urls.respond_to?(:each)
			urls.each do |url|
                doc = handle_crawl_block(url, &block)
			end
		else
            doc = handle_crawl_block(urls, &block)
		end
        if doc.nil?
            @docs.last
        else
            doc
        end
	end
	
	# Crawl the url and return the response document.
    # Also yield(doc) if a block is provided.
	def crawl_url(url = @urls.first, &block)
		markup = fetch(url)
        return nil if markup.nil?
        url.crawled = true
        doc = Document.new(url, markup)
        block.call(doc) unless block.nil?
        doc
	end
    
    # Crawls an entire site by recursively going through its internal_links.
    # Also yield(doc) for each crawled doc if a block is provided.
    # A block is the only way to interact with the crawled docs.
    # Returns a unique array of external urls collected from the site.
    def crawl_site(base_url, &block)
        Utils.assert_type?([base_url], Url)
        
        doc = crawl_url(base_url, &block)
        return nil if doc.nil?
        
        crawled_urls  = []
        external_urls = []
        internal_urls = doc.internal_links
        
        if internal_urls.nil? or internal_urls.length == 0
            return doc.external_links
        end
        
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
                unless doc.internal_links.nil?
                    internal_urls = internal_urls.concat(doc.internal_links)
                end
                unless doc.external_links.nil?
                    external_urls = external_urls.concat(doc.external_links)
                end
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
        if res.is_a?(Net::HTTPSuccess)
            res.body
        else
            nil
        end
    rescue
        nil
    end
    
    def add_url(url)
        @urls = [] if @urls.nil?
        if url.is_a?(Url)
            @urls << url
        else
            @urls << Url.new(url)
        end
    end
    
    alias :crawl :crawl_urls
end
