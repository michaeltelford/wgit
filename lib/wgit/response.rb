module Wgit
  # Response class modeling a generic HTTP GET response.
  class Response
    # The underlying HTTP adapter/library response object.
    attr_accessor :adapter_response

    # The HTML response body.
    attr_reader   :body

    # The HTTP response headers.
    attr_reader   :headers

    # The servers IP address.
    attr_accessor :ip_address

    # The redirections of the response.
    attr_reader   :redirections

    # The HTTP response status code.
    attr_reader   :status

    # The total crawl/network time for the response.
    attr_reader   :total_time

    # The HTTP request URL.
    attr_accessor :url

    # Defaults some values and returns a "blank" Wgit::Response object.
    def initialize
      @body         = ''
      @headers      = {}
      @redirections = {}
      @total_time   = 0.0
    end

    # Overrides String#inspect to shorten the printed output of a Response.
    #
    # @return [String] A short textual representation of this Response.
    def inspect
      "#<Wgit::Response url=\"#{@url}\" status=#{status}>"
    end

    # Adds time to @total_time (incrementally).
    #
    # @param time [Float] The time to add to @total_time.
    # @return [Float] @total_time's new value.
    def add_total_time(time)
      @total_time += (time || 0.0)
    end

    # Sets the HTML response body.
    #
    # @param str [String] The new HTML body.
    # @return [String] @body's new value.
    def body=(str)
      @body = (str || '')
    end

    # Returns the HTML response body or nil (if it's empty).
    #
    # @return [String, NilClass] The HTML body or nil if empty.
    def body_or_nil
      @body.empty? ? nil : @body
    end

    # Returns whether or not a server response is absent.
    #
    # @return [Boolean] True if the status is nil or < 1, false otherwise.
    def failure?
      !success?
    end

    # Sets the headers Hash to the given value. The header keys are mapped
    # to snake_cased Symbols for consistency.
    #
    # @param headers [Hash] The new response headers.
    # @return [Hash] @headers's new value.
    def headers=(headers)
      unless headers
        @headers = {}
        return
      end

      @headers = headers.map do |k, v|
        k = k.downcase.gsub('-', '_').to_sym
        [k, v]
      end.to_h
    end

    # Returns whether or not the response is 404 Not Found.
    #
    # @return [Boolean] True if 404 Not Found, false otherwise.
    def not_found?
      @status == 404
    end

    # Returns whether or not the response is 200 OK.
    #
    # @return [Boolean] True if 200 OK, false otherwise.
    def ok?
      @status == 200
    end

    # Returns whether or not the response is a 3xx Redirect.
    #
    # @return [Boolean] True if 3xx Redirect, false otherwise.
    def redirect?
      return false unless @status

      @status.between?(300, 399)
    end

    # Returns the number of redirects this response has had.
    #
    # @return [Integer] The number of response redirects.
    def redirect_count
      @redirections.size
    end

    # Returns the size of the response body.
    #
    # @return [Integer] The response body size in bytes.
    def size
      @body.size
    end

    # Sets the HTML response status.
    #
    # @param int [Integer] The new response status.
    # @return [Integer] @status' new value.
    def status=(int)
      @status = int.positive? ? int : nil
    end

    # Returns whether or not a server response is present.
    #
    # @return [Boolean] True if the status is > 0, false otherwise.
    def success?
      return false unless @status

      @status.positive?
    end

    # Returns whether or not Wgit is banned from indexing this site.
    #
    # @return [Boolean] True if Wgit should not index this site, false
    #   otherwise.
    def no_index?
      headers.fetch(:x_robots_tag, '').downcase.strip == 'noindex'
    end

    alias code           status
    alias content        body
    alias crawl_duration total_time
    alias to_s           body
    alias redirects      redirections
    alias length         size
  end
end
