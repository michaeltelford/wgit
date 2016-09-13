require_relative 'url'
require_relative 'utils'
require_relative 'assertable'
require 'nokogiri'

require 'byebug'

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
    
    # The HTML elements that make up visible text on a page.
    # These elements are used to init_text on the Document. 
    @@text_elements = [
      :dd, :div, :dl, :dt, :figcaption, :figure, :hr, :li, 
      :main, :ol, :p, :pre, :span, :ul, :h1, :h2, :h3, :h4, :h5
    ]
    
    attr_reader :url, :html, :score
	
  	def initialize(url_or_doc, html = "")
      if (url_or_doc.is_a?(String))
        assert_type(url_or_doc, Url)
  
        @url = url_or_doc
        @html = html

        @doc = Nokogiri::HTML(html) do |config|
            # TODO: Remove #'s below when crawling in production.
            #config.options = Nokogiri::XML::ParseOptions::STRICT | 
            #                 Nokogiri::XML::ParseOptions::NONET
        end

        @score = 0.0
        
        # Dynamically run the init_* methods. 
        Document.instance_methods.each do |method|
          self.send(method) if method.to_s.start_with?("init_")
        end
      else
        # Dynamically init from a mongo collection document.
        # TODO.
        @url = Wgit::Url.new(url_or_doc[:url])
        @html = url_or_doc[:html].nil? ? "" : url_or_doc[:html]
        @title = url_or_doc[:title]
        @author = url_or_doc[:author]
        @keywords = url_or_doc[:keywords].nil? ? [] : url_or_doc[:keywords]
        @links = url_or_doc[:links].nil? ? [] : url_or_doc[:links] 
        @links.map! { |link| Wgit::Url.new(link) }
        @text = url_or_doc[:text].nil? ? [] : url_or_doc[:text]
        @score = url_or_doc[:score].nil? ? 0.0 : url_or_doc[:score]
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
        ignore = include_html ? [] : [:@html]
        ignore << :@doc # Always ignore :@doc
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
      return [] if internal_links.empty?
      internal_links.map do |link|
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
    # functionality. Note that there is no way of getting the original text 
    # back however. 
    def search!(text)
      @text = search(text)
    end
    
    ### Document (Class) methods ###
    
    def self.text_elements
      @@text_elements
    end
    
    # Wrapper for Document#init_var (private method).
    # Initialises a private instance variable with the xpath result(s). 
    # A true singleton value will only ever return one result otherwise all 
    # xpath results are returned. A block if provided will be yielded with the 
    # created instance variable containing the results before being returned. 
    def self.define_extension(var, xpath, options = {}, &block)
      default_options = { singleton: true, text_content_only: true }
      options = default_options.merge(options)
      
      Document.send(:define_method, "init_#{var}") do
        init_var(var, xpath, 
                 options[:singleton], options[:text_content_only], 
                 &block)
      end
    end
    
    ### Default init_* methods. ###
    
  	def init_title
      xpath = "//title"
      init_var(:@title, xpath)
  	end
	
  	def init_author
      xpath = "//meta[@name='author']/@content"
      init_var(:@author, xpath)
  	end
	
  	def init_keywords
      xpath = "//meta[@name='keywords']/@content"
      init_var(:@keywords, xpath) do |keywords|
        if keywords
          keywords = keywords.split(",")
          process_arr(keywords)
        end
      end
  	end
    
    def init_links
      xpath = "//a/@href"
      init_var(:@links, xpath, false) do |links|
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
      end
    end
  
    def init_text
      xpath = text_elements_xpath
      init_var(:@text, xpath, false)
    end
	
    private
    
    # Initialises an instance variable and defines a getter method for it. 
    # The value of the instance variable will be the xpath result. 
    # If no xpath results are found the variable will have a value of nil for 
    # singleton vars or an empty array for non singleton vars. The result 
    # will be processed by either process_str or process_arr depending on 
    # the singleton value. Both of these methods are type safe. 
    # Yields the init variable to a given block before returning. 
    # 
    # @param [Symbol] var is the name of the variable to be initialised. 
    # @param [String] xpath is used to find the element(s). 
    # @param [Boolean] singleton determines whether or not the result(s) should 
    # be in an Array. If multiple results are found and singleton is true then 
    # the first result will be used. 
    # @param [Boolean] text_content_only if true will use the text content of 
    # the Nokogiri result object, otherwise the Nokogiri object itself is 
    # returned. 
    # @return [Object] the newly init variable's value containing the xpath 
    # result(s). 
    def init_var(var, xpath, singleton = true, text_content_only = true)
		  results = @doc.xpath(xpath)        
      if results and not results.empty?
        result = if singleton
                   text_content_only ? results.first.content : results.first
                 else
                   text_content_only ? results.map { |res| res.content } : results
                 end
      else
        result = singleton ? nil : []
      end
      
      # instance_var_name starts with @, var_name doesn't. 
      var = var.to_s
      var_name = (var.start_with?("@") ? var[1..-1] : var).to_sym
      instance_var_name = "@#{var_name}".to_sym
      
      instance_variable_set(instance_var_name, result)
      inst_var = instance_variable_get(instance_var_name)
      
      Document.send(:define_method, var_name) do
        inst_var
      end
      
      singleton ? process_str(inst_var) : process_arr(inst_var)
      
      yield inst_var if block_given?
      inst_var
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
      if str.is_a? String
        str.encode!('UTF-8', 'UTF-8', :invalid => :replace)
        str.strip!
      end
      str
    end

    def process_arr(array)
        if array.is_a? Array
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
    
  	alias :to_hash :to_h
    alias :relative_links :internal_links
    alias :relative_urls :internal_links
    alias :relative_full_links :internal_full_links
    alias :relative_full_urls :internal_full_links
    alias :external_urls :external_links
  end
end
