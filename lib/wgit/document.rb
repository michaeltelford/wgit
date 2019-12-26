require_relative 'url'
require_relative 'utils'
require_relative 'assertable'
require 'nokogiri'
require 'json'

module Wgit
  # Class primarily modeling a HTML web document, although other MIME types
  # will work e.g. images etc. Also doubles as a search result when
  # loading Documents from the database via `Wgit::Database#search`.
  #
  # The initialize method dynamically initializes instance variables from the
  # Document HTML / Database object e.g. text. This bit is dynamic so that the
  # Document class can be easily extended allowing you to pull out the bits of
  # a webpage that are important to you. See `Wgit::Document.define_extension`.
  class Document
    include Assertable

    # Regex for the allowed var names when defining an extension.
    REGEX_EXTENSION_NAME = /[a-z0-9_]+/.freeze

    # The xpath used to extract the visible text on a page.
    TEXT_ELEMENTS_XPATH = '//*/text()'.freeze

    # The URL of the webpage, an instance of Wgit::Url.
    attr_reader :url

    # The content/HTML of the document, an instance of String.
    attr_reader :html

    # The Nokogiri::HTML document object initialized from @html.
    attr_reader :doc

    # The score is only used following a `Database#search` and records matches.
    attr_reader :score

    # Initialize takes either two strings (representing the URL and HTML) or an
    # object representing a database record (of a HTTP crawled web page). This
    # allows for initialisation from both crawled web pages and documents/web
    # pages retrieved from the database.
    #
    # During initialisation, the Document will call any private
    # `init_*_from_html` and `init_*_from_object` methods it can find. See the
    # README.md and Wgit::Document.define_extension method for more details.
    #
    # @param url_or_obj [String, Wgit::Url, #fetch] Either a String
    #   representing a URL or a Hash-like object responding to :fetch. e.g. a
    #   MongoDB collection object. The Object's :fetch method should support
    #   Strings as keys.
    # @param html [String, NilClass] The crawled web page's content/HTML. This
    #   param is only used if url_or_obj is a String representing the web
    #   page's URL. Otherwise, the HTML comes from the database object. A html
    #   of nil will be defaulted to an empty String.
    # @param encode [Boolean] Whether or not to UTF-8 encode the html. Set to
    #   false if the Document content is an image etc.
    def initialize(url_or_obj, html = '', encode: true)
      if url_or_obj.is_a?(String)
        init_from_strings(url_or_obj, html, encode: encode)
      else
        init_from_object(url_or_obj, encode: encode)
      end
    end

    ### Document Class Methods ###

    # Defines an extension, which is a way to serialise HTML elements into
    # instance variables upon Document initialization. See the default
    # extensions defined in 'document_extensions.rb' as examples.
    #
    # Note that defined extensions work for both Documents initialized from
    # HTML (via Wgit::Crawler methods) and from database objects.
    # An extension once defined, initializes a private instance variable with
    # the xpath or database object result(s).
    #
    # When initialising from HTML, a singleton value of true will only
    # ever return one result; otherwise all xpath results are returned in an
    # Array. When initialising from a database object, the value is taken as
    # is and singleton is only used to define the default empty value.
    # If a value cannot be found (in either the HTML or database object), then
    # a default will be used. The default value is: `singleton ? nil : []`.
    #
    # @param var [Symbol] The name of the variable to be initialised.
    # @param xpath [String, #call] The xpath used to find the element(s)
    #   of the webpage. Only used when initializing from HTML.
    #
    #   Pass a callable object (proc etc.) if you want the
    #   xpath value to be derived on Document initialisation (instead of when
    #   the extension is defined). The call method must return a valid xpath
    #   String.
    # @param opts [Hash] The options to define an extension with. The
    #   options are only used when intializing from HTML, not the database.
    # @option opts [Boolean] :singleton The singleton option determines
    #   whether or not the result(s) should be in an Array. If multiple
    #   results are found and singleton is true then the first result will be
    #   used. Defaults to true.
    # @option opts [Boolean] :text_content_only The text_content_only option
    #   if true will use the text content of the Nokogiri result object,
    #   otherwise the Nokogiri object itself is returned. Defaults to true.
    # @yieldparam value [Object] The value to be assigned to the new var.
    # @yieldparam source [Wgit::Document, Object] The source of the value.
    # @yieldparam type [Symbol] The source type, either :document or (DB)
    #   :object.
    # @yieldreturn [Object] The return value of the block becomes the new var
    #   value, unless nil. Return nil if you want to inspect but not change the
    #   var value. The block is executed when a Wgit::Document is initialized,
    #   regardless of the source.
    # @raise [StandardError] If the var param isn't valid.
    # @return [Symbol] The given var Symbol if successful.
    def self.define_extension(var, xpath, opts = {}, &block)
      var = var.to_sym
      defaults = { singleton: true, text_content_only: true }
      opts = defaults.merge(opts)

      raise "var must match #{REGEX_EXTENSION_NAME}" unless \
      var =~ REGEX_EXTENSION_NAME

      # Define the private init_*_from_html method for HTML.
      # Gets the HTML's xpath value and creates a var for it.
      func_name = Document.send(:define_method, "init_#{var}_from_html") do
        result = find_in_html(xpath, opts, &block)
        init_var(var, result)
      end
      Document.send :private, func_name

      # Define the private init_*_from_object method for a Database object.
      # Gets the Object's 'key' value and creates a var for it.
      func_name = Document.send(:define_method, "init_#{var}_from_object") do |obj|
        result = find_in_object(obj, var.to_s, singleton: opts[:singleton], &block)
        init_var(var, result)
      end
      Document.send :private, func_name

      var
    end

    # Removes the init_* methods created when an extension is defined.
    # Therefore, this is the opposing method to Document.define_extension.
    # Returns true if successful or false if the method(s) cannot be found.
    #
    # @param var [Symbol] The extension variable already defined.
    # @return [Boolean] True if the extension var was found and removed;
    #   otherwise false.
    def self.remove_extension(var)
      Document.send(:remove_method, "init_#{var}_from_html")
      Document.send(:remove_method, "init_#{var}_from_object")

      true
    rescue NameError
      false
    end

    ### Document Instance Methods ###

    # Determines if both the url and html match. Use
    # doc.object_id == other.object_id for exact object comparison.
    #
    # @param other [Wgit::Document] To compare self against.
    # @return [Boolean] True if @url and @html are equal, false if not.
    def ==(other)
      return false unless other.is_a?(Wgit::Document)

      (@url == other.url) && (@html == other.html)
    end

    # Is a shortcut for calling Document#html[range].
    #
    # @param range [Range] The range of @html to return.
    # @return [String] The given range of @html.
    def [](range)
      @html[range]
    end

    # Returns the base URL of this Wgit::Document. The base URL is either the
    # <base> element's href value or @url (if @base is nil). If @base is
    # present and relative, then @url.to_base + @base is returned. This method
    # should be used instead of `doc.url.to_base` etc. when manually building
    # absolute links from relative links; or use `link.prefix_base(doc)`.
    #
    # Provide the `link:` parameter to get the correct base URL for that type
    # of link. For example, a link of `#top` would always return @url because
    # it applies to that page, not a different one. Query strings work in the
    # same way. Use this parameter if manually concatting Url's e.g.
    #
    #   relative_link = Wgit::Url.new('?q=hello')
    #   absolute_link = doc.base_url(link: relative_link).concat(relative_link)
    #
    # This is similar to how Wgit::Document#internal_absolute_links works.
    #
    # @param link [Wgit::Url, String] The link to obtain the correct base URL
    #   for; must be relative, not absolute.
    # @raise [StandardError] If link is relative or if a base URL can't be
    #   established e.g. the doc @url is relative and <base> is nil.
    # @return [Wgit::Url] The base URL of this Document e.g.
    #   'http://example.com/public'.
    def base_url(link: nil)
      raise "Document @url ('#{@url}') cannot be relative if <base> is nil" \
      if @url.relative? && @base.nil?
      raise "Document @url ('#{@url}') and <base> ('#{@base}') both can't be relative" \
      if @url.relative? && @base&.relative?

      get_base = -> { @base.relative? ? @url.to_base.concat(@base) : @base }

      if link
        link = Wgit::Url.new(link)
        raise "link must be relative: #{link}" unless link.relative?

        if link.is_fragment? || link.is_query?
          base_url = @base ? get_base.call : @url
          return base_url.omit_fragment.omit_query
        end
      end

      base_url = @base ? get_base.call : @url.to_base
      base_url.omit_fragment.omit_query
    end

    # Returns a Hash containing this Document's instance vars.
    # Used when storing the Document in a Database e.g. MongoDB etc.
    # By default the @html var is excluded from the returned Hash.
    #
    # @param include_html [Boolean] Whether or not to include @html in the
    #   returned Hash.
    # @return [Hash] Containing self's instance vars.
    def to_h(include_html: false, include_score: true)
      ignore = include_html ? [] : ['@html']
      ignore << '@score' unless include_score
      ignore << '@doc' # Always ignore Nokogiri @doc.

      Wgit::Utils.to_h(self, ignore: ignore)
    end

    # Converts this Document's #to_h return value to a JSON String.
    #
    # @param include_html [Boolean] Whether or not to include @html in the
    #   returned JSON String.
    # @return [String] This Document represented as a JSON String.
    def to_json(include_html: false)
      h = to_h(include_html: include_html)
      JSON.generate(h)
    end

    # Returns a Hash containing this Document's instance variables and
    # their #length (if they respond to it). Works dynamically so that any
    # user defined extensions (and their created instance vars) will appear in
    # the returned Hash as well. The number of text snippets as well as total
    # number of textual bytes are always included in the returned Hash.
    #
    # @return [Hash] Containing self's HTML page statistics.
    def stats
      hash = {}
      instance_variables.each do |var|
        # Add up the total bytes of text as well as the length.
        if var == :@text
          hash[:text_snippets] = @text.length
          hash[:text_bytes]    = @text.sum(&:length)
        # Else take the var's #length method return value.
        else
          next unless instance_variable_get(var).respond_to?(:length)

          hash[var[1..-1].to_sym] = instance_variable_get(var).send(:length)
        end
      end

      hash
    end

    # Determine the size of this Document's HTML.
    #
    # @return [Integer] The total number of @html bytes.
    def size
      stats[:html]
    end

    # Determine if this Document's HTML is empty or not.
    #
    # @return [Boolean] True if @html is nil/empty, false otherwise.
    def empty?
      return true if @html.nil?

      @html.empty?
    end

    # Uses Nokogiri's xpath method to search the doc's html and return the
    # results.
    #
    # @param xpath [String] The xpath to search the @html with.
    # @return [Nokogiri::XML::NodeSet] The result set of the xpath search.
    def xpath(xpath)
      @doc.xpath(xpath)
    end

    # Uses Nokogiri's css method to search the doc's html and return the
    # results.
    #
    # @param selector [String] The CSS selector to search the @html with.
    # @return [Nokogiri::XML::NodeSet] The result set of the CSS search.
    def css(selector)
      @doc.css(selector)
    end

    # Returns all internal links from this Document in relative form. Internal
    # meaning a link to another document on the same host.
    #
    # This Document's host is used to determine if an absolute URL is actually
    # a relative link e.g. For a Document representing
    # http://www.server.com/about, an absolute link of
    # <a href='http://www.server.com/search'> will be recognized and returned
    # as an internal link because both Documents live on the same host. Also
    # see Wgit::Document#internal_absolute_links.
    #
    # @return [Array<Wgit::Url>] Self's internal Url's in relative form.
    def internal_links
      return [] if @links.empty?

      links = @links
              .select { |link| link.relative?(host: @url.to_base) }
              .map(&:omit_base)
              .map do |link| # Map @url.to_host into / as it's a duplicate.
        link.to_host == @url.to_host ? Wgit::Url.new('/') : link
      end

      Wgit::Utils.process_arr(links)
    end

    # Returns all internal links from this Document in absolute form by
    # appending them to self's #base_url. Also see
    # Wgit::Document#internal_links.
    #
    # @return [Array<Wgit::Url>] Self's internal Url's in absolute form.
    def internal_absolute_links
      internal_links.map { |link| link.prefix_base(self) }
    end

    # Returns all external links from this Document in absolute form. External
    # meaning a link to a different host.
    #
    # @return [Array<Wgit::Url>] Self's external Url's in absolute form.
    def external_links
      return [] if @links.empty?

      links = @links
              .reject { |link| link.relative?(host: @url.to_base) }
              .map(&:omit_trailing_slash)

      Wgit::Utils.process_arr(links)
    end

    # Searches the @text for the given query and returns the results.
    #
    # The number of search hits for each sentenence are recorded internally
    # and used to rank/sort the search results before being returned. Where
    # the Wgit::Database#search method search all documents for the most hits,
    # this method searches each document's @text for the most hits.
    #
    # Each search result comprises of a sentence of a given length. The length
    # will be based on the sentence_limit parameter or the full length of the
    # original sentence, which ever is less. The algorithm obviously ensures
    # that the search query is visible somewhere in the sentence.
    #
    # @param query [String, #to_s] The value to search the document's
    #   @text for.
    # @param case_sensitive [Boolean] Whether character case must match.
    # @param whole_sentence [Boolean] Whether multiple words should be searched
    #   for separately.
    # @param sentence_limit [Integer] The max length of each search result
    #   sentence.
    # @return [Array<String>] A subset of @text, matching the query.
    def search(
      query, case_sensitive: false, whole_sentence: true, sentence_limit: 80
    )
      query = query.to_s
      raise 'A search query must be provided' if query.empty?
      raise 'The sentence_limit value must be even' if sentence_limit.odd?

      query   = query.gsub(' ', '|') unless whole_sentence
      regex   = Regexp.new(query, !case_sensitive)
      results = {}

      @text.each do |sentence|
        sentence = sentence.strip
        next if results[sentence]

        hits = sentence.scan(regex).count
        next unless hits.positive?

        index = sentence.index(regex) # Index of first match.
        Wgit::Utils.format_sentence_length(sentence, index, sentence_limit)

        results[sentence] = hits
      end

      return [] if results.empty?

      results = Hash[results.sort_by { |_k, v| v }]
      results.keys.reverse
    end

    # Performs a text search (see Document#search for details) but assigns the
    # results to the @text instance variable. This can be used for sub search
    # functionality. The original text is returned; no other reference to it
    # is kept thereafter.
    #
    # @param query [String, #to_s] The value to search the document's
    #   @text for.
    # @param case_sensitive [Boolean] Whether character case must match.
    # @param whole_sentence [Boolean] Whether multiple words should be searched
    #   for separately.
    # @param sentence_limit [Integer] The max length of each search result
    #   sentence.
    # @return [String] This Document's original @text value.
    def search!(
      query, case_sensitive: false, whole_sentence: true, sentence_limit: 80
    )
      orig_text = @text
      @text = search(
        query, case_sensitive: case_sensitive,
               whole_sentence: whole_sentence, sentence_limit: sentence_limit
      )

      orig_text
    end

    protected

    # Initializes the nokogiri object using @html, which cannot be nil.
    # Override this method to custom configure the Nokogiri object returned.
    # Gets called from Wgit::Document.new upon initialization.
    #
    # @raise [StandardError] If @html isn't set.
    # @return [Nokogiri::HTML] The initialised Nokogiri HTML object.
    def init_nokogiri
      raise '@html must be set' unless @html

      Nokogiri::HTML(@html) do |config|
        # TODO: Remove #'s below when crawling in production.
        # config.options = Nokogiri::XML::ParseOptions::STRICT |
        #                 Nokogiri::XML::ParseOptions::NONET
      end
    end

    # Returns a value/object from this Document's @html using the given xpath
    # parameter.
    #
    # @param xpath [String] Used to find the value/object in @html.
    # @param singleton [Boolean] singleton ? results.first (single Nokogiri
    #   Object) : results (Array).
    # @param text_content_only [Boolean] text_content_only ? result.content
    #   (String) : result (Nokogiri Object).
    # @yield [value, source] Given the value (String/Object) before it's set as
    #   an instance variable so that you can inspect/alter the value if
    #   desired. Return nil from the block if you don't want to override the
    #   value. Also given the source (Symbol) which is always :document.
    # @return [String, Object] The value found in the html or the default value
    #   (singleton ? nil : []).
    def find_in_html(xpath, singleton: true, text_content_only: true)
      default = singleton ? nil : []
      xpath   = xpath.call if xpath.respond_to?(:call)
      results = @doc.xpath(xpath)

      return default if results.nil? || results.empty?

      result = if singleton
                 text_content_only ? results.first.content : results.first
               else
                 text_content_only ? results.map(&:content) : results
               end

      singleton ? Wgit::Utils.process_str(result) : Wgit::Utils.process_arr(result)

      if block_given?
        new_result = yield(result, self, :document)
        result = new_result unless new_result.nil?
      end

      result
    end

    # Returns a value from the obj using the given key via obj#fetch.
    #
    # @param obj [#fetch] The object containing the key/value.
    # @param key [String] Used to find the value in the obj.
    # @param singleton [Boolean] True if a single value, false otherwise.
    # @yield [value, source] Given the value (String/Object) before it's set as
    #   an instance variable so that you can inspect/alter the value if
    #   desired. Return nil from the block if you don't want to override the
    #   value. Also given the source (Symbol) which is always :object.
    # @return [String, Object] The value found in the obj or the default value
    #   (singleton ? nil : []).
    def find_in_object(obj, key, singleton: true)
      assert_respond_to(obj, :fetch)

      default = singleton ? nil : []
      result  = obj.fetch(key.to_s, default)

      singleton ? Wgit::Utils.process_str(result) : Wgit::Utils.process_arr(result)

      if block_given?
        new_result = yield(result, obj, :object)
        result = new_result unless new_result.nil?
      end

      result
    end

    private

    # Initialise the Document from URL and HTML Strings.
    def init_from_strings(url, html, encode: true)
      assert_types(html, [String, NilClass])

      # We already know url.is_a?(String) so parse into Url unless already so.
      url = Wgit::Url.parse(url)
      url.crawled = true unless url.crawled? # Avoid overriding date_crawled.

      @url   = url
      @html  = html || ''
      @doc   = init_nokogiri
      @score = 0.0

      Wgit::Utils.process_str(@html, encode: encode)

      # Dynamically run the init_*_from_html methods.
      Document.private_instance_methods(false).each do |method|
        if method.to_s.start_with?('init_') &&
           method.to_s.end_with?('_from_html')
          send(method) unless method == __method__
        end
      end
    end

    # Initialise the Document from a Hash like Object containing Strings as
    # keys e.g. database collection object or Hash.
    def init_from_object(obj, encode: true)
      assert_respond_to(obj, :fetch)

      @url   = Wgit::Url.new(obj.fetch('url')) # Should always be present.
      @html  = obj.fetch('html', '')
      @doc   = init_nokogiri
      @score = obj.fetch('score', 0.0)

      Wgit::Utils.process_str(@html, encode: encode)

      # Dynamically run the init_*_from_object methods.
      Document.private_instance_methods(false).each do |method|
        if method.to_s.start_with?('init_') &&
           method.to_s.end_with?('_from_object')
          send(method, obj) unless method == __method__
        end
      end
    end

    # Initialises an instance variable and defines a getter method for it.
    #
    # @param var [Symbol] The name of the variable to be initialized.
    # @param value [Object] The newly initialized variable's value.
    # @return [Symbol] The name of the newly created getter method.
    def init_var(var, value)
      # instance_var_name starts with @, var_name doesn't.
      var = var.to_s
      var_name = (var.start_with?('@') ? var[1..-1] : var).to_sym
      instance_var_name = "@#{var_name}".to_sym

      instance_variable_set(instance_var_name, value)

      Document.send(:define_method, var_name) do
        instance_variable_get(instance_var_name)
      end
    end

    alias content                html
    alias statistics             stats
    alias internal_urls          internal_links
    alias internal_absolute_urls internal_absolute_links
    alias external_urls          external_links
  end
end
