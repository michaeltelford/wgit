require_relative 'url'
require_relative 'utils'
require_relative 'assertable'
require 'nokogiri'

# @author Michael Telford
# Class modeling a HTML web document. Also doubles as a search result.
class Document
    include Assertable
    
    TEXT_ELEMENTS = [:dd, :div, :dl, :dt, :figcaption, :figure, :hr, :li, 
                     :main, :ol, :p, :pre, :span, :ul, :h1, :h2, :h3, :h4, :h5]
    
	attr_reader :url, :html, :title, :author, :keywords, :links, :text, :score
	
	def initialize(url_or_doc, html = nil)
        if (url_or_doc.is_a?(String))
            assert_type(url_or_doc, Url)
            html ||= ""
        
            @url = url_or_doc
            @html = html
		
            doc = Nokogiri::HTML(html) do |config|
                # TODO: Remove #'s below when running in production.
                #config.options = Nokogiri::XML::ParseOptions::STRICT | 
                #                 Nokogiri::XML::ParseOptions::NONET
            end
		
            init_title(doc)
    		init_author(doc)
    		init_keywords(doc)
            init_links(doc)
            init_text(doc)
            # :score is only init from a mongo doc.
        else
            # Init from a mongo collection document.
            @url = Url.new(url_or_doc[:url])
            @html = url_or_doc[:html]
            @title = url_or_doc[:title]
            @author = url_or_doc[:author]
            @keywords = url_or_doc[:keywords].nil? ? [] : url_or_doc[:keywords]
            @links = url_or_doc[:links].nil? ? [] : url_or_doc[:links] 
            @links.map! { |link| Url.new(link) }
            @text = url_or_doc[:text].nil? ? [] : url_or_doc[:text]
            @score = url_or_doc[:score].nil? ? 0.0 : url_or_doc[:score]
        end
	end
	
	def internal_links
        return [] if @links.nil?
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
            @url.to_base + link
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
                hash[var[1..-1].to_sym] = instance_variable_get(var).send(:length)
            end
        end
        hash
    end
    
    def size
        stats[:html]
    end
    
    def to_h(include_html = false)
        ignore = include_html ? [] : [:@html]
        Utils.to_h(self, ignore)
    end
    
    def empty?
        html.strip.empty?
    end
    
    # Searches against the Document#text for the given search text.
    # The number of search hits for each sentenence are recorded internally 
    # and used to rank/sort the search results before being returned. Where 
    # the Database#search method search all documents for the most hits this 
    # method search each documents text for the most hits. 
    #
    # Each search result comprises of a sentence of a given length (based on 
    # the sentence_length parameter). The algorithm ensures that the search 
    # value is at the centre of the sentence and that there is at 
    # least one instance of the search text value in the sentence. 
    #
    # @param text [String] the value to search the document text against.
    # @param sentence_length [Fixnum] the length of each search result 
    # sentence. 
    # 
    # @return [Array] of String objects representing the search results.
    def search(text, sentence_length = 80)
        results = {}
        regex = Regexp.new(text, Regexp::IGNORECASE)
        
        @text.each do |sentence|
            hits = sentence.scan(regex).count
            if hits > 0
                index = sentence.index(regex)
                start = index - (sentence_length / 2)
                finish = index + (sentence_length / 2)
                results[sentence[start..finish].strip] = hits
            end
        end
        
        return [] if results.empty?
        results = Hash[results.sort_by { |k, v| v }]
        results.keys.reverse
    end
    
    def search!(text)
        @text = search(text)
    end
	
private

    def process(array)
        assert_arr_types(array, String)
        array.map! { |str| str.strip }
        array.reject! { |str| str.empty? }
        array.uniq!
    end
    
    def text_elements_xpath
        xpath = ""
        return xpath if TEXT_ELEMENTS.empty?
        el_xpath = "//%s/text()"
        TEXT_ELEMENTS.each_with_index do |el, i|
            xpath += " | " unless i == 0
            xpath += el_xpath % [el]
        end
        xpath
    end
    
    def init_var(doc, xpath, var, first_result = true)
		raise unless doc.respond_to?(:xpath)
		results = doc.xpath(xpath)        
        unless results.nil? || results.empty?
            result = if first_result
                         results.first.content
                     else
                         results.map { |res| res.content }
                     end
            instance_variable_set(var, result)
        end
    end
	
	def init_title(doc)
        xpath = "//title"
        init_var(doc, xpath, :@title)
	end
	
	def init_author(doc)
        xpath = "//meta[@name='author']/@content"
        init_var(doc, xpath, :@author)
	end
	
	def init_keywords(doc)
        xpath = "//meta[@name='keywords']/@content"
        init_var(doc, xpath, :@keywords)
        return @keywords = [] unless @keywords
        @keywords = @keywords.split(",")
        process(@keywords)
	end
    
    def init_links(doc)
        xpath = "//a/@href"
        init_var(doc, xpath, :@links, false)
        return @links = [] unless @links
        process(@links)
        @links.reject! { |link| link == "/" }
        @links.map! do |link|
            begin
                Url.new(link)
            rescue
                nil
            end
        end
        @links.reject! { |link| link.nil? }
    end
    
    def init_text(doc)
        xpath = text_elements_xpath
        init_var(doc, xpath, :@text, false)
        return @text = [] unless @text
        process(@text)
    end
    
	alias :to_hash :to_h
    alias :relative_links :internal_links
end
