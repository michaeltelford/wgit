require_relative 'utils'
require_relative 'assertable'
require 'uri'

module Wgit

  # Class modeling a web based URL.
  # Can be an internal/relative link e.g. "about.html" or a full URL
  # e.g. "http://www.google.co.uk". Is a subclass of String and uses 'uri'
  # internally.
  class Url < String
    include Assertable

    # Whether or not the Url has been crawled or not.
    attr_accessor :crawled

    # The date which the Url was crawled.
    attr_accessor :date_crawled

    # Initializes a new instance of Wgit::Url which represents a web based
    # HTTP URL.
    #
    # @param url_or_obj [String, Object#fetch#[]] Is either a String based
    #     URL or an object representing a Database record e.g. a MongoDB
    #     document/object.
    # @param crawled [Boolean] Whether or not the HTML of the URL's web
    #     page has been scraped or not.
    # @param date_crawled [Time] Should only be provided if crawled is
    #     true. A suitable object can be returned from
    #     Wgit::Utils.time_stamp.
    # @raise [RuntimeError] If url_or_obj is an Object with missing methods.
    def initialize(url_or_obj, crawled = false, date_crawled = nil)
      # Init from a URL String.
      if url_or_obj.is_a?(String)
        url = url_or_obj.to_s
      # Else init from a database object/document.
      else
        obj = url_or_obj
        assert_respond_to(obj, [:fetch, :[]])

        url = obj.fetch("url") # Should always be present.
        crawled = obj.fetch("crawled", false)
        date_crawled = obj["date_crawled"]
      end

      @uri = URI(url)
      @crawled = crawled
      @date_crawled = date_crawled

      super(url)
    end

    # Raises an exception if url is not a valid HTTP URL.
    #
    # @param url [Wgit::Url, String] The Url to validate.
    # @raise [RuntimeError] If url is invalid.
    def self.validate(url)
      if Wgit::Url.relative_link?(url)
        raise "Invalid url (or a relative link): #{url}"
      end
      unless url.start_with?("http://") or url.start_with?("https://")
        raise "Invalid url (missing protocol prefix): #{url}"
      end
      if URI.regexp.match(url).nil?
        raise "Invalid url: #{url}"
      end
    end

    # Determines if the Url is valid or not.
    #
    # @param url [Wgit::Url, String] The Url to validate.
    # @return [Boolean] True if valid, otherwise false.
    def self.valid?(url)
      Wgit::Url.validate(url)
      true
    rescue
      false
    end

    # Modifies the receiver url by prefixing it with a protocol.
    # Returns the url whether its been modified or not.
    # The default protocol prefix is http://.
    #
    # @param url [Wgit::Url, String] The url to be prefixed with a protocol.
    # @param https [Boolean] Whether the protocol prefix is https or http.
    # @return [Wgit::Url] The url with a protocol prefix.
    def self.prefix_protocol(url, https = false)
      unless url.start_with?("http://") or url.start_with?("https://")
        if https
          url.replace("https://#{url}")
        else
          url.replace("http://#{url}")
        end
      end
      url
    end

    # Returns if link is a relative or absolute Url.
    # All external links in a page are expected to have a protocol prefix e.g.
    # "http://", otherwise the link is treated as an internal link (regardless
    # of whether it is valid or not). The only exception is if base is provided
    # and link is a page within that site; then the link is relative.
    #
    # @param link [Wgit::Url, String] The url to test if relative or not.
    # @param base [String] The Url base e.g. http://www.google.co.uk.
    # @return [Boolean] True if relative, false if absolute.
    # @raise [RuntimeError] If the link is invalid.
    def self.relative_link?(link, base: nil)
      raise "Invalid link: #{link}" if link.nil? or link.empty?
      if base and URI(base).host.nil?
        raise "Invalid base, must contain protocol prefix: #{base}"
      end

      uri = URI(link)
      if uri.relative?
        true
      else
        base ? uri.host == URI(base).host : false
      end
    end

    # Concats the host and link Strings and returns the result.
    #
    # @param host [Wgit::Url, String] The Url host.
    # @param link [Wgit::Url, String] The link to add to the host prefix.
    # @return [Wgit::Url] host + "/" + link
    def self.concat(host, link)
      url = host
      url.chop! if url.end_with?('/')
      link = link[1..-1] if link.start_with?('/')
      separator = link.start_with?('#') ? '' : '/'
      Wgit::Url.new(url + separator + link)
    end

    # Returns if self is a relative or absolute Url. If base is provided and
    # self is a page within that site then the link is relative.
    # See Wgit.relative_link? for more information.
    #
    # @return [Boolean] True if relative, false if absolute.
    # @raise [RuntimeError] If the link is invalid.
    def relative_link?(base: nil)
      Wgit::Url.relative_link?(self, base: base)
    end

    # Determines if self is a valid Url or not.
    #
    # @return [Boolean] True if valid, otherwise false.
    def valid?
      Wgit::Url.valid?(self)
    end

    # Concats self and the link.
    #
    # @param link [Wgit::Url, String] The link to concat with self.
    # @return [Wgit::Url] self + "/" + link
    def concat(link)
      Wgit::Url.concat(self, link)
    end

    # Sets the @crawled instance var, also setting @date_crawled to the
    # current time or nil (depending on the bool value).
    #
    # @param bool [Boolean] True if self has been crawled, false otherwise.
    def crawled=(bool)
      @crawled = bool
      @date_crawled = bool ? Wgit::Utils.time_stamp : nil
    end

    # Returns the @uri instance var of this URL.
    #
    # @return [URI::HTTP, URI::HTTPS] The URI object of self.
    def to_uri
      @uri
    end

    # Returns self.
    #
    # @return [Wgit::Url] This (self) Url.
    def to_url
      self
    end

    # Returns a new Wgit::Url containing just the scheme/protocol of this URL
    # e.g. Given http://www.google.co.uk, http is returned.
    #
    # @return [Wgit::Url, nil] Containing just the scheme/protocol or nil.
    def to_scheme
      scheme = @uri.scheme
      scheme ? Wgit::Url.new(scheme) : nil
    end

    # Returns a new Wgit::Url containing just the host of this URL e.g.
    # Given http://www.google.co.uk/about.html, www.google.co.uk is returned.
    #
    # @return [Wgit::Url, nil] Containing just the host or nil.
    def to_host
      host = @uri.host
      host ? Wgit::Url.new(host) : nil
    end

    # Returns only the base of this URL e.g. the protocol and host combined.
    #
    # @return [Wgit::Url, nil] Base of self e.g. http://www.google.co.uk or nil.
    def to_base
      return nil if @uri.scheme.nil? or @uri.host.nil?
      base = "#{@uri.scheme}://#{@uri.host}"
      Wgit::Url.new(base)
    end

    # Returns the path of this URL e.g. the bit after the host without slashes.
    # For example:
    # Wgit::Url.new("http://www.google.co.uk/about.html/").to_path returns
    # "about.html". See Wgit::Url#to_endpoint if you want the slashes.
    #
    # @return [Wgit::Url, nil] Path of self e.g. about.html or nil.
    def to_path
      path = @uri.path
      return nil if path.nil? or path.empty?
      return Wgit::Url.new('/') if path == '/'
      path = path[1..-1] if path.start_with?('/')
      path.chop! if path.end_with?('/')
      Wgit::Url.new(path)
    end

    # Returns the endpoint of this URL e.g. the bit after the host with any
    # slashes included. For example:
    # Wgit::Url.new("http://www.google.co.uk/about.html/").to_endpoint returns
    # "/about.html/". See Wgit::Url#to_path if you don't want the slashes.
    #
    # @return [Wgit::Url] Endpoint of self e.g. /about.html/. For a URL without
    #   an endpoint, / is returned.
    def to_endpoint
      endpoint = @uri.path
      endpoint = '/' + endpoint unless endpoint.start_with?('/')
      Wgit::Url.new(endpoint)
    end

    # Returns a new Wgit::Url containing just the query string of this URL
    # e.g. Given http://google.com?q=ruby, 'ruby' is returned.
    #
    # @return [Wgit::Url, nil] Containing just the query string or nil.
    def to_query_string
      query = @uri.query
      query ? Wgit::Url.new(query) : nil
    end

    # Returns a new Wgit::Url containing just the anchor string of this URL
    # e.g. Given http://google.com#about, #about is returned.
    #
    # @return [Wgit::Url, nil] Containing just the anchor string or nil.
    def to_anchor
      anchor = @uri.fragment
      anchor ? Wgit::Url.new("##{anchor}") : nil
    end

    # Returns a new Wgit::Url containing just the path + anchor string of this
    # URL e.g. Given http://google.com/us#about, us#about is returned.
    #
    # @return [Wgit::Url, nil] Containing just the path and anchor string or
    #   nil.
    def to_path_and_anchor
      path = to_path || ''
      anchor = to_anchor || ''
      both = path + anchor
      both.empty? ? nil : Wgit::Url.new(both)
    end

    # Returns a new Wgit::Url containing self without a trailing slash. Is
    # idempotent.
    #
    # @return [Wgit::Url] Without a trailing slash.
    def without_trailing_slash
      end_with?('/') ? Wgit::Url.new(chop) : self
    end

    # Returns a Hash containing this Url's instance vars excluding @uri.
    # Used when storing the URL in a Database e.g. MongoDB etc.
    #
    # @return [Hash] self's instance vars as a Hash.
    def to_h
      ignore = ["@uri"]
      h = Wgit::Utils.to_h(self, ignore)
      Hash[h.to_a.insert(0, ["url", self])] # Insert url at position 0.
    end

    alias :to_hash :to_h
    alias :uri :to_uri
    alias :url :to_url
    alias :scheme :to_scheme
    alias :to_protocol :to_scheme
    alias :protocol :to_scheme
    alias :host :to_host
    alias :base :to_base
    alias :path :to_path
    alias :endpoint :to_endpoint
    alias :query_string :to_query_string
    alias :query :to_query_string
    alias :anchor :to_anchor
    alias :to_fragment :to_anchor
    alias :fragment :to_anchor
    alias :internal_link? :relative_link?
    alias :is_relative? :relative_link?
    alias :is_internal? :relative_link?
    alias :crawled? :crawled
  end
end
