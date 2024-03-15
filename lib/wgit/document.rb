require_relative 'url'
require_relative 'utils'
require_relative 'assertable'
require 'nokogiri'
require 'json'

module Wgit
  # Class modeling/serialising a HTML web document, although other MIME types
  # will work e.g. images etc. Also doubles as a search result when
  # loading Documents from the database via
  # `Wgit::Database::DatabaseAdapter#search`.
  #
  # The initialize method dynamically initializes instance variables from the
  # Document HTML / Database object e.g. text. This bit is dynamic so that the
  # Document class can be easily extended allowing you to extract the bits of
  # a webpage that are important to you. See `Wgit::Document.define_extractor`.
  class Document
    include Assertable

    # Regex for the allowed var names when defining an extractor.
    REGEX_EXTRACTOR_NAME = /[a-z0-9_]+/

    # Set of text elements used to build the xpath for Document#text.
    @text_elements = Set.new(%i[
      a abbr address article aside b bdi bdo blockquote button caption cite
      code data dd del details dfn div dl dt em figcaption figure footer h1 h2
      h3 h4 h5 h6 header hr i input ins kbd label legend li main mark meter ol
      option output p pre q rb rt ruby s samp section small span strong sub
      summary sup td textarea th time u ul var wbr
    ])

    # Instance vars to be ignored by Document#to_h and in turn Model.document.
    @to_h_ignore_vars = [
      '@parser' # Always ignore the Nokogiri object.
    ]

    # Set of Symbols representing the defined Document extractors.
    @extractors = Set.new

    class << self
      # Set of HTML elements that make up the visible text on a page. These
      # elements are used to initialize the Wgit::Document#text. See the
      # README.md for how to add to this Set dynamically.
      attr_reader :text_elements

      # Array of instance vars to ignore when Document#to_h and in turn
      # Model.document methods are called. Append your own defined extractor
      # vars to omit them from the model (database object) when indexing.
      # Each var should be a String starting with an '@' char e.g. "@data" etc.
      attr_reader :to_h_ignore_vars

      # Set of Symbols representing the defined Document extractors. Is
      # read-only. Use Wgit::Document.define_extractor for a new extractor.
      attr_reader :extractors
    end

    # The URL of the webpage, an instance of Wgit::Url.
    attr_reader :url

    # The content/HTML of the document, an instance of String.
    attr_reader :html

    # The Nokogiri::HTML document object initialized from @html.
    attr_reader :parser

    # The score is only used following a `Database#search` and records matches.
    attr_reader :score

    # Initialize takes either two strings (representing the URL and HTML) or an
    # object representing a database record (of a HTTP crawled web page). This
    # allows for initialisation from both crawled web pages and documents/web
    # pages retrieved from the database.
    #
    # During initialisation, the Document will call any private
    # `init_*_from_html` and `init_*_from_object` methods it can find. See the
    # Wgit::Document.define_extractor method for more details.
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
        init_from_strings(url_or_obj, html, encode:)
      else
        init_from_object(url_or_obj, encode:)
      end
    end

    ### Document Class Methods ###

    # Uses Document.text_elements to build an xpath String, used to obtain
    # all of the combined visual text on a webpage.
    #
    # @return [String] An xpath String to obtain a webpage's text elements.
    def self.text_elements_xpath
      @text_elements.each_with_index.reduce('') do |xpath, (el, i)|
        xpath += ' | ' unless i.zero?
        xpath + format('//%s/text()', el)
      end
    end

    # Defines a content extractor, which extracts HTML elements/content
    # into instance variables upon Document initialization. See the default
    # extractors defined in 'document_extractors.rb' as examples. Defining an
    # extractor means that every subsequently crawled/initialized document
    # will attempt to extract the xpath's content. Use `#extract` for a one off
    # content extraction on any document.
    #
    # Note that defined extractors work for both Documents initialized from
    # HTML (via Wgit::Crawler methods) and from database objects.
    # An extractor once defined, initializes a private instance variable with
    # the xpath or database object result(s).
    #
    # When initialising from HTML, a singleton value of true will only
    # ever return the first result found; otherwise all the results are
    # returned in an Enumerable. When initialising from a database object, the
    # value is taken as is and singleton is only used to define the default
    # empty value. If a value cannot be found (in either the HTML or database
    # object), then a default will be used. The default value is:
    # `singleton ? nil : []`.
    #
    # @param var [Symbol] The name of the variable to be initialised, that will
    #   contain the extracted content. A getter and setter method is defined
    #   for the initialised variable.
    # @param xpath [String, #call] The xpath used to find the element(s)
    #   of the webpage. Only used when initializing from HTML.
    #
    #   Pass a callable object (proc etc.) if you want the
    #   xpath value to be derived on Document initialisation (instead of when
    #   the extractor is defined). The call method must return a valid xpath
    #   String.
    # @param opts [Hash] The options to define an extractor with. The
    #   options are only used when intializing from HTML, not the database.
    # @option opts [Boolean] :singleton The singleton option determines
    #   whether or not the result(s) should be in an Enumerable. If multiple
    #   results are found and singleton is true then the first result will be
    #   used. Defaults to true.
    # @option opts [Boolean] :text_content_only The text_content_only option
    #   if true will use the text #content of the Nokogiri result object,
    #   otherwise the Nokogiri object itself is returned. The type of Nokogiri
    #   object returned depends on the given xpath query. See the Nokogiri
    #   documentation for more information. Defaults to true.
    # @yield The block is executed when a Wgit::Document is initialized,
    #   regardless of the source. Use it (optionally) to process the result
    #   value.
    # @yieldparam value [Object] The result value to be assigned to the new
    #   `var`.
    # @yieldparam source [Wgit::Document, Object] The source of the `value`.
    # @yieldparam type [Symbol] The `source` type, either `:document` or (DB)
    #   `:object`.
    # @yieldreturn [Object] The return value of the block becomes the new var's
    #   value. Return the block's value param unchanged if you want to inspect.
    # @raise [StandardError] If the var param isn't valid.
    # @return [Symbol] The given var Symbol if successful.
    def self.define_extractor(var, xpath, opts = {}, &block)
      var = var.to_sym
      defaults = { singleton: true, text_content_only: true }
      opts = defaults.merge(opts)

      raise "var must match #{REGEX_EXTRACTOR_NAME}" unless \
      var =~ REGEX_EXTRACTOR_NAME

      # Define the private init_*_from_html method for HTML.
      # Gets the HTML's xpath value and creates a var for it.
      func_name = Document.send(:define_method, "init_#{var}_from_html") do
        result = extract_from_html(xpath, **opts, &block)
        init_var(var, result)
      end
      Document.send(:private, func_name)

      # Define the private init_*_from_object method for a Database object.
      # Gets the Object's 'key' value and creates a var for it.
      func_name = Document.send(
        :define_method, "init_#{var}_from_object"
      ) do |obj|
        result = extract_from_object(
          obj, var.to_s, singleton: opts[:singleton], &block
        )
        init_var(var, result)
      end
      Document.send(:private, func_name)

      @extractors << var
      var
    end

    # Removes the `init_*` methods created when an extractor is defined.
    # Therefore, this is the opposing method to `Document.define_extractor`.
    # Returns true if successful or false if the method(s) cannot be found.
    #
    # @param var [Symbol] The extractor variable to remove.
    # @return [Boolean] True if the extractor `var` was found and removed;
    #   otherwise false.
    def self.remove_extractor(var)
      Document.send(:remove_method, "init_#{var}_from_html")
      Document.send(:remove_method, "init_#{var}_from_object")

      @extractors.delete(var.to_sym)

      true
    rescue NameError
      false
    end

    # Removes all default and defined extractors by calling
    # `Document.remove_extractor` underneath. See its documentation.
    def self.remove_extractors
      @extractors.each { |var| remove_extractor(var) }
    end

    ### Document Instance Methods ###

    # Overrides String#inspect to shorten the printed output of a Document.
    #
    # @return [String] A short textual representation of this Document.
    def inspect
      "#<Wgit::Document url=\"#{@url}\" html_size=#{size}>"
    end

    # Determines if both the url and html match. Use
    # doc.object_id == other.object_id for exact object comparison.
    #
    # @param other [Wgit::Document] To compare self against.
    # @return [Boolean] True if @url and @html are equal, false if not.
    def ==(other)
      return false unless other.is_a?(Wgit::Document)

      (@url == other.url) && (@html == other.html)
    end

    # Shortcut for calling Document#html[range].
    #
    # @param range [Range] The range of @html to return.
    # @return [String] The given range of @html.
    def [](range)
      @html[range]
    end

    # Returns the base URL of this Wgit::Document. The base URL is either the
    # <base> element's href value or @url (if @base is nil). If @base is
    # present and relative, then @url.to_origin + @base is returned. This method
    # should be used instead of `doc.url.to_origin` etc. when manually building
    # absolute links from relative links; or use `link.make_absolute(doc)`.
    #
    # Provide the `link:` parameter to get the correct base URL for that type
    # of link. For example, a link of `#top` would always return @url because
    # it applies to that page, not a different one. Query strings work in the
    # same way. Use this parameter if manually joining Url's e.g.
    #
    #   relative_link = Wgit::Url.new('?q=hello')
    #   absolute_link = doc.base_url(link: relative_link).join(relative_link)
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
      if @url.relative? && @base.nil?
        raise "Document @url ('#{@url}') cannot be relative if <base> is nil"
      end

      if @url.relative? && @base&.relative?
        raise "Document @url ('#{@url}') and <base> ('#{@base}') both can't \
be relative"
      end

      get_base = -> { @base.relative? ? @url.to_origin.join(@base) : @base }

      if link
        link = Wgit::Url.new(link)
        raise "link must be relative: #{link}" unless link.relative?

        if link.is_fragment? || link.is_query?
          base_url = @base ? get_base.call : @url
          return base_url.omit_fragment.omit_query
        end
      end

      base_url = @base ? get_base.call : @url.to_origin
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
      ignore = Wgit::Document.to_h_ignore_vars.dup
      ignore << '@html' unless include_html
      ignore << '@score' unless include_score

      Wgit::Utils.to_h(self, ignore:)
    end

    # Converts this Document's #to_h return value to a JSON String.
    #
    # @param include_html [Boolean] Whether or not to include @html in the
    #   returned JSON String.
    # @return [String] This Document represented as a JSON String.
    def to_json(include_html: false)
      h = to_h(include_html:)
      JSON.generate(h)
    end

    # Returns a Hash containing this Document's instance variables and
    # their #length (if they respond to it). Works dynamically so that any
    # user defined extractors (and their created instance vars) will appear in
    # the returned Hash as well. The number of text snippets as well as total
    # number of textual bytes are always included in the returned Hash.
    #
    # @return [Hash] Containing self's HTML page statistics.
    def stats
      hash = {}
      instance_variables.each do |var|
        # Add up the total bytes of text as well as the length.
        if var == :@text
          hash[:text]       = @text.length
          hash[:text_bytes] = @text.sum(&:length)
        # Else take the var's #length method return value.
        else
          next unless instance_variable_get(var).respond_to?(:length)

          hash[var[1..].to_sym] = instance_variable_get(var).send(:length)
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
    # results. Use `#at_xpath` for returning the first result only.
    #
    # @param xpath [String] The xpath to search the @html with.
    # @return [Nokogiri::XML::NodeSet] The result set of the xpath search.
    def xpath(xpath)
      @parser.xpath(xpath)
    end

    # Uses Nokogiri's `at_xpath` method to search the doc's html and return the
    # result. Use `#xpath` for returning several results.
    #
    # @param xpath [String] The xpath to search the @html with.
    # @return [Nokogiri::XML::Element] The result of the xpath search.
    def at_xpath(xpath)
      @parser.at_xpath(xpath)
    end

    # Uses Nokogiri's `css` method to search the doc's html and return the
    # results. Use `#at_css` for returning the first result only.
    #
    # @param selector [String] The CSS selector to search the @html with.
    # @return [Nokogiri::XML::NodeSet] The result set of the CSS search.
    def css(selector)
      @parser.css(selector)
    end

    # Uses Nokogiri's `at_css` method to search the doc's html and return the
    # result. Use `#css` for returning several results.
    #
    # @param selector [String] The CSS selector to search the @html with.
    # @return [Nokogiri::XML::Element] The result of the CSS search.
    def at_css(selector)
      @parser.at_css(selector)
    end

    # Returns all unique internal links from this Document in relative form.
    # Internal meaning a link to another document on the same host.
    #
    # This Document's host is used to determine if an absolute URL is actually
    # a relative link e.g. For a Document representing
    # http://www.server.com/about, an absolute link of
    # <a href='http://www.server.com/search'> will be recognized and returned
    # as an internal link because both Documents live on the same host. Also
    # see Wgit::Document#internal_absolute_links.
    #
    # @return [Array<Wgit::Url>] Self's unique internal Url's in relative form.
    def internal_links
      return [] if @links.empty?

      links = @links
              .select { |link| link.relative?(host: @url.to_origin) }
              .map(&:omit_base)
              .map do |link| # Map @url.to_host into / as it's a duplicate.
        link.to_host == @url.to_host ? Wgit::Url.new('/') : link
      end

      Wgit::Utils.sanitize(links)
    end

    # Returns all unique internal links from this Document in absolute form by
    # appending them to self's #base_url. Also see
    # Wgit::Document#internal_links.
    #
    # @return [Array<Wgit::Url>] Self's unique internal Url's in absolute form.
    def internal_absolute_links
      internal_links.map { |link| link.make_absolute(self) }
    end

    # Returns all unique external links from this Document in absolute form.
    # External meaning a link to a different host.
    #
    # @return [Array<Wgit::Url>] Self's unique external Url's in absolute form.
    def external_links
      return [] if @links.empty?

      links = @links
              .map do |link|
                if link.scheme_relative?
                  link.prefix_scheme(@url.to_scheme.to_sym)
                else
                  link
                end
              end
              .reject { |link| link.relative?(host: @url.to_origin) }

      Wgit::Utils.sanitize(links)
    end

    # Searches the @text for the given query and returns the results.
    #
    # The number of search hits for each sentenence are recorded internally
    # and used to rank/sort the search results before being returned. Where
    # the Wgit::Database::DatabaseAdapter#search method search all documents
    # for the most hits, this method searches each document's @text for the
    # most hits.
    #
    # Each search result comprises of a sentence of a given length. The length
    # will be based on the sentence_limit parameter or the full length of the
    # original sentence, which ever is less. The algorithm obviously ensures
    # that the search query is visible somewhere in the sentence.
    #
    # @param query [Regexp, #to_s] The regex or text value to search the
    #   document's @text for.
    # @param case_sensitive [Boolean] Whether character case must match.
    # @param whole_sentence [Boolean] Whether multiple words should be searched
    #   for separately.
    # @param sentence_limit [Integer] The max length of each search result
    #   sentence.
    # @return [Array<String>] A subset of @text, matching the query.
    def search(
      query, case_sensitive: false, whole_sentence: true, sentence_limit: 80
    )
      raise 'The sentence_limit value must be even' if sentence_limit.odd?

      if query.is_a?(Regexp)
        regex = query
      else
        query = query.to_s
        query = query.gsub(' ', '|') unless whole_sentence
        regex = Regexp.new(query, !case_sensitive)
      end

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
    # @param query [Regexp, #to_s] The regex or text value to search the
    #   document's @text for.
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
      @text = search(query, case_sensitive:, whole_sentence:, sentence_limit:)

      orig_text
    end

    # Extracts a value/object from this Document's @html using the given xpath
    # parameter.
    #
    # @param xpath [String, #call] Used to find the value/object in @html.
    # @param singleton [Boolean] singleton ? results.first (single Object) :
    #   results (Enumerable).
    # @param text_content_only [Boolean] text_content_only ? result.content
    #   (String) : result (Nokogiri Object).
    # @yield (Optionally) Pass a block to read/write the result value before
    #   it's returned.
    # @yieldparam value [Object] The result value to be returned.
    # @yieldparam source [Wgit::Document, Object] This Document instance.
    # @yieldparam type [Symbol] The `source` type, which is `:document`.
    # @yieldreturn [Object] The return value of the block gets returned. Return
    #   the block's `value` param unchanged if you simply want to inspect it.
    # @return [String, Object] The value found in the html or the default value
    #   (singleton ? nil : []).
    def extract(xpath, singleton: true, text_content_only: true, &block)
      send(:extract_from_html, xpath, singleton:, text_content_only:, &block)
    end

    # Attempts to extract and check the HTML meta tags instructing Wgit not to
    # index this document (save it to a Database).
    #
    # @return [Boolean] True if this document shouldn't be saved to a Database,
    #   false otherwise.
    def no_index?
      meta_robots = extract_from_html(
        '//meta[@name="robots"]/@content',
        singleton: true,
        text_content_only: true
      )
      meta_wgit = extract_from_html(
        '//meta[@name="wgit"]/@content',
        singleton: true,
        text_content_only: true
      )

      [meta_robots, meta_wgit].include?('noindex')
    end

    # Firstly finds the target element whose text contains el_text.
    # Then finds the preceeding fragment element nearest to the target
    # element and returns it's href value (starting with #). The search is
    # performed against the @html so Documents loaded from a DB will need to
    # contain the 'html' field in the Wgit::Database::Model. See the
    # `Wgit::Database::Model#include_doc_html` documentation for more info.
    #
    # @param el_text [String] The element text of the target element.
    # @param el_type [String] The element type, defaulting to any type.
    # @yield [results] Given the results of the xpath query. Return the target
    #   you want or nil to use the default (first) target in results.
    # @return [String, nil] nil if no nearest fragment or '#about' if nearest
    #   fragment's href is '#about'.
    # @raise [StandardError] Raises if no matching target element containg
    #   el_text can be found.
    def nearest_fragment(el_text, el_type = "*")
      results = xpath("//#{el_type}[contains(text(),\"#{el_text}\")]")
      if results.empty?
        raise "Unable to find element '#{el_type}' containing text '#{el_text}'"
      end

      target = results.first
      if block_given?
        result = yield(results)
        target = result if result
      end

      target_index = html_index(target)
      raise 'Failed to find target index' unless target_index

      fragment_h = fragment_indices(fragments)

      # Return the target href if it's a fragment.
      return fragment_h[target_index] if fragment_h.keys.include?(target_index)

      # Find the target's nearest preceeding fragment href.
      closest_index = 0
      fragment_h.each do |fragment_index, href|
        if fragment_index.between?(closest_index, target_index)
          closest_index = fragment_index
        end
      end

      fragment_h[closest_index]
    end

    protected

    # Initializes the nokogiri object using @html, which cannot be nil.
    # Override this method to custom configure the Nokogiri object returned.
    # Gets called from Wgit::Document.new upon initialization.
    #
    # @yield [config] The given block is passed to Nokogiri::HTML for
    #   initialisation.
    # @raise [StandardError] If @html isn't set.
    # @return [Nokogiri::HTML] The initialised Nokogiri HTML object.
    def init_nokogiri(&block)
      raise '@html must be set' unless @html

      Nokogiri::HTML(@html, &block)
    end

    # Extracts a value/object from this Document's @html using the given xpath
    # parameter.
    #
    # @param xpath [String, #call] Used to find the value/object in @html.
    # @param singleton [Boolean] singleton ? results.first (single Object) :
    #   results (Enumerable).
    # @param text_content_only [Boolean] text_content_only ? result.content
    #   (String) : result (Nokogiri Object).
    # @yield (Optionally) Pass a block to read/write the result value before
    #   it's returned.
    # @yieldparam value [Object] The result value to be returned.
    # @yieldparam source [Wgit::Document, Object] This Document instance.
    # @yieldparam type [Symbol] The `source` type, which is `:document`.
    # @yieldreturn [Object] The return value of the block gets returned. Return
    #   the block's `value` param unchanged if you simply want to inspect it.
    # @return [String, Object] The value found in the html or the default value
    #   (singleton ? nil : []).
    def extract_from_html(xpath, singleton: true, text_content_only: true)
      xpath  = xpath.call if xpath.respond_to?(:call)
      result = singleton ? at_xpath(xpath) : xpath(xpath)

      if result && text_content_only
        result = singleton ? result.content : result.map(&:content)
      end

      result = Wgit::Utils.sanitize(result)
      result = yield(result, self, :document) if block_given?
      result
    end

    # Returns a value from the obj using the given key via `obj#fetch`.
    #
    # @param obj [#fetch] The object containing the key/value.
    # @param key [String] Used to find the value in the obj.
    # @param singleton [Boolean] True if a single value, false otherwise.
    # @yield The block is executed when a Wgit::Document is initialized,
    #   regardless of the source. Use it (optionally) to process the result
    #   value.
    # @yieldparam value [Object] The result value to be returned.
    # @yieldparam source [Wgit::Document, Object] The source of the `value`.
    # @yieldparam type [Symbol] The `source` type, either `:document` or (DB)
    #   `:object`.
    # @yieldreturn [Object] The return value of the block gets returned. Return
    #   the block's `value` param unchanged if you simply want to inspect it.
    # @return [String, Object] The value found in the obj or the default value
    #   (singleton ? nil : []).
    def extract_from_object(obj, key, singleton: true)
      assert_respond_to(obj, :fetch)

      default = singleton ? nil : []
      result  = obj.fetch(key.to_s, default)

      result = Wgit::Utils.sanitize(result)
      result = yield(result, obj, :object) if block_given?
      result
    end

    private

    # Initialise the Document from URL and HTML Strings.
    def init_from_strings(url, html, encode: true)
      assert_types(html, [String, NilClass])

      # We already know url.is_a?(String) so parse into Url unless already so.
      url = Wgit::Url.parse(url)
      url.crawled = true unless url.crawled? # Avoid overriding date_crawled.

      @url    = url
      @html   = html || ''
      @parser = init_nokogiri
      @score  = 0.0

      @html = Wgit::Utils.sanitize(@html, encode:)

      # Dynamically run the init_*_from_html methods.
      Document.private_instance_methods(false).each do |method|
        if method.to_s.start_with?('init_') &&
           method.to_s.end_with?('_from_html') && method != __method__
          send(method)
        end
      end
    end

    # Initialise the Document from a Hash like Object containing Strings as
    # keys e.g. database collection object or Hash.
    def init_from_object(obj, encode: true)
      assert_respond_to(obj, :fetch)

      @url    = Wgit::Url.new(obj.fetch('url')) # Should always be present.
      @html   = obj.fetch('html', '')
      @parser = init_nokogiri
      @score  = obj.fetch('score', 0.0)

      @html = Wgit::Utils.sanitize(@html, encode:)

      # Dynamically run the init_*_from_object methods.
      Document.private_instance_methods(false).each do |method|
        if method.to_s.start_with?('init_') &&
           method.to_s.end_with?('_from_object') && method != __method__
          send(method, obj)
        end
      end
    end

    # Initialises an instance variable and defines an accessor method for it.
    #
    # @param var [Symbol] The name of the variable to be initialized.
    # @param value [Object] The newly initialized variable's value.
    # @return [Symbol] The name of the defined getter method.
    def init_var(var, value)
      # instance_var_name starts with @, var_name doesn't.
      var = var.to_s
      var_name = (var.start_with?('@') ? var[1..] : var).to_sym
      instance_var_name = "@#{var_name}".to_sym

      instance_variable_set(instance_var_name, value)
      Wgit::Document.attr_accessor(var_name)

      var_name
    end

    # Returns all <a> fragment elements from within the HTML body e.g. #about.
    def fragments
      anchors = xpath("/html/body//a")

      anchors.select do |anchor|
        href = anchor.attributes['href']&.value
        href&.start_with?('#')
      end
    end

    # Returns a Hash{Int=>String} of <a> fragment positions and their href
    # values. Only fragment anchors are returned e.g. <a> elements with a
    # href starting with '#'.
    def fragment_indices(fragments)
      fragments.reduce({}) do |hash, fragment|
        index = html_index(fragment)
        next(hash) unless index

        href = fragment.attributes['href']&.value
        hash[index] = href

        hash
      end
    end

    # Takes a Nokogiri element or HTML substring and returns it's index in
    # @html. Returns the index/position Integer or nil if not found. The search
    # is case insensitive because Nokogiri lower cases camelCase attributes.
    def html_index(el_or_str)
      @html.downcase.index(el_or_str.to_s.strip.downcase)
    end

    alias_method :content,                :html
    alias_method :statistics,             :stats
    alias_method :internal_urls,          :internal_links
    alias_method :internal_absolute_urls, :internal_absolute_links
    alias_method :external_urls,          :external_links
  end
end
