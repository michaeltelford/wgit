require 'nokogiri'

# @author Michael Telford
# Class modeling a HTML web document.
class Document
	attr_reader :url, :html, :title, :author, :keywords, :links, :text
	
	def initialize(url, html)
        @url = url
        @html = html
		
        nokogiri_doc = Nokogiri::HTML(html)
		
        init_title(nokogiri_doc)
		init_author(nokogiri_doc)
		init_keywords(nokogiri_doc)
        init_links(nokogiri_doc)
        init_text(nokogiri_doc)
	end
    
    def pretty_print
        Hash[instance_variables.map do |name| 
            [name[1..-1], instance_variable_get(name)]
        end]
    end
	
	private
    
    def init_var(html, xpath, var, first_result = true)
		raise unless html.respond_to?(:xpath)
		results = html.xpath(xpath)
        unless results.nil? or results.empty?
            result = if first_result
                         results.first.content
                     else
                         results.map { |res| res.content }
                     end
            instance_variable_set(var, result)
        end
    end
	
	def init_title(html)
        xpath = "//title"
        init_var(html, xpath, :@title)
	end
	
	def init_author(html)
        xpath = "//meta[@name='author']/@content"
        init_var(html, xpath, :@author)
	end
	
	def init_keywords(html)
        xpath = "//meta[@name='keywords']/@content"
        init_var(html, xpath, :@keywords)
        if @keywords.respond_to?(:split)
            @keywords = @keywords.split(",")
            @keywords.map { |keyword| keyword.strip! }
        end
	end
    
    def init_links(html)
        xpath = "//a/@href"
        init_var(html, xpath, :@links, false)
    end
    
    def init_text(html)
        xpath = "//*/text()"
        init_var(html, xpath, :@text, false)
        @text = @text.join("\n") if @text.respond_to?(:join)
    end
end
