require 'nokogiri'

# @author Michael Telford
# Class modeling a HTML web document.
class Document
    # Element list contains all text (currently only text) elements from:
    # https://developer.mozilla.org/en-US/docs/Web/HTML/Element
    TEXT_ELEMENTS = [:dd, :div, :dl, :dt, :figcaption, :figure, :hr, :li, 
                     :main, :ol, :p, :pre, :ul]
    
	attr_reader :url, :html, :title, :author, :keywords, :links, :text
	
	def initialize(url, html)
        @url = url
        @html = html
		
        doc = Nokogiri::HTML(html)
		
        init_title(doc)
		init_author(doc)
		init_keywords(doc)
        init_links(doc)
        init_text(doc)
	end
    
    def to_hash(include_html = true)
        Hash[instance_variables.map do |name| 
            next if not include_html and name == "@html"
            [name[1..-1], instance_variable_get(name)]
        end]
    end
    
	def save
		yield self
	end
	
	private
    
    def text_elements_xpath
        xpath = ""
        return xpath if TEXT_ELEMENTS.empty?
        el_xpath = "//%s/text()"
        TEXT_ELEMENTS.each_with_index do |el, i|
            xpath += " | " unless i == 0
            xpath += el_xpath %[el]
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
    end
    
    def init_text(doc)
        xpath = text_elements_xpath
        init_var(doc, xpath, :@text, false)
        if @text.is_a?(Array)
            @text.map { |t| t.strip! }
            @text.reject! { |t| t.empty? }
        end
    end
end
