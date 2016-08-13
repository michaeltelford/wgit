require_relative 'url'
require_relative 'document'
require_relative 'utils'
require_relative 'assertable'
require 'net/http' # requires 'uri'
 
module Wgit

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
        Wgit::Utils.each(urls) { |url| add_url(url) }
    end
  
    def [](*urls)
        self.urls = urls unless urls.nil?
    end
  
    def <<(url)
        add_url(url)
    end
	
    # Crawls individual urls, not entire sites.
    # Returns the last crawled doc.
    # Yields each doc to the provided block or adds each doc to @docs
    # which can be accessed by Crawler#docs after the method returns.
  	def crawl_urls(urls = @urls, &block)
      raise "No urls to crawl" unless urls
      @docs = []
      doc = nil
      Wgit::Utils.each(urls) { |url| doc = handle_crawl_block(url, &block) }
      doc ? doc : @docs.last
  	end
	
  	# Crawl the url and return the response document or nil.
    # Also yield(doc) if a block is provided. The doc is passed to the block 
    # regardless of the crawl success so the doc.url can be used if needed. 
  	def crawl_url(url = @urls.first, &block)
      assert_type(url, Url)
  		markup = fetch(url)
      url.crawled = true
      doc = Wgit::Document.new(url, markup)
      block.call(doc) if block_given?
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
      external_urls = doc.external_links
      internal_urls = doc.internal_links
    
      return doc.external_links.uniq if internal_urls.empty?
    
      loop do
        internal_urls.uniq! unless internal_urls.uniq.nil?
      
        links = internal_urls - crawled_urls
        break if links.empty?
      
        links.each do |link|
          doc = crawl_url(Wgit::Url.concat(base_url.to_base, link), &block)
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
        if not block_given?
		        @docs << crawl_url(url)
            nil
        else
            crawl_url(url, &block)
        end
    end
  
    # The fetch method performs a HTTP GET to obtain the HTML document.
    # Invalid urls or any HTTP response that doesn't return a HTML body 
    # will be ignored and nil will be returned.  This means that redirects
    # etc. will not be followed. 
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
            @urls << Wgit::Url.new(url)
        end
    end
  
    alias :crawl :crawl_urls
    alias :crawl_r :crawl_site
  end
end
