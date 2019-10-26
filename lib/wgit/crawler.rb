# frozen_string_literal: true

require_relative 'url'
require_relative 'document'
require_relative 'utils'
require_relative 'assertable'
require 'typhoeus'

module Wgit
  # The Crawler class provides a means of crawling web based HTTP Wgit::Url's,
  # serialising their HTML into Wgit::Document instances.
  class Crawler
    include Assertable

    # The amount of allowed redirects before raising an error. Set to 0 to
    # disable redirects completely.
    attr_accessor :redirect_limit

    # The maximum amount of time (in seconds) a crawl request has to complete
    # before raising an error. Set to 0 to disable time outs completely.
    attr_accessor :time_out

    # Whether or not to UTF-8 encode the HTML once crawled. Set to false if
    # crawling more than just HTML e.g. images etc.
    attr_accessor :encode_html

    # The Typhoeus::Response of the most recently crawled URL or nil.
    # See https://rubydoc.info/gems/typhoeus/Typhoeus/Response for more info.
    attr_reader :last_response

    # Initializes and returns a Wgit::Crawler instance.
    #
    # @param redirect_limit [Integer] The amount of allowed redirects before
    #   raising an error. Set to 0 to disable redirects completely.
    # @param time_out [Integer, Float] The maximum amount of time (in seconds)
    #   a crawl request has to complete before raising an error. Set to 0 to
    #   disable time outs completely.
    # @param encode_html [Boolean] Whether or not to UTF-8 encode the HTML once
    #   crawled. Set to false if crawling more than just HTML e.g. images etc.
    def initialize(redirect_limit: 5, time_out: 5, encode_html: true)
      @redirect_limit = redirect_limit
      @time_out       = time_out
      @encode_html    = encode_html
    end

    # Crawls an entire website's HTML pages by recursively going through
    # its internal links. Each crawled Document is yielded to a block.
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
    # @yield [doc] Given each crawled page (Wgit::Document) of the site.
    #   A block is the only way to interact with each crawled Document.
    # @return [Array<Wgit::Url>, nil] Unique Array of external urls collected
    #   from all of the site's pages or nil if the url could not be
    #   crawled successfully.
    def crawl_site(url, &block)
      doc = crawl_url(url, &block)
      return nil if doc.nil?

      opts      = { follow_external_redirects: false, host: url.to_base }
      alt_url   = url.end_with?('/') ? url.chop : url + '/'
      crawled   = [url, alt_url]
      externals = doc.external_links
      internals = get_internal_links(doc)

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

    # Crawls one or more individual urls using Wgit::Crawler#crawl_url
    # underneath. See Wgit::Crawler#crawl_site for crawling entire sites.
    #
    # @param urls [*Wgit::Url] The Url's to crawl.
    # @yield [doc] Given each crawled page (Wgit::Document); this is the only
    #   way to interact with them.
    # @raise [StandardError] If no urls are provided.
    # @return [Wgit::Document] The last Document crawled.
    def crawl_urls(*urls, follow_external_redirects: true, host: nil, &block)
      raise 'You must provide at least one Url' if urls.empty?

      opts = {
        follow_external_redirects: follow_external_redirects,
        host: host
      }
      doc = nil

      Wgit::Utils.each(urls) { |url| doc = crawl_url(url, opts, &block) }

      doc
    end

    # Crawl the url returning the response Wgit::Document or nil, if an error
    # occurs.
    #
    # @param url [Wgit::Url] The Url to crawl; which will likely be modified.
    # @param follow_external_redirects [Boolean] Whether or not to follow
    #   an external redirect. External meaning to a different host. False will
    #   return nil for such a crawl. If false, you must also provide a `host:`
    #   parameter.
    # @param host [Wgit::Url, String] Specify the host by which
    #   an absolute redirect is determined to be internal or not. Must be
    #   absolute and contain a protocol prefix. For example, a `host:` of
    #   'http://www.example.com' will only allow redirects for Url's with a
    #   `to_host` value of 'www.example.com'.
    # @yield [doc] The crawled HTML page (Wgit::Document) regardless if the
    #   crawl was successful or not. Therefore, Document#url etc. can be used.
    # @return [Wgit::Document, nil] The crawled HTML Document or nil if the
    #   crawl was unsuccessful.
    def crawl_url(url, follow_external_redirects: true, host: nil)
      # A String url isn't allowed because it's passed by value not reference,
      # meaning a redirect isn't reflected; A Wgit::Url is passed by reference.
      assert_type(url, Wgit::Url)
      raise 'host cannot be nil if follow_external_redirects is false' \
      if !follow_external_redirects && host.nil?

      html = fetch(
        url,
        follow_external_redirects: follow_external_redirects,
        host: host
      )

      doc = Wgit::Document.new(url, html, encode_html: @encode_html)
      yield(doc) if block_given?

      doc.empty? ? nil : doc
    end

    protected

    # Fetches the url HTML String or nil. Handles any errors that arise
    # and sets the @last_response. Errors or any HTTP response that doesn't
    # return a HTML body will be ignored, returning nil.
    #
    # @param url [Wgit::Url] The URL to fetch. This Url object is passed by
    #   reference and gets modified as a result of the fetch/crawl.
    # @param follow_external_redirects [Boolean] Whether or not to follow
    #   an external redirect. False will return nil for such a crawl. If false,
    #   you must also provide a `host:` parameter.
    # @param host [Wgit::Url, String] Specify the host by which
    #   an absolute redirect is determined to be internal or not. Must be
    #   absolute and contain a protocol prefix. For example, a `host:` of
    #   'http://www.example.com' will only allow redirects for Urls with a
    #   `to_host` value of 'www.example.com'.
    # @return [String, nil] The crawled HTML or nil if the crawl was
    #   unsuccessful.
    def fetch(url, follow_external_redirects: true, host: nil)
      response       = nil
      crawl_duration = nil

      response = resolve(
        url,
        follow_external_redirects: follow_external_redirects,
        host: host
      )
      crawl_duration = response.total_time

      response.body.empty? ? nil : response.body
    rescue StandardError => e
      Wgit.logger.debug("Wgit::Crawler#fetch('#{url}') exception: #{e.message}")

      nil
    ensure
      url.crawled        = true # Also sets date_crawled underneath.
      url.crawl_duration = crawl_duration
      @last_response     = response
    end

    # Resolves the url by handling any redirects. The response object will be
    # returned or an error raised.
    #
    # @param url [Wgit::Url] The URL to resolve.
    # @param follow_external_redirects [Boolean] Whether or not to follow
    #   an external redirect. If false, you must also provide a `host:`
    #   parameter.
    # @param host [Wgit::Url, String] Specify the host by which
    #   an absolute redirect is determined to be internal or not. Must be
    #   absolute and contain a protocol prefix. For example, a `host:` of
    #   'http://www.example.com' will only allow redirects for Urls with a
    #   `to_host` value of 'www.example.com'.
    # @raise [StandardError] If a redirect isn't allowed etc.
    # @return [Typhoeus::Response] The HTTP response of the GET request.
    def resolve(url, follow_external_redirects: true, host: nil)
      response       = nil
      redirect_count = 0
      total_net_time = 0.0

      loop do
        response = get_response(url)
        total_net_time += response.total_time if response.total_time

        # Break unless it's a redirect.
        break unless (response.code >= 300) && (response.code < 400)

        # Handle response 'Location' header.
        location = Wgit::Utils.fetch(response.headers, :location, '')
        location = Wgit::Url.new(location)
        raise 'Encountered redirect without Location header' if location.empty?

        yield(url, response, location) if block_given?

        # Handle redirect logic.
        if !follow_external_redirects && !location.relative?(host: host)
          raise "External redirect not allowed - Redirected to: \
'#{location}', which is outside of host: '#{host}'"
        end

        raise "Too many redirects, exceeded: #{redirect_count}" \
        if redirect_count >= @redirect_limit

        redirect_count += 1

        # Process the location to be crawled next.
        location = url.to_base.concat(location) if location.relative?
        url.replace(location) # Update the url on redirect.
      end

      response.options[:redirect_count] = redirect_count
      response.options[:total_time]     = total_net_time

      response
    end

    # Performs a HTTP GET request and returns the response.
    #
    # @param url [String] The url to GET. Will call url#normalize if possible.
    # @raise [StandardError] If a response can't be obtained.
    # @return [Typhoeus::Response] The HTTP response of the GET request.
    def get_response(url)
      url = url.normalize if url.respond_to?(:normalize)

      opts = {
        followlocation: false,
        timeout: @time_out,
        accept_encoding: 'gzip',
        headers: {
          'User-Agent' => "wgit/#{Wgit::VERSION}",
          'Accept'     => 'text/html'
        }
      }

      response = Typhoeus.get(url, opts)

      # Handle response status code.
      raise "No response (within timeout: #{@time_out} second(s))" \
      if response.code.zero?

      response
    end

    # Returns a doc's internal HTML page links in absolute form; used when
    # crawling a site.
    #
    # Override this method in a subclass to change how a site
    # is crawled; not what is extracted from each page (Document extensions
    # should be used for this purpose instead). Just remember that only HTML
    # files contain <a> links to keep the crawl going beyond the base URL.
    #
    # @param doc [Wgit::Document] The document from which to extract it's
    #   internal page links.
    # @return [Array<Wgit::Url>] The internal page links from doc.
    def get_internal_links(doc)
      doc.internal_absolute_links
         .map(&:without_anchor) # Because anchors don't change page content.
         .uniq
         .reject do |link|
        ext = link.to_extension
        ext ? !%w[htm html].include?(ext.downcase) : false
      end
    end

    alias crawl       crawl_urls
    alias crawl_pages crawl_urls
    alias crawl_page  crawl_url
    alias crawl_r     crawl_site
  end
end
