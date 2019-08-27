require_relative 'utils'
require_relative 'assertable'
require 'uri'
require 'addressable/uri'

module Wgit

  # Class modeling a web based URL.
  # Can be an internal/relative link e.g. "about.html" or a full URL
  # e.g. "http://www.google.co.uk". Is a subclass of String and uses
  # 'uri' and 'addressable/uri' internally.
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

      @uri = Addressable::URI.parse(url)
      @crawled = crawled
      @date_crawled = date_crawled

      super(url)
    end

    # A class alias for Url.new.
    #
    # @param str [String] The URL string to parse.
    # @return [Wgit::Url] The parsed Url object.
    def self.parse(str)
      self.new(str)
    end

    # Raises an exception if url is not a valid HTTP URL.
    #
    # @param url [Wgit::Url, String] The Url to validate.
    # @raise [RuntimeError] If url is invalid.
    def self.validate(url)
      url = Wgit::Url.new(url)
      if url.relative_link?
        raise "Invalid url (or a relative link): #{url}"
      end
      unless url.start_with?("http://") or url.start_with?("https://")
        raise "Invalid url (missing protocol prefix): #{url}"
      end
      if URI.regexp.match(url.normalise).nil?
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

    # Concats the host and link Strings and returns the result.
    #
    # @param host [Wgit::Url, String] The Url host.
    # @param link [Wgit::Url, String] The link to add to the host prefix.
    # @return [Wgit::Url] host + "/" + link
    def self.concat(host, link)
      host = Wgit::Url.new(host).without_trailing_slash
      link = Wgit::Url.new(link).without_leading_slash
      separator = (link.start_with?('#') or link.start_with?('?')) ? '' : '/'
      Wgit::Url.new(host + separator + link)
    end

    # Overrides String#replace setting the new_url @uri and String value.
    #
    # @param new_url [Wgit::Url, String] The new URL value.
    # @return [String] The new URL value once set.
    def replace(new_url)
      @uri = Addressable::URI.parse(new_url)
      super(new_url)
    end

    # Returns true if self is a relative Url.
    #
    # All external links in a page are expected to have a protocol prefix e.g.
    # "http://", otherwise the link is treated as an internal link (regardless
    # of whether it's valid or not). The only exception is if host or domain is
    # provided and self is a page belonging to that host/domain; then the link
    # is relative.
    #
    # @param host [Wgit::Url, String] The Url host e.g.
    #   http://www.google.com/how which gives a host of www.google.com.
    #   The host must be absolute and prefixed with a protocol.
    # @param domain [Wgit::Url, String] The Url domain e.g.
    #   http://www.google.com/how which gives a domain of google.com. The
    #   domain must be absolute and prefixed with a protocol.
    # @return [Boolean] True if relative, false if absolute.
    # @raise [RuntimeError] If self is invalid e.g. empty.
    def is_relative?(host: nil, domain: nil)
      raise "Invalid link: #{self}" if nil? or empty?
      raise "Provide host or domain, not both" if host and domain

      if host
        host = Wgit::Url.new(host)
        if host.to_base.nil?
          raise "Invalid host, must be absolute and contain protocol: #{host}"
        end
      end

      if domain
        domain = Wgit::Url.new(domain)
        if domain.to_base.nil?
          raise "Invalid domain, must be absolute and contain protocol: #{domain}"
        end
      end

      if @uri.relative?
        true
      else
        return host   ? to_host   == host.to_host     : false if host
        return domain ? to_domain == domain.to_domain : false if domain
      end
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

    # Normalises/escapes self and returns a new Wgit::Url.
    #
    # @return [Wgit::Url] An encoded version of self.
    def normalise
      Wgit::Url.new(@uri.normalize.to_s)
    end

    # Returns a normalised URI object for this URL.
    #
    # @return [URI::HTTP, URI::HTTPS] The URI object of self.
    def to_uri
      URI(normalise)
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

    # Returns a new Wgit::Url containing just the domain of this URL e.g.
    # Given http://www.google.co.uk/about.html, google.co.uk is returned.
    #
    # @return [Wgit::Url, nil] Containing just the domain or nil.
    def to_domain
      domain = @uri.domain
      domain ? Wgit::Url.new(domain) : nil
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
      Wgit::Url.new(path).without_slashes
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
    # e.g. Given http://google.com?q=ruby, '?q=ruby' is returned.
    #
    # @return [Wgit::Url, nil] Containing just the query string or nil.
    def to_query_string
      query = @uri.query
      query ? Wgit::Url.new("?#{query}") : nil
    end

    # Returns a new Wgit::Url containing just the anchor string of this URL
    # e.g. Given http://google.com#about, #about is returned.
    #
    # @return [Wgit::Url, nil] Containing just the anchor string or nil.
    def to_anchor
      anchor = @uri.fragment
      anchor ? Wgit::Url.new("##{anchor}") : nil
    end

    # Returns a new Wgit::Url containing just the file extension of this URL
    # e.g. Given http://google.com#about.html, html is returned.
    #
    # @return [Wgit::Url, nil] Containing just the extension string or nil.
    def to_extension
      path = to_path
      return nil unless path
      segs = path.split('.')
      segs.length > 1 ? Wgit::Url.new(segs.last) : nil
    end

    # Returns a new Wgit::Url containing self without a trailing slash. Is
    # idempotent meaning self will always be returned regardless of whether
    # there's a trailing slash or not.
    #
    # @return [Wgit::Url] Self without a trailing slash.
    def without_leading_slash
      start_with?('/') ? Wgit::Url.new(self[1..-1]) : self
    end

    # Returns a new Wgit::Url containing self without a trailing slash. Is
    # idempotent meaning self will always be returned regardless of whether
    # there's a trailing slash or not.
    #
    # @return [Wgit::Url] Self without a trailing slash.
    def without_trailing_slash
      end_with?('/') ? Wgit::Url.new(chop) : self
    end

    # Returns a new Wgit::Url containing self without a leading or trailing
    # slash. Is idempotent and will return self regardless if there's slashes
    # present or not.
    #
    # @return [Wgit::Url] Self without leading or trailing slashes.
    def without_slashes
      self.
        without_leading_slash.
        without_trailing_slash
    end

    # Returns a new Wgit::Url with the base (proto and host) removed e.g. Given
    # http://google.com/search?q=something#about, search?q=something#about is
    # returned. If relative and base isn't present then self is returned.
    # Leading and trailing slashes are always stripped from the return value.
    #
    # @return [Wgit::Url] Self containing everything after the base.
    def without_base
      base_url = to_base
      without_base = base_url ? gsub(base_url, '') : self

      return self if ['', '/'].include?(without_base)
      Wgit::Url.new(without_base).without_slashes
    end

    # Returns a new Wgit::Url with the query string portion removed e.g. Given
    # http://google.com/search?q=hello, http://google.com/search is
    # returned. Self is returned as is if no query string is present. A URL
    # consisting of only a query string e.g. '?q=hello' will return an empty
    # URL.
    #
    # @return [Wgit::Url] Self with the query string portion removed.
    def without_query_string
      query = to_query_string
      without_query_string = query ? gsub(query, '') : self

      Wgit::Url.new(without_query_string)
    end

    # Returns a new Wgit::Url with the anchor portion removed e.g. Given
    # http://google.com/search#about, http://google.com/search is
    # returned. Self is returned as is if no anchor is present. A URL
    # consisting of only an anchor e.g. '#about' will return an empty URL.
    # This method assumes that the anchor is correctly placed at the very end
    # of the URL.
    #
    # @return [Wgit::Url] Self with the anchor portion removed.
    def without_anchor
      anchor = to_anchor
      without_anchor = anchor ? gsub(anchor, '') : self

      Wgit::Url.new(without_anchor)
    end

    # Returns true if self is a URL query string e.g. ?q=hello etc.
    #
    # @return [Boolean] True if self is a query string, false otherwise.
    def is_query_string?
      start_with?('?')
    end

    # Returns true if self is a URL anchor/fragment e.g. #top etc.
    #
    # @return [Boolean] True if self is a anchor/fragment, false otherwise.
    def is_anchor?
      start_with?('#')
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

    alias :uri :to_uri
    alias :url :to_url
    alias :scheme :to_scheme
    alias :to_protocol :to_scheme
    alias :protocol :to_scheme
    alias :host :to_host
    alias :domain :to_domain
    alias :base :to_base
    alias :path :to_path
    alias :endpoint :to_endpoint
    alias :query_string :to_query_string
    alias :query :to_query_string
    alias :anchor :to_anchor
    alias :to_fragment :to_anchor
    alias :fragment :to_anchor
    alias :extension :to_extension
    alias :without_query :without_query_string
    alias :without_fragment :without_anchor
    alias :is_query? :is_query_string?
    alias :is_fragment? :is_anchor?
    alias :relative_link? :is_relative?
    alias :internal_link? :is_relative?
    alias :is_internal? :is_relative?
    alias :relative? :is_relative?
    alias :crawled? :crawled
    alias :normalize :normalise
  end
end
