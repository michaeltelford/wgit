# frozen_string_literal: true

require_relative 'url'
require_relative 'document'
require_relative 'utils'
require_relative 'assertable'
require_relative 'response'
require 'benchmark'
require 'typhoeus'
require 'ferrum'

module Wgit
  # The Crawler class provides a means of crawling web based HTTP `Wgit::Url`s,
  # and serialising their HTML into `Wgit::Document` instances. This is the
  # only Wgit class containing network logic (HTTP request/response handling).
  class Crawler
    include Assertable

    # Set of supported file extensions for Wgit::Crawler#crawl_site.
    @supported_file_extensions = Set.new(
      %w[asp aspx cfm cgi htm html htmlx jsp php]
    )

    class << self
      # The URL file extensions (from `<a>` hrefs) which will be crawled by
      # `#crawl_site`. The idea is to omit anything that isn't HTML and therefore
      # doesn't keep the crawl of the site going. All URL's without a file
      # extension will be crawled, because they're assumed to be HTML.
      # The `#crawl` method will crawl anything since it's given the URL(s).
      # You can add your own site's URL file extension e.g.
      # `Wgit::Crawler.supported_file_extensions << 'html5'` etc.
      attr_reader :supported_file_extensions
    end

    # The amount of allowed redirects before raising an error. Set to 0 to
    # disable redirects completely; or you can pass `follow_redirects: false`
    # to any Wgit::Crawler.crawl_* method.
    attr_accessor :redirect_limit

    # The maximum amount of time (in seconds) a crawl request has to complete
    # before raising an error. Set to 0 to disable time outs completely.
    attr_accessor :timeout

    # Whether or not to UTF-8 encode the response body once crawled. Set to
    # false if crawling more than just HTML e.g. images.
    attr_accessor :encode

    # Whether or not to parse the Javascript of the crawled document.
    # Parsing requires Chrome/Chromium to be installed and in $PATH.
    attr_accessor :parse_javascript

    # The delay between checks in a page's HTML size. When the page has stopped
    # "growing", the Javascript has finished dynamically updating the DOM.
    # The value should balance between a good UX and enough JS parse time.
    attr_accessor :parse_javascript_delay

    # The Wgit::Response of the most recently crawled URL.
    attr_reader :last_response

    # Initializes and returns a Wgit::Crawler instance.
    #
    # @param redirect_limit [Integer] The amount of allowed redirects before
    #   raising an error. Set to 0 to disable redirects completely.
    # @param timeout [Integer, Float] The maximum amount of time (in seconds)
    #   a crawl request has to complete before raising an error. Set to 0 to
    #   disable time outs completely.
    # @param encode [Boolean] Whether or not to UTF-8 encode the response body
    #   once crawled. Set to false if crawling more than just HTML e.g. images.
    # @param parse_javascript [Boolean] Whether or not to parse the Javascript
    #   of the crawled document. Parsing requires Chrome/Chromium to be
    #   installed and in $PATH.
    def initialize(redirect_limit: 5, timeout: 5, encode: true,
                   parse_javascript: false, parse_javascript_delay: 1)
      @redirect_limit         = redirect_limit
      @timeout                = timeout
      @encode                 = encode
      @parse_javascript       = parse_javascript
      @parse_javascript_delay = parse_javascript_delay
    end

    # Crawls an entire website's HTML pages by recursively going through
    # its internal `<a>` links; this can be overridden with `follow: xpath`.
    # Each crawled Document is yielded to a block. Use `doc.empty?` to
    # determine if the crawled link was successful / is valid.
    #
    # Use the allow and disallow paths params to partially and selectively
    # crawl a site; the glob syntax is fully supported e.g. `'wiki/\*'` etc.
    #
    # Only redirects to the same host are followed. For example, the Url
    # 'http://www.example.co.uk/how' has a host of 'www.example.co.uk' meaning
    # a link which redirects to 'https://ftp.example.co.uk' or
    # 'https://www.example.com' will not be followed. The only exception to
    # this is the initially crawled url which is allowed to redirect anywhere;
    # it's host is then used for other link redirections on the site, as
    # described above.
    #
    # @param url [Wgit::Url] The base URL of the website to be crawled.
    #   It is recommended that this URL be the index page of the site to give a
    #   greater chance of finding all pages within that site/host.
    # @param follow [String] The xpath extracting links to be followed during
    #   the crawl. This changes how a site is crawled. Only links pointing to
    #   the site domain are allowed. The `:default` is any `<a>` href returning
    #   HTML.
    # @param allow_paths [String, Array<String>] Filters the `follow:` links by
    #   selecting them if their path `File.fnmatch?` one of allow_paths.
    # @param disallow_paths [String, Array<String>] Filters the `follow` links
    #   by rejecting them if their path `File.fnmatch?` one of disallow_paths.
    # @yield [doc] Given each crawled page (Wgit::Document) of the site.
    #   A block is the only way to interact with each crawled Document.
    #   Use `doc.empty?` to determine if the page is valid.
    # @return [Array<Wgit::Url>, nil] Unique Array of external urls collected
    #   from all of the site's pages or nil if the given url could not be
    #   crawled successfully.
    def crawl_site(
      url, follow: :default, allow_paths: nil, disallow_paths: nil, &block
    )
      doc = crawl_url(url, &block)
      return nil if doc.nil?

      link_opts = { xpath: follow, allow_paths:, disallow_paths: }
      alt_str   = url.end_with?('/') ? url.chop : "#{url}/"
      alt_url   = Wgit::Url.new(alt_str)

      crawled   = Set.new([url, alt_url])
      externals = Set.new(doc.external_links)
      internals = Set.new(next_internal_links(doc, **link_opts))

      return externals.to_a if internals.empty?

      loop do
        links = internals - crawled
        break if links.empty?

        links.each do |link|
          doc = crawl_url(link, follow_redirects: :host, &block)

          redirects = url.redirects.keys
          crawled += [link, redirects].flatten

          next if doc.nil?

          internals += next_internal_links(doc, **link_opts)
          externals += doc.external_links
        end
      end

      externals.to_a
    end

    # Crawls one or more individual urls using Wgit::Crawler#crawl_url
    # underneath. See Wgit::Crawler#crawl_site for crawling entire sites.
    #
    # @param urls [*Wgit::Url] The Url's to crawl.
    # @param follow_redirects [Boolean, Symbol] Whether or not to follow
    #   redirects. Pass a Symbol to limit where the redirect is allowed to go
    #   e.g. :host only allows redirects within the same host. Choose from
    #   :origin, :host, :domain or :brand. See Wgit::Url#relative? opts param.
    #   This value will be used for all urls crawled.
    # @yield [doc] Given each crawled page (Wgit::Document); this is the only
    #   way to interact with them. Use `doc.empty?` to determine if the page
    #   is valid.
    # @raise [StandardError] If no urls are provided.
    # @return [Wgit::Document] The last Document crawled.
    def crawl_urls(*urls, follow_redirects: true, &block)
      raise 'You must provide at least one Url' if urls.empty?

      opts = { follow_redirects: }
      doc = nil

      Wgit::Utils.each(urls) { |url| doc = crawl_url(url, **opts, &block) }

      doc
    end

    # Crawl the url returning the response Wgit::Document or nil, if an error
    # occurs.
    #
    # @param url [Wgit::Url] The Url to crawl; which will be modified in the
    #   event of a redirect.
    # @param follow_redirects [Boolean, Symbol] Whether or not to follow
    #   redirects. Pass a Symbol to limit where the redirect is allowed to go
    #   e.g. :host only allows redirects within the same host. Choose from
    #   :origin, :host, :domain or :brand. See Wgit::Url#relative? opts param.
    # @yield [doc] The crawled HTML page (Wgit::Document) regardless if the
    #   crawl was successful or not. Therefore, Document#url etc. can be used.
    #   Use `doc.empty?` to determine if the page is valid.
    # @return [Wgit::Document, nil] The crawled HTML Document or nil if the
    #   crawl was unsuccessful.
    def crawl_url(url, follow_redirects: true)
      # A String url isn't allowed because it's passed by value not reference,
      # meaning a redirect isn't reflected; A Wgit::Url is passed by reference.
      assert_type(url, Wgit::Url)

      html = fetch(url, follow_redirects:)
      doc  = Wgit::Document.new(url, html, encode: @encode)

      yield(doc) if block_given?

      doc.empty? ? nil : doc
    end

    protected

    # Returns the URL's HTML String or nil. Handles any errors that arise
    # and sets the @last_response. Errors or any HTTP response that doesn't
    # return a HTML body will be ignored, returning nil.
    #
    # If @parse_javascript is true, then the final resolved URL will be browsed
    # to and Javascript parsed allowing for dynamic HTML generation.
    #
    # @param url [Wgit::Url] The URL to fetch. This Url object is passed by
    #   reference and gets modified as a result of the fetch/crawl.
    # @param follow_redirects [Boolean, Symbol] Whether or not to follow
    #   redirects. Pass a Symbol to limit where the redirect is allowed to go
    #   e.g. :host only allows redirects within the same host. Choose from
    #   :origin, :host, :domain or :brand. See Wgit::Url#relative? opts param.
    # @raise [StandardError] If url isn't valid and absolute.
    # @return [String, nil] The crawled HTML or nil if the crawl was
    #   unsuccessful.
    def fetch(url, follow_redirects: true)
      response = Wgit::Response.new
      raise "Invalid url: #{url}" if url.invalid?

      resolve(url, response, follow_redirects:)
      get_browser_response(url, response) if @parse_javascript

      response.body_or_nil
    rescue StandardError => e
      Wgit.logger.debug("Wgit::Crawler#fetch('#{url}') exception: #{e}")

      nil
    ensure
      url.crawled        = true # Sets date_crawled underneath.
      url.crawl_duration = response.total_time

      # Don't override previous url.redirects if response is fully resolved.
      url.redirects      = response.redirects unless response.redirects.empty?

      @last_response = response
    end

    # GETs the given url, resolving any redirects. The given response object
    # will be enriched.
    #
    # @param url [Wgit::Url] The URL to GET and resolve.
    # @param response [Wgit::Response] The response to enrich. Modifies by
    #   reference.
    # @param follow_redirects [Boolean, Symbol] Whether or not to follow
    #   redirects. Pass a Symbol to limit where the redirect is allowed to go
    #   e.g. :host only allows redirects within the same host. Choose from
    #   :origin, :host, :domain or :brand. See Wgit::Url#relative? opts param.
    # @raise [StandardError] If a redirect isn't allowed etc.
    def resolve(url, response, follow_redirects: true)
      origin = url.to_url.to_origin # Recorded before any redirects.
      follow_redirects, within = redirect?(follow_redirects)

      loop do
        get_http_response(url, response)
        break unless response.redirect?

        # Handle response 'Location' header.
        location = Wgit::Url.new(response.headers.fetch(:location, ''))
        raise 'Encountered redirect without Location header' if location.empty?

        yield(url, response, location) if block_given?

        # Validate if the redirect is allowed.
        raise "Redirect not allowed: #{location}" unless follow_redirects

        if within && !location.relative?(within => origin)
          raise "Redirect (outside of #{within}) is not allowed: '#{location}'"
        end

        raise "Too many redirects, exceeded: #{@redirect_limit}" \
        if response.redirect_count >= @redirect_limit

        # Process the location to be crawled next.
        location = url.to_origin.join(location) if location.relative?
        response.redirections[url.to_s] = location.to_s
        url.replace(location) # Update the url on redirect.
      end
    end

    # Makes a HTTP request and enriches the given Wgit::Response from it.
    #
    # @param url [String] The url to GET. Will call url#normalize if possible.
    # @param response [Wgit::Response] The response to enrich. Modifies by
    #   reference.
    # @raise [StandardError] If a response can't be obtained.
    # @return [Wgit::Response] The enriched HTTP Wgit::Response object.
    def get_http_response(url, response)
      # Perform a HTTP GET request.
      orig_url = url.to_s
      url      = url.normalize if url.respond_to?(:normalize)

      http_response = http_get(url)

      # Enrich the given Wgit::Response object.
      response.adapter_response = http_response
      response.url              = orig_url
      response.status           = http_response.code
      response.headers          = http_response.headers
      response.body             = http_response.body
      response.ip_address       = http_response.primary_ip
      response.add_total_time(http_response.total_time)

      # Log the request/response details.
      log_net(:http, response, http_response.total_time)

      # Handle a failed response.
      raise "No response (within timeout: #{@timeout} second(s))" \
      if response.failure?
    end

    # Makes a browser request and enriches the given Wgit::Response from it.
    #
    # @param url [String] The url to browse to. Will call url#normalize if
    #   possible.
    # @param response [Wgit::Response] The response to enrich. Modifies by
    #   reference.
    # @raise [StandardError] If a response can't be obtained.
    # @return [Wgit::Response] The enriched HTTP Wgit::Response object.
    def get_browser_response(url, response)
      url     = url.normalize if url.respond_to?(:normalize)
      browser = nil

      crawl_time = Benchmark.measure { browser = browser_get(url) }.real
      yield browser if block_given?

      # Enrich the given Wgit::Response object (on top of Typhoeus response).
      response.adapter_response = browser.network.response
      response.status           = browser.network.response.status
      response.headers          = browser.network.response.headers
      response.body             = browser.body
      response.add_total_time(crawl_time)

      # Log the request/response details.
      log_net(:browser, response, crawl_time)

      # Handle a failed response.
      raise "No browser response (within timeout: #{@timeout} second(s))" \
      if response.failure?
    end

    # Performs a HTTP GET request and returns the response.
    #
    # @param url [String] The url to GET.
    # @return [Typhoeus::Response] The HTTP response object.
    def http_get(url)
      opts = {
        followlocation: false,
        timeout: @timeout,
        accept_encoding: 'gzip',
        headers: {
          'User-Agent' => "wgit/#{Wgit::VERSION}",
          'Accept'     => 'text/html'
        }
      }

      # See https://rubydoc.info/gems/typhoeus for more info.
      Typhoeus.get(url, **opts)
    end

    # Performs a HTTP GET request in a web browser and parses the response JS
    # before returning the HTML body of the fully rendered webpage. This allows
    # Javascript (SPA apps etc.) to generate HTML dynamically.
    #
    # @param url [String] The url to browse to.
    # @return [Ferrum::Browser] The browser response object.
    def browser_get(url)
      @browser ||= Ferrum::Browser.new(timeout: @timeout, process_timeout: 10)
      @browser.goto(url)

      # Wait for the page's JS to finish dynamically manipulating the DOM.
      html = @browser.body
      loop do
        sleep @parse_javascript_delay
        break if html.size == @browser.body.size

        html = @browser.body
      end

      @browser
    end

    # Returns a doc's internal HTML page links in absolute form; used when
    # crawling a site. By default, any `<a>` href returning HTML is returned;
    # override this with `xpath:` if desired.
    #
    # Use the allow and disallow paths params to partially and selectively
    # crawl a site; the glob syntax is supported e.g. `'wiki/\*'` etc. Note
    # that each path should NOT start with a slash.
    #
    # @param doc [Wgit::Document] The document from which to extract it's
    #   internal (absolute) page links.
    # @param xpath [String] The xpath selecting links to be returned. Only
    #   links pointing to the doc.url domain are allowed. The :default is any
    #   <a> href returning HTML. The allow/disallow paths will be applied to
    #   the returned value.
    # @param allow_paths [String, Array<String>] Filters links by selecting
    #   them if their path `File.fnmatch?` one of allow_paths.
    # @param disallow_paths [String, Array<String>] Filters links by rejecting
    #   them if their path `File.fnmatch?` one of disallow_paths.
    # @return [Array<Wgit::Url>] The internal page links from doc.
    def next_internal_links(
      doc, xpath: :default, allow_paths: nil, disallow_paths: nil
    )
      links = if xpath && xpath != :default
                follow_xpath(doc, xpath)
              else
                follow_default(doc)
              end

      return links if allow_paths.nil? && disallow_paths.nil?

      process_paths(links, allow_paths, disallow_paths)
    end

    private

    # Returns the next links used to continue crawling a site. The xpath value
    # is used to obtain the links. Any valid URL Strings will be converted into
    # absolute Wgit::Urls. Invalid URLs will be silently dropped. Any link not
    # pointing to the site domain will raise an error.
    def follow_xpath(doc, xpath)
      links = doc.send(:extract_from_html, xpath, singleton: false) do |urls|
        urls
          .map { |url| Wgit::Url.parse?(url)&.make_absolute(doc) }
          .compact
      end

      if links.any? { |link| link.to_domain != doc.url.to_domain }
        raise 'The links to follow must be within the site domain'
      end

      links
    end

    # Returns the default set of links used to continue crawling a site.
    # By default, any <a> href returning HTML and pointing to the same domain
    # will get returned.
    def follow_default(doc)
      doc
        .internal_absolute_links
        .map(&:omit_fragment) # Because fragments don't alter content.
        .uniq
        .select do |link| # Whitelist only HTML content.
          ext = link.to_extension
          if ext
            Wgit::Crawler.supported_file_extensions.include?(ext.downcase)
          else
            true # URLs without an extension are assumed HTML.
          end
        end
    end

    # Validate and filter by the given URL paths.
    def process_paths(links, allow_paths, disallow_paths)
      if allow_paths && !allow_paths.empty?
        paths = validate_paths(allow_paths)
        filter_links(links, :select!, paths)
      end

      if disallow_paths && !disallow_paths.empty?
        paths = validate_paths(disallow_paths)
        filter_links(links, :reject!, paths)
      end

      links
    end

    # Validate the paths are suitable for filtering.
    def validate_paths(paths)
      paths = *paths
      raise 'The provided paths must all be Strings' \
      unless paths.all? { |path| path.is_a?(String) }

      paths = Wgit::Utils.sanitize(paths, encode: false)
      raise 'The provided paths cannot be empty' if paths.empty?

      paths.map do |path|
        path = Wgit::Url.parse(path)
        path.index? ? path : path.omit_slashes
      end
    end

    # Filters links by selecting/rejecting them based on their path.
    # Uses File.fnmatch? so that globbing is supported.
    def filter_links(links, filter_method, paths)
      links.send(filter_method) do |link|
        # Turn http://example.com into / meaning index.
        link = link.to_endpoint.index? ? '/' : link.omit_base

        match = false
        paths.each do |pattern|
          match = File.fnmatch?(pattern, link, File::FNM_EXTGLOB)
          break if match
        end

        match
      end
    end

    # Returns whether or not to follow redirects, and within what context e.g.
    # :host, :domain etc.
    def redirect?(follow_redirects)
      return [true, follow_redirects] if follow_redirects.is_a?(Symbol)

      unless [true, false].include?(follow_redirects)
        raise "follow_redirects: must be a Boolean or Symbol, not: \
#{follow_redirects}"
      end

      [follow_redirects, nil]
    end

    # Log (at debug level) the network request/response details.
    def log_net(client, response, duration)
      resp_template  = "[#{client}] Response: %s (%s bytes in %s seconds)"
      log_status     = (response.status || 0)
      log_total_time = (duration || 0.0).truncate(3)

      # The browsers request URL is the same so ignore it.
      if client.to_sym == :http
        Wgit.logger.debug("[#{client}] Request:  #{response.url}")
      end

      Wgit.logger.debug(
        format(resp_template, log_status, response.size, log_total_time)
      )
    end

    alias_method :crawl,       :crawl_urls
    alias_method :crawl_pages, :crawl_urls
    alias_method :crawl_page,  :crawl_url
    alias_method :crawl_r,     :crawl_site
  end
end
