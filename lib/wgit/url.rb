# frozen_string_literal: true

require_relative 'utils'
require_relative 'assertable'
require 'uri'
require 'addressable/uri'

module Wgit
  # Class modeling a web based HTTP URL.
  #
  # Can be an internal/relative link e.g. "about.html" or a full URL
  # e.g. "http://www.google.co.uk". Is a subclass of String and uses 'uri' and
  # 'addressable/uri' internally.
  class Url < String
    include Assertable

    # Whether or not the Url has been crawled or not. A custom crawled= method
    # is provided by this class, overridding the default one.
    attr_accessor :crawled

    # The Time stamp of when this Url was crawled.
    attr_accessor :date_crawled

    # The duration of the crawl for this Url (in seconds).
    attr_accessor :crawl_duration

    # Initializes a new instance of Wgit::Url which represents a web based
    # HTTP URL.
    #
    # @param url_or_obj [String, Wgit::Url, Object#fetch#[]] Is either a String
    #   based URL or an object representing a Database record e.g. a MongoDB
    #   document/object.
    # @param crawled [Boolean] Whether or not the HTML of the URL's web page
    #   has been crawled or not. Only used if url_or_obj is a String.
    # @param date_crawled [Time] Should only be provided if crawled is true. A
    #   suitable object can be returned from Wgit::Utils.time_stamp. Only used
    #   if url_or_obj is a String.
    # @param crawl_duration [Float] Should only be provided if crawled is true.
    #   The duration of the crawl for this Url (in seconds).
    # @raise [StandardError] If url_or_obj is an Object with missing methods.
    def initialize(
      url_or_obj, crawled: false, date_crawled: nil, crawl_duration: nil
    )
      # Init from a URL String.
      if url_or_obj.is_a?(String)
        url = url_or_obj.to_s
      # Else init from a Hash like object e.g. database object.
      else
        obj = url_or_obj
        assert_respond_to(obj, :fetch)

        url            = obj.fetch('url') # Should always be present.
        crawled        = obj.fetch('crawled', false)
        date_crawled   = obj.fetch('date_crawled', nil)
        crawl_duration = obj.fetch('crawl_duration', nil)
      end

      @uri            = Addressable::URI.parse(url)
      @crawled        = crawled
      @date_crawled   = date_crawled
      @crawl_duration = crawl_duration

      super(url)
    end

    # Initialises a new Wgit::Url instance from a String or subclass of String
    # e.g. Wgit::Url. Any other obj type will raise an error.
    #
    # If obj is already a Wgit::Url then it will be returned as is to maintain
    # it's state. Otherwise, a new Wgit::Url is instantiated and returned. This
    # differs from Wgit::Url.new which always instantiates a new Wgit::Url.
    #
    # Note: Only use this method if you are allowing obj to be either a String
    # or a Wgit::Url whose state you want to preserve e.g. when passing a URL
    # to a crawl method which might redirect (calling Wgit::Url#replace). If
    # you're sure of the type or don't care about preserving the state of the
    # Wgit::Url, use Wgit::Url.new instead.
    #
    # @param obj [Object] The object to parse, which #is_a?(String).
    # @raise [StandardError] If obj.is_a?(String) is false.
    # @return [Wgit::Url] A Wgit::Url instance.
    def self.parse(obj)
      raise 'Can only parse if obj#is_a?(String)' unless obj.is_a?(String)

      # Return a Wgit::Url as is to avoid losing state e.g. date_crawled etc.
      obj.is_a?(Wgit::Url) ? obj : new(obj)
    end

    # Sets the @crawled instance var, also setting @date_crawled for
    # convenience.
    #
    # @param bool [Boolean] True if this Url has been crawled, false otherwise.
    # @return [Boolean] The value of bool having been set.
    def crawled=(bool)
      @crawled      = bool
      @date_crawled = bool ? Wgit::Utils.time_stamp : nil

      bool
    end

    # Overrides String#replace setting the new_url @uri and String value.
    #
    # @param new_url [Wgit::Url, String] The new URL value.
    # @return [String] The new URL value once set.
    def replace(new_url)
      @uri = Addressable::URI.parse(new_url)

      super(new_url)
    end

    # Returns true if self is a relative Url; false if absolute.
    #
    # All external links in a page are expected to have a protocol prefix e.g.
    # 'http://', otherwise the link is treated as an internal link (regardless
    # of whether it's valid or not). The only exception is if an opts arg is
    # provided and self is a page belonging to that arg type e.g. host; then
    # the link is relative.
    #
    # @param opts [Hash] The options with which to check relativity. Only one
    #   opts param should be provided. The provided opts param Url must be
    #   absolute and be prefixed with a protocol. Consider using the output of
    #   Wgit::Url#to_base which should work unless it's nil.
    # @option opts [Wgit::Url, String] :base The Url base e.g.
    #   http://www.google.com/how which gives a base of
    #   'http://www.google.com'.
    # @option opts [Wgit::Url, String] :host The Url host e.g.
    #   http://www.google.com/how which gives a host of 'www.google.com'.
    # @option opts [Wgit::Url, String] :domain The Url domain e.g.
    #   http://www.google.com/how which gives a domain of 'google.com'.
    # @option opts [Wgit::Url, String] :brand The Url brand e.g.
    #   http://www.google.com/how which gives a domain of 'google'.
    # @raise [StandardError] If self is invalid e.g. empty or an invalid opts
    #   param has been provided.
    # @return [Boolean] True if relative, false if absolute.
    def relative?(opts = {})
      defaults = { base: nil, host: nil, domain: nil, brand: nil }
      opts = defaults.merge(opts)
      raise 'Url (self) cannot be empty' if empty?

      return true if @uri.relative?

      # Self is absolute but may be relative to the opts param e.g. host.
      opts.select! { |_k, v| v }
      raise "Provide only one of: #{defaults.keys}" if opts.length > 1

      return false if opts.empty?

      type, url = opts.first
      url = Wgit::Url.new(url)
      raise "Invalid opts param value, Url must be absolute and contain \
protocol: #{url}" unless url.to_base

      case type
      when :base   # http://www.google.com
        to_base   == url.to_base
      when :host   # www.google.com
        to_host   == url.to_host
      when :domain # google.com
        to_domain == url.to_domain
      when :brand  # google
        to_brand  == url.to_brand
      else
        raise "Unknown opts param: :#{type}, use one of: #{defaults.keys}"
      end
    end

    # Returns true if self is an absolute Url; false if relative.
    #
    # @return [Boolean] True if absolute, false if relative.
    def absolute?
      @uri.absolute?
    end

    # Returns if self is a valid and absolute HTTP Url or not.
    #
    # @return [Boolean] True if valid and absolute, otherwise false.
    def valid?
      return false if relative?
      return false unless start_with?('http://') || start_with?('https://')
      return false if URI::DEFAULT_PARSER.make_regexp.match(normalize).nil?

      true
    end

    # Concats self and path together before returning a new Url. Self is not
    # modified.
    #
    # @param path [Wgit::Url, String] The path to concat onto the end of self.
    # @return [Wgit::Url] self + separator + path, separator depends on path.
    def concat(path)
      path = Wgit::Url.new(path)
      raise 'path must be relative' unless path.relative?

      path = path.without_leading_slash
      separator = path.start_with?('#') || path.start_with?('?') ? '' : '/'

      Wgit::Url.new(without_trailing_slash + separator + path)
    end

    # Normalises/escapes self and returns a new Wgit::Url. Self isn't modified.
    #
    # @return [Wgit::Url] An escaped version of self.
    def normalize
      Wgit::Url.new(@uri.normalize.to_s)
    end

    # Returns an absolute form of self within the context of doc. Doesn't
    # modify the receiver.
    #
    # If self is absolute then it's returned as is, making this method
    # idempotent. The doc's <base> element is used if present, otherwise
    # doc.url is used as the base; which is concatted with self.
    #
    # Typically used to build an absolute link obtained from a document e.g.
    #
    #   link = Wgit::Url.new('/favicon.png')
    #   doc  = Wgit::Document.new('http://example.com')
    #
    #   link.prefix_base(doc) # => "http://example.com/favicon.png"
    #
    # @param doc [Wgit::Document] The doc whose base Url is concatted with
    #   self.
    # @raise [StandardError] If doc isn't a Wgit::Document.
    # @return [Wgit::Url] Self in absolute form.
    def prefix_base(doc)
      assert_type(doc, Wgit::Document)

      absolute? ? self : doc.base_url(link: self).concat(self)
    end

    # Returns self having prefixed a protocol. Doesn't modify the receiver.
    # Returns self even if absolute (with protocol); therefore is idempotent.
    #
    # @param protocol [Symbol] Either :http or :https.
    # @return [Wgit::Url] Self with a protocol prefix.
    def prefix_protocol(protocol: :http)
      return self if absolute?

      case protocol
      when :http
        Wgit::Url.new("http://#{url}")
      when :https
        Wgit::Url.new("https://#{url}")
      else
        raise "protocol must be :http or :https, not :#{protocol}"
      end
    end

    # Returns a Hash containing this Url's instance vars excluding @uri.
    # Used when storing the URL in a Database e.g. MongoDB etc.
    #
    # @return [Hash] self's instance vars as a Hash.
    def to_h
      ignore = ['@uri']
      h = Wgit::Utils.to_h(self, ignore: ignore)
      Hash[h.to_a.insert(0, ['url', self])] # Insert url at position 0.
    end

    # Returns a normalised URI object for this URL.
    #
    # @return [URI::HTTP, URI::HTTPS] The URI object of self.
    def to_uri
      URI(normalize)
    end

    # Returns the Addressable::URI object for this URL.
    #
    # @return [Addressable::URI] The Addressable::URI object of self.
    def to_addressable_uri
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

    # Returns a new Wgit::Url containing just the domain of this URL e.g.
    # Given http://www.google.co.uk/about.html, google.co.uk is returned.
    #
    # @return [Wgit::Url, nil] Containing just the domain or nil.
    def to_domain
      domain = @uri.domain
      domain ? Wgit::Url.new(domain) : nil
    end

    # Returns a new Wgit::Url containing just the brand of this URL e.g.
    # Given http://www.google.co.uk/about.html, google is returned.
    #
    # @return [Wgit::Url, nil] Containing just the brand or nil.
    def to_brand
      domain = to_domain
      domain ? Wgit::Url.new(domain.split('.').first) : nil
    end

    # Returns only the base of this URL e.g. the protocol and host combined.
    #
    # @return [Wgit::Url, nil] Base of self e.g. http://www.google.co.uk or nil.
    def to_base
      return nil if @uri.scheme.nil? || @uri.host.nil?

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
      return nil if path.nil? || path.empty?
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
    def to_query
      query = @uri.query
      query ? Wgit::Url.new(query) : nil
    end

    # Returns a new Wgit::Url containing just the fragment string of this URL
    # e.g. Given http://google.com#about, #about is returned.
    #
    # @return [Wgit::Url, nil] Containing just the fragment string or nil.
    def to_fragment
      fragment = @uri.fragment
      fragment ? Wgit::Url.new(fragment) : nil
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
      without_leading_slash
      .without_trailing_slash
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
    def without_query
      query = to_query
      without_query_string = query ? gsub("?#{query}", '') : self

      Wgit::Url.new(without_query_string)
    end

    # Returns a new Wgit::Url with the fragment portion removed e.g. Given
    # http://google.com/search#about, http://google.com/search is
    # returned. Self is returned as is if no fragment is present. A URL
    # consisting of only a fragment e.g. '#about' will return an empty URL.
    # This method assumes that the fragment is correctly placed at the very end
    # of the URL.
    #
    # @return [Wgit::Url] Self with the fragment portion removed.
    def without_fragment
      fragment = to_fragment
      without_fragment = fragment ? gsub("##{fragment}", '') : self

      Wgit::Url.new(without_fragment)
    end

    # Returns true if self is a URL query string e.g. ?q=hello etc. Note this
    # shouldn't be used to determine if self contains a query.
    #
    # @return [Boolean] True if self is a query string, false otherwise.
    def query?
      start_with?('?')
    end

    # Returns true if self is a URL fragment e.g. #top etc. Note this
    # shouldn't be used to determine if self contains a fragment.
    #
    # @return [Boolean] True if self is a fragment, false otherwise.
    def fragment?
      start_with?('#')
    end

    alias crawled?     crawled
    alias is_relative? relative?
    alias is_absolute? absolute?
    alias is_valid?    valid?
    alias is_query?    query?
    alias is_fragment? fragment?
    alias normalise    normalize
    alias uri          to_uri
    alias url          to_url
    alias scheme       to_scheme
    alias host         to_host
    alias domain       to_domain
    alias brand        to_brand
    alias base         to_base
    alias path         to_path
    alias endpoint     to_endpoint
    alias query        to_query
    alias fragment     to_fragment
    alias extension    to_extension
  end
end
