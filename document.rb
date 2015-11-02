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
        Hash[instance_variables.map { |name| 
            [name, instance_variable_get(name)]
        }]
    end
	
	private
	
	def init_title(html)
		raise unless html.respond_to?(:xpath)
		results = html.xpath("//title")
        unless results.nil? or results.empty?
            @title = results.first.content
        end
	end
	
	def init_author(html)
		raise unless html.respond_to?(:xpath)
		results = html.xpath("//meta[@name='author']/@content")
        unless results.nil? or results.empty?
            @author = results.first.content
        end
	end
	
	def init_keywords(html)
		raise unless html.respond_to?(:xpath)
		results = html.xpath("//meta[@name='keywords']/@content")
        unless results.nil? or results.empty?
            @keywords = results.first.content
        end
	end
    
    def init_links(html)
       # 
    end
    
    def init_text(html)
        #
    end
end
