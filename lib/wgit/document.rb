require_relative 'url'
require_relative 'utils'
require_relative 'assertable'
require 'nokogiri'
require 'json'

module Wgit

  # Class modeling a HTML web document. Also doubles as a search result when
  # loading Documents from the database.
  #
  # The initialize method dynamically initializes certain variables from the
  # Document HTML / Database object e.g. text. This bit is dynamic so that the
  # Document class can be easily extended allowing you to pull out the bits of
  # a webpage that are important to you. See Wgit::Document.define_extension.
  class Document
    include Assertable

    # The HTML elements that make up the visible text on a page.
    # These elements are used to initialize the @text of the Document.
    # See the README.md for how to add to this Array dynamically.
    @text_elements = [
      :dd, :div, :dl, :dt, :figcaption, :figure, :hr, :li,
      :main, :ol, :p, :pre, :span, :ul, :h1, :h2, :h3, :h4, :h5
    ]

    class << self
      # Class level instance reader method for @text_elements.
      # Call using Wgit::Document.text_elements.
      attr_reader :text_elements
    end

    # The URL of the webpage, an instance of Wgit::Url.
    attr_reader :url

    # The HTML of the webpage, an instance of String.
    attr_reader :html

    # The Nokogiri document object initialized from @html.
    attr_reader :doc

    # The score is only used following a Database#search and records matches.
    attr_reader :score

    # Initialize takes either two strings (representing the URL and HTML) or an
    # object representing a database record (of a HTTP crawled web page). This
    # allows for initialisation from both crawled web pages and (afterwards)
    # documents/web pages retrieved from the database.
    #
    # During initialisation, the Document will call any
    # 'init_*_from_html' and 'init_*_from_object' methods it can find. Some
    # default init_* methods exist while others can be defined by the user.
    # See the README and Wgit::Document.define_extension for more info.
    #
    # @param url_or_obj [String, Object#fetch] Either a String representing a
    #   URL or a Hash-like object responding to :fetch. e.g. a MongoDB
    #   collection object. The Object's :fetch method should support Strings as
    #   keys.
    # @param html [String] The crawled web page's HTML. This param is only
    #   required if url_or_obj is a String representing the web page's URL.
    def initialize(url_or_obj, html = "")
      # Init from URL String and HTML String.
      if url_or_obj.is_a?(String)
        url = url_or_obj
        assert_type(url, Wgit::Url)

        @url = url
        @html = html ||= ""
        @doc = init_nokogiri
        @score = 0.0

        process_url_and_html

        # Dynamically run the init_*_from_html methods.
        Document.private_instance_methods(false).each do |method|
          if method.to_s.start_with?("init_") &&
                method.to_s.end_with?("_from_html")
            self.send(method)
          end
        end
      # Init from a Hash like object containing Strings as keys e.g. Mongo
      # collection obj.
      else
        obj = url_or_obj
        assert_respond_to(obj, :fetch)

        @url = Wgit::Url.new(obj.fetch("url")) # Should always be present.
        @html = obj.fetch("html", "")
        @doc = init_nokogiri
        @score = obj.fetch("score", 0.0)

        process_url_and_html

        # Dynamically run the init_*_from_object methods.
        Document.private_instance_methods(false).each do |method|
          if method.to_s.start_with?("init_") &&
                method.to_s.end_with?("_from_object")
            self.send(method, obj)
          end
        end
      end
    end

    # Determines if both the url and html match. Use
    # doc.object_id == other_doc.object_id for exact object comparison.
    #
    # @param other_doc [Wgit::Document] To compare self against.
    # @return [Boolean] True if @url and @html are equal, false if not.
    def ==(other_doc)
      return false unless other_doc.is_a? Wgit::Document
      @url == other_doc.url and @html == other_doc.html
    end

    # Is a shortcut for calling Document#html[range].
    #
    # @param range [Range] The range of @html to return.
    # @return [String] The given range of @html.
    def [](range)
      @html[range]
    end

    # Returns the timestamp of when this Wgit::Document was crawled.
    #
    # @return [Time] Time of when this Wgit::Document was crawled.
    def date_crawled
      @url.date_crawled
    end

    # Returns the base URL of this Wgit::Document. The base URL is either the
    # <base> element's href value or @url (if @base is nil). If @base is
    # present and relative, then @url + @base is returned. This method should
    # be used instead of `doc.url.to_base` if manually building absolute links.
    #
    # @return [Wgit::Url] The base URL of this Document e.g.
    #   'http://example.com/public'.
    def base_url
      return @url.base unless @base
      @base.is_relative? ? @url.to_base.concat(@base) : @base
    end

    # Returns a Hash containing this Document's instance vars.
    # Used when storing the Document in a Database e.g. MongoDB etc.
    # By default the @html var is excluded from the returned Hash.
    #
    # @param include_html [Boolean] Whether or not to include @html in the
    #   returned Hash.
    # @return [Hash] Containing self's instance vars.
    def to_h(include_html = false)
      ignore = include_html ? [] : ["@html"]
      ignore << "@doc" # Always ignore "@doc"
      Wgit::Utils.to_h(self, ignore)
    end

    # Converts this Document's to_h return value to a JSON String.
    #
    # @param include_html [Boolean] Whether or not to include @html in the
    #   returned JSON String.
    # @return [String] This Document represented as a JSON String.
    def to_json(include_html = false)
      h = to_h(include_html)
      JSON.generate(h)
    end

    # Returns a Hash containing this Document's instance variables and
    # their :length (if they respond to it). Works dynamically so that any
    # user defined extensions (and their created instance vars) will appear in
    # the returned Hash as well. The number of text snippets as well as total
    # number of textual bytes are always included in the returned Hash.
    #
    # @return [Hash] Containing self's HTML statistics.
    def stats
      hash = {}
      instance_variables.each do |var|
        # Add up the total bytes of text as well as the length.
        if var == :@text
          count = 0
          @text.each { |t| count += t.length }
          hash[:text_snippets] = @text.length
          hash[:text_bytes] = count
        # Else take the var's #length method return value.
        else
          next unless instance_variable_get(var).respond_to?(:length)
          hash[var[1..-1].to_sym] =
                              instance_variable_get(var).send(:length)
        end
      end
      hash
    end

    # Determine the size of this Document's HTML.
    #
    # @return [Integer] The total number of bytes in @html.
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

    # Get all the internal links of this Document in relative form. Internal
    # meaning a link to another document on this domain. This Document's domain
    # is used to determine if an absolute URL is actually a relative link e.g.
    # For a Document representing http://server.com/about, an absolute link of
    # <a href='http://server.com/search'> will be recognized and returned as an
    # internal link because both Documents live on the same domain. Also see
    # Wgit::Document#internal_full_links.
    #
    # @return [Array<Wgit::Url>] self's internal/relative URL's.
    def internal_links
      return [] if @links.empty?

      links = @links.
        reject { |link| !link.is_relative?(base: @url.to_base) }.
        map(&:without_base).
        map do |link| # We map @url.to_host into / because it's a duplicate.
          link.to_host == @url.to_host ? Wgit::Url.new('/') : link
        end

      Wgit::Utils.process_arr(links)
    end

    # Get all the internal links of this Document with their anchors removed
    # (if present). Also see Wgit::Document#internal_links.
    #
    # @return [Array<Wgit::Url>] self's internal/relative URL's with their
    #   anchors removed.
    def internal_links_without_anchors
      links = internal_links
      return [] if links.empty?
      links.
        map(&:without_anchor).
        reject(&:empty?)
    end

    # Get all the internal links of this Document and append them to this
    # Document's base URL making them absolute. Also see
    # Wgit::Document#internal_links.
    #
    # @return [Array<Wgit::Url>] self's internal/relative URL's in absolute
    #   form.
    def internal_full_links
      links = internal_links
      return [] if links.empty?
      links.map { |link| base_url.concat(link) }
    end

    # Get all the external links of this Document. External meaning a link to
    # a different domain.
    #
    # @return [Array<Wgit::Url>] self's external/absolute URL's.
    def external_links
      return [] if @links.empty?

      links = @links.
        reject { |link| link.relative_link?(base: @url.to_base) }.
        map(&:without_trailing_slash)

      Wgit::Utils.process_arr(links)
    end

    # Searches against the @text for the given search query.
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
    # @param query [String] The value to search the document's text against.
    # @param sentence_limit [Integer] The max length of each search result
    #   sentence.
    # @return [Array<String>] Representing the search results.
    def search(query, sentence_limit = 80)
      raise "A search query must be provided" if query.empty?
      raise "The sentence_limit value must be even" if sentence_limit.odd?

      results = {}
      regex = Regexp.new(query, Regexp::IGNORECASE)

      @text.each do |sentence|
        hits = sentence.scan(regex).count
        if hits > 0
          sentence.strip!
          index = sentence.index(regex)
          Wgit::Utils.format_sentence_length(sentence, index, sentence_limit)
          results[sentence] = hits
        end
      end

      return [] if results.empty?
      results = Hash[results.sort_by { |k, v| v }]
      results.keys.reverse
    end

    # Performs a text search (see Document#search for details) but assigns the
    # results to the @text instance variable. This can be used for sub search
    # functionality. The original text is returned; no other reference to it
    # is kept thereafter.
    #
    # @param query [String] The value to search the document's text against.
    # @param sentence_limit [Integer] The max length of each search result
    #   sentence.
    # @return [String] This Document's original @text value.
    def search!(query, sentence_limit = 80)
      orig_text = @text
      @text = search(query, sentence_limit)
      orig_text
    end

    ### Document (Class) methods ###

    # Uses Document.text_elements to build an xpath String, used to obtain
    # all of the combined text on a webpage.
    #
    # @return [String] An xpath String to obtain a webpage's text elements.
    def self.text_elements_xpath
      xpath = ""
      return xpath if Wgit::Document.text_elements.empty?
      el_xpath = "//%s/text()"
      Wgit::Document.text_elements.each_with_index do |el, i|
        xpath += " | " unless i == 0
        xpath += el_xpath % [el]
      end
      xpath
    end

    # Initialises a private instance variable with the xpath or database object
    # result(s). When initialising from HTML, a true singleton value will only
    # ever return one result otherwise all xpath results are returned in an
    # Array. When initialising from a database object, the value is taken as
    # is and singleton is only used to define the default empty value.
    # If a value cannot be found (in either the HTML or database object), then
    # a default will be used. The default is: singleton ? nil : [].
    #
    # Note that defined extensions work for both documents being crawled from
    # the WWW and for documents being retrieved from the database. This
    # effectively implements ORM like behavior using this class.
    #
    # @param var [Symbol] The name of the variable to be initialised.
    # @param xpath [String, Object#call] The xpath used to find the element(s)
    #   of the webpage. Pass a callable object (proc etc.) if you want the
    #   xpath value to be derived on Document initialisation (instead of when
    #   the extension is defined). The call method must return a valid xpath
    #   String.
    # @param options [Hash] The options to define an extension with.
    # @option options [Boolean] :singleton The singleton option determines
    #   whether or not the result(s) should be in an Array. If multiple
    #   results are found and singleton is true then the first result will be
    #   used. Defaults to true.
    # @option options [Boolean] :text_content_only The text_content_only option
    #   if true will use the text content of the Nokogiri result object,
    #   otherwise the Nokogiri object itself is returned. Defaults to true.
    # @yield [Object, Symbol] Yields the value about to be assigned to the new
    #   var and the source of the value (either :html or :object aka database).
    #   The return value of the block becomes the new var value, unless nil.
    #   Return nil if you want to inspect but not change the var value. The
    #   block gets executed when a Document is initialized from html or an
    #   object.
    # @return [Symbol] The first half of the newly defined method names e.g.
    #   if var == "title" then :init_title is returned.
    def self.define_extension(var, xpath, options = {}, &block)
      default_options = { singleton: true, text_content_only: true }
      options = default_options.merge(options)

      # Define the private init_*_from_html method for HTML.
      # Gets the HTML's xpath value and creates a var for it.
      func_name = Document.send(:define_method, "init_#{var}_from_html") do
        result = find_in_html(xpath, options, &block)
        init_var(var, result)
      end
      Document.send :private, func_name

      # Define the private init_*_from_object method for a Database object.
      # Gets the Object's "key" value and creates a var for it.
      func_name = Document.send(:define_method, "init_#{var}_from_object") do |obj|
        result = find_in_object(obj, var.to_s, singleton: options[:singleton], &block)
        init_var(var, result)
      end
      Document.send :private, func_name

      "init_#{var}".to_sym
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

  private

    # Initializes the nokogiri object using @html, which must be already set.
    def init_nokogiri
      raise "@html must be set" unless @html
      Nokogiri::HTML(@html) do |config|
        # TODO: Remove #'s below when crawling in production.
        #config.options = Nokogiri::XML::ParseOptions::STRICT |
        #                 Nokogiri::XML::ParseOptions::NONET
      end
    end

    # Ensure the @url and @html Strings are correctly encoded etc.
    def process_url_and_html
      @url = Wgit::Utils.process_str(@url)
      @html = Wgit::Utils.process_str(@html)
    end

    # Returns an object/value from this Document's @html using the provided
    # xpath param.
    # singleton ? results.first (single Object) : results (Array)
    # text_content_only ? result.content (String) : result (nokogiri Object)
    # A block can be used to set the final value before it is returned.
    # Return nil from the block if you don't want to override the value.
    def find_in_html(xpath, singleton: true, text_content_only: true)
      xpath = xpath.call if xpath.respond_to?(:call)
      results = @doc.xpath(xpath)

      if results and not results.empty?
        result =  if singleton
                    text_content_only ? results.first.content : results.first
                  else
                    text_content_only ? results.map(&:content) : results
                  end
      else
        result = singleton ? nil : []
      end

      singleton ? Wgit::Utils.process_str(result) : Wgit::Utils.process_arr(result)

      if block_given?
        new_result = yield(result, :html)
        result = new_result if new_result
      end

      result
    end

    # Finds a value in the obj using the key.
    # singleton is used to set the value if not found in obj.
    # A block can be used to set the final value before it is returned.
    # Return nil from the block if you don't want to override the value.
    def find_in_object(obj, key, singleton: true)
      assert_respond_to(obj, :fetch)

      default = singleton ? nil : []
      result = obj.fetch(key.to_s, default)
      singleton ? Wgit::Utils.process_str(result) : Wgit::Utils.process_arr(result)

      if block_given?
        new_result = yield(result, :object)
        result = new_result if new_result
      end

      result
    end

    # Initialises an instance variable and defines a getter method for it.
    # @param var [Symbol] The name of the variable to be initialized.
    # @param value [Object] The newly initialized variable's value.
    # @return [Symbol] The name of the newly created getter method.
    def init_var(var, value)
      # instance_var_name starts with @, var_name doesn't.
      var = var.to_s
      var_name = (var.start_with?("@") ? var[1..-1] : var).to_sym
      instance_var_name = "@#{var_name}".to_sym

      instance_variable_set(instance_var_name, value)

      Document.send(:define_method, var_name) do
        instance_variable_get(instance_var_name)
      end
    end

    alias :relative_links :internal_links
    alias :relative_urls :internal_links
    alias :relative_full_links :internal_full_links
    alias :relative_full_urls :internal_full_links
    alias :external_urls :external_links
  end
end
