require_relative 'url'
require_relative 'document'
require_relative 'utils'
require_relative 'assertable'
require 'net/http' # Requires 'uri'.

module Wgit

  # The Crawler class provides a means of crawling web based Wgit::Url's, turning
  # their HTML into Wgit::Document instances.
  class Crawler
    include Assertable

    # The default maximum amount of allowed URL redirects.
    @default_redirect_limit = 5

    class << self
      # Class level instance accessor methods for @default_redirect_limit.
      # Call using Wgit::Crawler.default_redirect_limit etc.
      attr_accessor :default_redirect_limit
    end

    # The urls to crawl.
    attr_reader :urls

    # The docs of the crawled @urls.
    attr_reader :docs

    # The Net::HTTPResponse of the most recently crawled URL or nil.
    attr_reader :last_response

    # Initializes the Crawler and sets the @urls and @docs.
    #
    # @param urls [*Wgit::Url] The URL's to crawl in the future using either
    #   Crawler#crawl_url or Crawler#crawl_site. Note that the urls passed here
    #   will NOT update if they happen to redirect when crawled. If in doubt,
    #   pass the url(s) directly to the crawl_* method instead of to the new
    #   method.
    def initialize(*urls)
      self.[](*urls)
      @docs = []
    end

    # Sets this Crawler's @urls.
    #
    # @param urls [*Wgit::Url] The URL's to crawl in the future using either
    #   crawl_url or crawl_site. Note that the urls passed here will NOT update
    #   if they happen to redirect when crawled. If in doubt, pass the url(s)
    #   directly to the crawl_* method instead of to the new method.
    def urls=(urls)
      @urls = []
      Wgit::Utils.each(urls) { |url| add_url(url) }
    end

    # Sets this Crawler's @urls.
    #
    # @param urls [*Wgit::Url] The URL's to crawl in the future using either
    #   crawl_url or crawl_site. Note that the urls passed here will NOT update
    #   if they happen to redirect when crawled. If in doubt, pass the url(s)
    #   directly to the crawl_* method instead of to the new method.
    def [](*urls)
      # If urls is nil then add_url (when called later) will set @urls = []
      # so we do nothing here.
      if not urls.nil?
        # Due to *urls you can end up with [[url1,url2,url3]] etc. where the
        # outer array is bogus so we use the inner one only.
        if  urls.is_a?(Enumerable) &&
            urls.length == 1 &&
            urls.first.is_a?(Enumerable)
          urls = urls.first
        end

        # Here we call urls= method using self because the param name is also
        # urls which conflicts.
        self.urls = urls
      end
    end

    # Adds the url to this Crawler's @urls.
    #
    # @param url [Wgit::Url] A URL to crawl later by calling a crawl_* method.
    #   Note that the url added here will NOT update if it happens to
    #   redirect when crawled. If in doubt, pass the url directly to the
    #   crawl_* method instead of to the new method.
    def <<(url)
      add_url(url)
    end

    # Crawls one or more individual urls using Crawler#crawl_url underneath.
    # See Crawler#crawl_site for crawling entire sites. Note that any external
    # redirects are followed. Use Crawler#crawl_url yourself if this isn't
    # desirable.
    #
    # @param urls [Array<Wgit::Url>] The URLs to crawl.
    # @yield [Wgit::Document] If provided, the block is given each crawled
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

    # Crawl the url returning the response Document or nil if an error occurs.
    #
    # @param url [Wgit::Document] The URL to crawl.
    # @param follow_external_redirects [Boolean] Whether or not to follow
    #   an external redirect. False will return nil for such a crawl. If false,
    #   you must also provide a `base_domain:` parameter.
    # @param base_domain [Wgit::Url, String] Specify the domain by which
    #   a redirect is determined to be internal or not. For example, a
    #   `base_domain:` of 'http://www.example.com' will only allow redirects to
    #   Urls with a `to_domain` value of 'example.com'.
    # @yield [Wgit::Document] The crawled HTML Document regardless if the
    #   crawl was successful or not. Therefore, the Document#url can be used.
    # @return [Wgit::Document, nil] The crawled HTML Document or nil if the
    #   crawl was unsuccessful.
    def crawl_url(
        url = @urls.first,
        follow_external_redirects: true,
        base_domain: nil
      )
      assert_type(url, Wgit::Url)
      if !follow_external_redirects and base_domain.nil?
        raise 'base_domain cannot be nil if follow_external_redirects is false'
      end

      html = fetch(
        url,
        follow_external_redirects: follow_external_redirects,
        base_domain: base_domain
      )
      url.crawled = true

      doc = Wgit::Document.new(url, html)
      yield(doc) if block_given?

      doc.empty? ? nil : doc
    end

    # Crawls an entire website's HTML pages by recursively going through
    # its internal links. Each crawled Document is yielded to a block.
    #
    # Only redirects within the same domain are allowed. For example, the Url
    # 'http://www.example.co.uk' has a domain of 'example.co.uk' meaning a
    # redirect to 'https://ftp.example.co.uk' will be allowed whereas a
    # redirect to 'http://www.example.com' will not.
    #
    # @param base_url [Wgit::Url] The base URL of the website to be crawled.
    #   It is recommended that this URL be the index page of the site to give a
    #   greater chance of finding all pages within that site/domain.
    # @yield [Wgit::Document] Given each crawled Document/page of the site.
    #   A block is the only way to interact with each crawled Document.
    # @return [Array<Wgit::Url>, nil] Unique Array of external urls collected
    #   from all of the site's pages or nil if the base_url could not be
    #   crawled successfully.
    def crawl_site(base_url = @urls.first, &block)
      assert_type(base_url, Wgit::Url)
      opts = {
        follow_external_redirects: false,
        base_domain: base_url.to_base,
      }.freeze

      doc = crawl_url(base_url, opts, &block)
      return nil if doc.nil?

      alt_base_url = base_url.end_with?('/') ? base_url.chop : base_url + '/'
      crawled      = [base_url, alt_base_url]
      externals    = doc.external_links
      internals    = get_internal_links(doc)

      return doc.external_links.uniq if internals.empty?

      loop do
        crawled.uniq!
        internals.uniq!

        links = internals - crawled
        break if links.empty?

        links.each do |link|
          orig_link = link.dup
          doc = crawl_url(link, opts, &block)

          crawled.push(orig_link, link) # Push both in case of redirects.
          next if doc.nil?

          internals.concat(get_internal_links(doc))
          externals.concat(doc.external_links)
        end
      end

      externals.uniq
    end

  private

    # Add the document to the @docs array for later processing or let the block
    # process it here and now.
    def handle_crawl_block(url, &block)
      if block_given?
        crawl_url(url, &block)
      else
        @docs << crawl_url(url)
        nil
      end
    end

    # The fetch method performs a HTTP GET to obtain the HTML document.
    # Invalid urls or any HTTP response that doesn't return a HTML body will be
    # ignored and nil will be returned. Otherwise, the HTML is returned.
    # External redirects are followed by default but can be disabled.
    def fetch(url, follow_external_redirects: true, base_domain: nil)
      response = resolve(
        url,
        follow_external_redirects: follow_external_redirects,
        base_domain: base_domain
      )
      @last_response = response
      response.body.empty? ? nil : response.body
    rescue Exception => ex
      Wgit.logger.debug(
        "Wgit::Crawler#fetch('#{url}') exception: #{ex.message}"
      )
      @last_response = nil
      nil
    end

    # The resolve method performs a HTTP GET to obtain the HTML document.
    # A certain amount of redirects will be followed by default before raising
    # an exception. Redirects can be disabled by setting `redirect_limit: 0`.
    # External redirects are followed by default but can be disabled.
    # The Net::HTTPResponse will be returned.
    def resolve(
        url,
        redirect_limit: Wgit::Crawler.default_redirect_limit,
        follow_external_redirects: true,
        base_domain: nil
      )
      raise 'url must respond to :to_uri' unless url.respond_to?(:to_uri)
      redirect_count = 0

      begin
        response = Net::HTTP.get_response(url.to_uri)
        location = Wgit::Url.new(response.fetch('location', ''))

        if not location.empty?
          if  !follow_external_redirects and
              !location.is_relative?(base: base_domain)
            raise 'External redirect encountered but not allowed'
          end

          raise 'Too many redirects' if redirect_count >= redirect_limit
          redirect_count += 1

          location = url.to_base.concat(location) if location.is_relative?
          url.replace(location)
        end
      end while response.is_a?(Net::HTTPRedirection)

      response
    end

    # Add the url to @urls ensuring it is cast to a Wgit::Url if necessary.
    def add_url(url)
      @urls = [] if @urls.nil?
      @urls << Wgit::Url.new(url)
    end

    # Returns doc's internal HTML page links in absolute form for crawling.
    # We remove anchors because they are client side and don't change the
    # resulting page's HTML; unlike query strings for example, which do.
    def get_internal_links(doc)
      doc.internal_full_links.
        map(&:without_anchor).
        uniq.
        reject do |link|
          ext = link.to_extension
          ext ? !['htm', 'html'].include?(ext) : false
        end
    end

    alias :crawl :crawl_urls
    alias :crawl_pages :crawl_urls
    alias :crawl_page :crawl_url
    alias :crawl_r :crawl_site
  end
end
