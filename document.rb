require_relative 'url'
require 'nokogiri'

# @author Michael Telford
# Class modeling a HTML web document.
class Document
    TEXT_ELEMENTS = [:dd, :div, :dl, :dt, :figcaption, :figure, :hr, :li, 
                     :main, :ol, :p, :pre, :ul, :span]
    
	attr_reader :url, :html, :title, :author, :keywords, :links, :text
	
	def initialize(url, html)
        raise "url must be a Url object" unless url.is_a?(Url)
        
        @url = url
        @html = html
		
        doc = Nokogiri::HTML(html)
		
        init_title(doc)
		init_author(doc)
		init_keywords(doc)
        init_links(doc)
        init_text(doc)
	end
	
	def internal_links
		@links.reject { |link| not link.start_with?(@url) }
	end
	
	def external_links
		@links.reject { |link| link.start_with?(@url) }
	end
    
    def stats
        hash = {}
        instance_variables.each do |var|
            # Add up the total bytes of text.
            if var == :@text
                count = 0
                @text.each { |t| count = count + t.length }
                hash[var[1..-1]] = count
            # Else take the #length method return value.
            else
                next unless instance_variable_get(var).respond_to?(:length)
                hash[var[1..-1]] = instance_variable_get(var).send(:length)
            end
        end
        hash
    end
    
    def to_hash(include_html = true)
        hash = {}
        instance_variables.each do |var|
            next if not include_html and var == :@html
            hash[var[1..-1]] = instance_variable_get(var)
        end
        hash
    end
    
    def search(text)
        results = []
        @text.each do |t|
            if match = t.match(Regexp.new(text))
                results << match.string
            end
        end
        results
    end
	
	private
    
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
        unless results.nil? or results.empty?
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
        if @keywords.is_a?(Array)
            @keywords = @keywords.split(",")
            @keywords.map { |keyword| keyword.strip! }
        end
	end
    
    def init_links(doc)
        xpath = "//a/@href"
        init_var(doc, xpath, :@links, false)
        if @links.is_a?(Array)
            @links.reject! { |l| l.empty? or l == "/" }
            @links.map do |link| 
                link.replace(@url.concat(link)) if Url.relative_link?(link)
            end
        end
    end
    
    def init_text(doc)
        xpath = text_elements_xpath
        init_var(doc, xpath, :@text, false)
        if @text.is_a?(Array)
            @text.map { |t| t.strip! }
            @text.reject! { |t| t.empty? }
        end
    end
    
    alias :length :stats
    alias :count :stats
	alias :to_h :to_hash
end
