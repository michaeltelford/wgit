require_relative 'url'
require_relative 'document'
require_relative 'utils'
require_relative 'assertable'
require 'net/http' # requires 'uri'

module Wgit

  # Crawler class provides a means of crawling web based URL's. 
  # Note that currently all redirects will not be followed during a crawl.
  class Crawler
    include Assertable
    
    # The urls to crawl.
    attr_reader :urls
      
    # The docs of the crawled @urls.
    attr_reader :docs

    # Initializes the Crawler by setting the @urls and @docs.
    #
    # @param urls [Wgit::Url] The URLs to crawl.
  	def initialize(*urls)
        self.urls = urls unless urls.nil?
        @docs = []
  	end
    
    # Sets this Crawler's @urls.
    #
    # @param urls [Array<Wgit::Url>] The URLs to crawl.
    def urls=(urls)
        @urls = []
        Wgit::Utils.each(urls) { |url| add_url(url) }
    end
  
    # Sets this Crawler's @urls.
    #
    # @param urls [Wgit::Url] The URLs to crawl.
    def [](*urls)
        self.urls = urls unless urls.nil?
    end
  
    # Adds the url to this Crawler's @urls.
    #
    # @param url [Wgit::Url] A URL to crawl.
    def <<(url)
        add_url(url)
    end
	
    # Crawls individual urls, not entire sites.
    #
    # @param urls [Array<Wgit::Url>] The URLs to crawl.
    # @yield [doc] If provided, the block is given each crawled
    #   Document. Otherwise each doc is added to @docs which can be accessed
    #   by Crawler#docs after this method returns.
    # @return [Wgit::Document] The last Document crawled.
  	def crawl_urls(urls = @urls, &block)
      raise "No urls to crawl" unless urls
      @docs = []
      doc = nil
      Wgit::Utils.each(urls) { |url| doc = handle_crawl_block(url, &block) }
      doc ? doc : @docs.last
  	end
	
  	# Crawl the url and return the response document or nil.
    #
    # @param url [Wgit::Document] The URL to crawl.
    # @yield [doc] The crawled HTML Document regardless if the
    #   crawl was successful or not. Therefore, the Document#url can be used.
    # @return [Wgit::Document, nil] The crawled HTML Document or nil if the
    #   crawl was unsuccessful.
  	def crawl_url(url = @urls.first, &block)
      assert_type(url, Url)
  	  markup = fetch(url)
      url.crawled = true
      doc = Wgit::Document.new(url, markup)
      block.call(doc) if block_given?
      doc.empty? ? nil : doc
  	end

    # Crawls an entire site by recursively going through its internal_links.
    #
    # @param base_url [Wgit::Url] The base URL of the website to be crawled.
    # @yield [doc] Given each crawled Document/page of the site.
    #   A block is the only way to interact with each crawled Document.
    # @return [Array<Wgit::Url>, nil] Unique Array of external urls collected
    #   from all of the site's pages or nil if the base_url could not be
    #   crawled successfully.
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
    
    # Add the document to the @docs array for later processing or let the block
    # process it here and now.
    def handle_crawl_block(url, &block)
        if not block_given?
		        @docs << crawl_url(url)
            nil
        else
            crawl_url(url, &block)
        end
    end
  
    # The fetch method performs a HTTP GET to obtain the HTML document.
    # Invalid urls or any HTTP response that doesn't return a HTML body will be
    # ignored and nil will be returned.  This means that redirects etc. will
    # not be followed.
    def fetch(url)
        raise unless url.respond_to?(:to_uri)
        res = Net::HTTP.get_response(url.to_uri)
        res.body.empty? ? nil : res.body
    rescue
        nil
    end
  
    # Add the url to @urls ensuring it is cast to a Wgit::Url if necessary.
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
