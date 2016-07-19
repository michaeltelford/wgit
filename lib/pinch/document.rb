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
		
            @doc = Nokogiri::HTML(html) do |config|
                # TODO: Remove #'s below when running in production.
                #config.options = Nokogiri::XML::ParseOptions::STRICT | 
                #                 Nokogiri::XML::ParseOptions::NONET
            end
		
            init_title
    		    init_author
    		    init_keywords
            init_links
            init_text
            @score = 0.0
        else
            # Init from a mongo collection document.
            @url = Url.new(url_or_doc[:url])
            @html = url_or_doc[:html].nil? ? "" : url_or_doc[:html]
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
            Url.new(@url.to_base + link)
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
                hash[var[1..-1].to_sym] = 
                                    instance_variable_get(var).send(:length)
            end
        end
        hash
    end
    
    def size
        stats[:html]
    end
    
    def to_h(include_html = false)
        ignore = include_html ? [] : [:@html]
        ignore << :@doc # Always ignore :@doc
        Utils.to_h(self, ignore)
    end
    
    def empty?
        html.strip.empty?
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
    # that the search value is visible somewher in the sentence.
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
                Utils.format_sentence_length(sentence, index, sentence_limit)
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
    
    # Uses Nokogiri's xpath method to search the doc's html and return the 
    # results. 
    def xpath(xpath)
  		@doc.xpath(xpath)
    end
	
private

    def process_str(str)
        str.encode!('UTF-8', 'UTF-8', :invalid => :replace)
        str.strip!
        str # This is required to return the str, do not remove.
    end

    def process_arr(array)
        assert_arr_types(array, String)
        array.map! { |str| process_str(str) }
        array.reject! { |str| str.empty? }
        array.uniq!
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
    
    def init_var(xpath, var, first_result = true)
		results = @doc.xpath(xpath)        
        unless results.nil? || results.empty?
            result = if first_result
                         results.first.content
                     else
                         results.map { |res| res.content }
                     end
            instance_variable_set(var, result)
        end
    end
	
	def init_title
    @title = nil
    xpath = "//title"
    init_var(xpath, :@title)
    process_str(@title) unless @title.nil?
	end
	
	def init_author
    @author = nil
    xpath = "//meta[@name='author']/@content"
    init_var(xpath, :@author)
    process_str(@author) unless @author.nil?
	end
	
	def init_keywords
    @keywords = nil
    xpath = "//meta[@name='keywords']/@content"
    init_var(xpath, :@keywords)
    return @keywords = [] unless @keywords
    @keywords = @keywords.split(",")
    process_arr(@keywords)
	end
    
  def init_links
    @links = nil
    xpath = "//a/@href"
    init_var(xpath, :@links, false)
    return @links = [] unless @links
    process_arr(@links)
    @links.reject! { |link| link == "/" }
    @links.map! do |link|
      begin
        Url.new(link)
      rescue
        nil
      end
    end
    @links.reject! { |link| link.nil? }
    process_internal_links(@links)
  end
  
  def init_text
    @text = nil
    xpath = text_elements_xpath
    init_var(xpath, :@text, false)
    return @text = [] unless @text
    process_arr(@text)
  end
    
	alias :to_hash :to_h
  alias :relative_links :internal_links
  alias :relative_full_links :internal_full_links
end
