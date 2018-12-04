require_relative 'url'
require_relative 'utils'
require_relative 'assertable'
require 'nokogiri'

module Wgit

  # @author Michael Telford
  # Class modeling a HTML web document. Also doubles as a search result when 
  # loading Documents from the database. 
  #
  # The initialize method dynamically init certain variables from the 
  # Document HTML e.g. text. This bit is dynamic so the Document class can be 
  # easily extended by code elsewhere. 
  class Document
    include Assertable
    
    # The HTML elements that make up the visible text on a page.
    # These elements are used to init_text on the Document. 
    @@text_elements = [
      :dd, :div, :dl, :dt, :figcaption, :figure, :hr, :li, 
      :main, :ol, :p, :pre, :span, :ul, :h1, :h2, :h3, :h4, :h5
    ]
    
    attr_reader :url, :html, :doc, :score
  
    # Initialize takes either two strings (representing the URL and HTML) or an
    # object representing a database record (of a HTTP crawled web page). This
    # allows for initialisation from both crawled web pages and (afterwards)
    # documents/web pages retrieved from the database.
    #
    # During initialised, the Wgit::Document will call any 'init_*' methods
    # it can find. Some default init_* methods exist while others can be
    # defined by the user. See Wgit::Document.define_extension for more info.
    #
    # @param [String|Hash|Object] url_or_obj is either a String representing a
    # URL or a Hash like object responding to :[], :each etc. e.g. a MongoDB
    # collection object.
    # @param [String] html is a String of the crawled web page's HTML. Defaults
    # to an empty String if not provided. This param is only required if
    # url_or_obj is a String representing the web page's URL.
    # @return [Wgit::Document] The initialised Wgit::Document ready for use.
    def initialize(url_or_obj, html = "")
      # Init from URL String and HTML String.
      if url_or_obj.is_a?(String)
        url = url_or_obj
        assert_type(url, Url)
  
        @url = url
        @html = html ||= ""
        @doc = init_nokogiri
        @score = 0.0
        
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
        unless obj.respond_to?(:fetch) && obj.respond_to?(:[])
          raise "obj must respond_to? :fetch and :[]"
        end

        @url = obj.fetch("url") # Should always be present.
        @html = obj.fetch("html", "")
        @doc = init_nokogiri
        @score = obj.fetch("score", 0.0)
        
        # Dynamically run the init_*_from_object methods.
        Document.private_instance_methods(false).each do |method|
          if method.to_s.start_with?("init_") && 
             method.to_s.end_with?("_from_object")
              self.send(method, obj)
          end
        end
      end
    end
    
    # Override of the default == method, is equal if url and html both match.
    # Use doc.object_id == other_doc.object_id for exact object comparison. 
    def ==(other_doc)
      return false unless other_doc.is_a? Wgit::Document
      url == other_doc.url and html == other_doc.html
    end
    
    # Shortcut for calling Document#html[range].
    def [](range)
      html[range]
    end
    
    def to_h(include_html = false)
        ignore = include_html ? [] : ["@html"]
        ignore << "@doc" # Always ignore "@doc"
        Wgit::Utils.to_h(self, ignore)
    end
    
    def stats
        hash = {}
        instance_variables.each do |var|
            # Add up the total bytes of text as well as the length.
            if var == :@text
                count = 0
                @text.each { |t| count += t.length }
                hash[:text_length] = @text.length
                hash[:text_bytes] = count
            # Else take the #length method return value.
            else
                next unless instance_variable_get(var).respond_to?(:length)
                hash[var[1..-1].to_sym] = 
                                    instance_variable_get(var).send(:length)
            end
        end
        hash
    end
  
    def size
        stats[:html]
    end
  
    def empty?
      return true if html.nil?
      html.strip.empty?
    end
    
    # Uses Nokogiri's xpath method to search the doc's html and return the 
    # results. 
    def xpath(xpath)
  		@doc.xpath(xpath)
    end
    
  	def internal_links
      return [] if @links.empty?
	    @links.reject do |link|
          begin
              not link.relative_link?
          rescue
              true
          end
      end
  	end
    
    def internal_full_links
      in_links = internal_links
      return [] if in_links.empty?
      in_links.map do |link|
          link.replace("/" + link) unless link.start_with?("/")
          Wgit::Url.new(@url.to_base + link)
      end
    end
	
  	def external_links
      return [] if @links.empty?
  		@links.reject do |link|
        begin
            link.relative_link?
        rescue
            true
        end
      end
  	end
  
    # Searches against the Document#text for the given search text.
    # The number of search hits for each sentenence are recorded internally 
    # and used to rank/sort the search results before being returned. Where 
    # the Database#search method search all documents for the most hits this 
    # method searches each documents text for the most hits. 
    #
    # Each search result comprises of a sentence of a given length. The length 
    # will be based on the sentence_limit parameter or the full length of the 
    # original sentence, which ever is less. The algorithm obviously ensures 
    # that the search value is visible somewhere in the sentence.
    #
    # @param text [String] the value to search the document text against.
    # @param sentence_limit [Fixnum] the length of each search result 
    # sentence. 
    # 
    # @return [Array] of String objects representing the search results.
    def search(text, sentence_limit = 80)
      raise "A search value must be provided" if text.empty?
      raise "The sentence length value must be even" if sentence_limit.odd?
    
      results = {}
      regex = Regexp.new(text, Regexp::IGNORECASE)
    
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
  
    # Performs a text search (see search for details) but assigns the results 
    # to the @text instance variable. This can be used for sub search 
    # functionality. The original text is returned; no other reference to it
    # is kept.
    def search!(text)
      orig_text = @text
      @text = search(text)
      orig_text
    end
    
    ### Document (Class) methods ###
    
    def self.text_elements
      @@text_elements
    end

    # Initialises a private instance variable with the xpath or database object
    # result(s). When initialising from HTML, a true singleton value will only
    # ever return one result otherwise all xpath results are returned in an
    # Array. When initialising from a database object, the value is taken as
    # is.
    #
    # Yields the result value to a given block before setting the instance 
    # variable allowing for prior manipulation if required. The return value 
    # of the block becomes the result value assigned to the instance variable
    # if not nil. Therefore return nil if you want to examine but not change 
    # the result before the instance var is set.
    #
    # Note that any defined extensions work for documents being crawled from
    # the WWW and for documents being retrieved from the database. This
    # effectively implements ORM like behavior.
    #
    # @param [Symbol] var is the name of the variable to be initialised.
    # @param [String] xpath is used to find the element(s) of the webpage.
    # @param [Hash] options is a Hash which defaults if not set. 
    #
    # The singleton option determines whether or not the result(s) should be
    # in an Array. If multiple results are found and singleton is true then
    # the first result will be used. Defaults to true.
    #
    # The text_content_only option if true will use the text content of 
    # the Nokogiri result object, otherwise the Nokogiri object itself is 
    # returned. Defaults to true.
    # @return [Symbol] The first half of the newly created method names.
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
      # E.g. var == "title" then: `@title = obj[:title]`
      func_name = Document.send(
                        :define_method, "init_#{var}_from_object") do |obj|
        result = find_in_object(
                      obj, var.to_s, singleton: options[:singleton], &block)
        init_var(var, result)
      end
      Document.send :private, func_name

      "init_#{var}".to_sym
    end

    # The opposing method to Wgit::Document.define_extension.
    # Removes the init_* method created when an extension is defined.
    # Returns true if successful or false if the method cannot be found.
    #
    # @param [String|Symbol] var is the name of the extension variable.
    # @return [Boolean] true if the extension var was found and removed;
    # otherwise false is returned.
    def self.remove_extension(var)
      Document.send(:remove_method, "init_#{var}_from_html")
      Document.send(:remove_method, "init_#{var}_from_object")
      true
    rescue NameError
      false
    end

    private

    def init_nokogiri
      raise "@html must be set" unless @html
      Nokogiri::HTML(@html) do |config|
        # TODO: Remove #'s below when crawling in production.
        #config.options = Nokogiri::XML::ParseOptions::STRICT | 
        #                 Nokogiri::XML::ParseOptions::NONET
      end
    end

    def find_in_html(xpath, singleton: true, text_content_only: true)
      results = @doc.xpath(xpath)
      
      if results and not results.empty?
        result = if singleton
                   text_content_only ? results.first.content : results.first
                 else
                   text_content_only ? results.map(&:content) : results
                 end
      else
        result = singleton ? nil : []
      end
      
      singleton ? process_str(result) : process_arr(result)

      if block_given?
        new_result = yield result
        result = new_result if new_result
      end

      result
    end

    def find_in_object(obj, key, singleton: true)
      default = singleton ? nil : []
      result = obj.fetch(key.to_s, default)
      singleton ? process_str(result) : process_arr(result)

      if block_given?
        new_result = yield result
        result = new_result if new_result
      end

      result
    end
    
    # Initialises an instance variable and defines a getter method for it. 
    # The value of the instance variable will be the xpath result. 
    # If no xpath results are found the variable will have a value of nil for 
    # singleton vars or an empty array for non singleton vars. The result 
    # will be processed by either process_str or process_arr depending on 
    # the singleton value. Both of these methods are type safe. 
    # Yields the xpath result to a given block before setting the instance 
    # variable allowing for prior manipulation if required. The return value 
    # of the block becomes the result value assigned to the instance variable
    # if not nil. Therefore return nil if you don't want to change the result.
    # 
    # @param [Symbol] var is the name of the variable to be initialised. 
    # @param [String] xpath is used to find the element(s) of the webpage.
    # @param [Boolean] singleton determines whether or not the result(s) should 
    # be in an Array. If multiple results are found and singleton is true then 
    # the first result will be used. 
    # @param [Boolean] text_content_only if true will use the text content of 
    # the Nokogiri result object, otherwise the Nokogiri object itself is 
    # returned. 
    # @return [Object] the newly init variable's value containing the xpath 
    # result(s).
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
    
    def text_elements_xpath
        xpath = ""
        return xpath if @@text_elements.empty?
        el_xpath = "//%s/text()"
        @@text_elements.each_with_index do |el, i|
            xpath += " | " unless i == 0
            xpath += el_xpath % [el]
        end
        xpath
    end

    def process_str(str)
      if str.is_a?(String)
        str.encode!('UTF-8', 'UTF-8', :invalid => :replace)
        str.strip!
      end
      str
    end

    def process_arr(array)
        if array.is_a?(Array)
          array.map! { |str| process_str(str) }
          array.reject! { |str| str.is_a?(String) ? str.empty? : false }
          array.uniq!
        end
        array
    end
  
    # Modifies internal links by removing this doc's base or host url if 
    # present. http://www.google.co.uk/about.html (with or without the 
    # protocol prefix) will become about.html meaning it'll appear within 
    # internal_links.
    def process_internal_links(links)
        links.map! do |link|
            host_or_base = if link.start_with?("http")
                              url.base
                           else
                              url.host
                           end
            if link.start_with?(host_or_base)
                link.sub!(host_or_base, "")
                link.replace(link[1..-1]) if link.start_with?("/")
                link.strip!
            end
            link
        end
    end

    ### Default init_* methods. ###
    
    # Init methods for title.
    
    def init_title_from_html
      xpath = "//title"
      result = find_in_html(xpath)
      init_var(:@title, result)
    end
    
    def init_title_from_object(obj)
      result = find_in_object(obj, "title")
      init_var(:@title, result)
    end
  
    # Init methods for author.

    def init_author_from_html
      xpath = "//meta[@name='author']/@content"
      result = find_in_html(xpath)
      init_var(:@author, result)
    end

    def init_author_from_object(obj)
      result = find_in_object(obj, "author")
      init_var(:@author, result)
    end

    # Init methods for keywords.

    def init_keywords_from_html
      xpath = "//meta[@name='keywords']/@content"
      result = find_in_html(xpath) do |keywords|
        if keywords
          keywords = keywords.split(",")
          process_arr(keywords)
        end
        keywords
      end
      init_var(:@keywords, result)
    end

    def init_keywords_from_object(obj)
      result = find_in_object(obj, "keywords", singleton: false)
      init_var(:@keywords, result)
    end
    
    # Init methods for links.

    def init_links_from_html
      xpath = "//a/@href"
      result = find_in_html(xpath, singleton: false) do |links|
        if links
          links.reject! { |link| link == "/" }
          links.map! do |link|
            begin
              Wgit::Url.new(link)
            rescue
              nil
            end
          end
          links.reject! { |link| link.nil? }
          process_internal_links(links)
        end
        links
      end
      init_var(:@links, result)
    end

    def init_links_from_object(obj)
      result = find_in_object(obj, "links", singleton: false) do |links|
        if links
          links.map! { |link| Wgit::Url.new(link) }
        end
        links
      end
      init_var(:@links, result)
    end

    # Init methods for text.

    def init_text_from_html
      xpath = text_elements_xpath
      result = find_in_html(xpath, singleton: false)
      init_var(:@text, result)
    end

    def init_text_from_object(obj)
      result = find_in_object(obj, "text", singleton: false)
      init_var(:@text, result)
    end
    
  	alias :to_hash :to_h
    alias :relative_links :internal_links
    alias :relative_urls :internal_links
    alias :relative_full_links :internal_full_links
    alias :relative_full_urls :internal_full_links
    alias :external_urls :external_links
  end
end
