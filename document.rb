require_relative 'url'
require_relative 'utils'
require 'nokogiri'

# @author Michael Telford
# Class modeling a HTML web document.
class Document
    TEXT_ELEMENTS = [:dd, :div, :dl, :dt, :figcaption, :figure, :hr, :li, 
                     :main, :ol, :p, :pre, :ul, :span]
    
	attr_reader :url, :html, :title, :author, :keywords, :links, :text
	
	def initialize(url, html)
        Utils.assert_type?([url], Url)
        Utils.assert_type?([html], String)
        
        @url = url
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
	end
	
	def internal_links
        return nil if @links.nil?
		@links.reject do |link|
            begin
                not link.relative_link?
            rescue
                true
            end
        end
	end
    
    def internal_full_links
        internal_links.map do |link|
            link.replace("/" + link) unless link[0] == "/"
            @url + link
        end
    end
	
	def external_links
        return nil if @links.nil?
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
                hash["text_length"] = @text.length
                hash["text_bytes"] = count
            # Else take the #length method return value.
            else
                next unless instance_variable_get(var).respond_to?(:length)
                hash[var[1..-1]] = instance_variable_get(var).send(:length)
            end
        end
        hash
    end
    
    def to_h(include_html = false)
        ignore = include_html ? [] : [:@html]
        Utils.to_h(self, ignore)
    end
    
    def search(text)
        results = []
        @text.each do |t|
            if match = t.match(Regexp.new(text, Regexp::IGNORECASE))
                results << match.string
            end
        end
        results
    end
	
private

    def process!(array)
        Utils.assert_type?(array, String)
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
        unless @keywords.nil?
            @keywords = @keywords.split(",")
            process!(@keywords)
        end
	end
    
    def init_links(doc)
        xpath = "//a/@href"
        init_var(doc, xpath, :@links, false)
        unless @links.nil?
            process!(@links)
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
    end
    
    def init_text(doc)
        xpath = text_elements_xpath
        init_var(doc, xpath, :@text, false)
        unless @text.nil?
            process!(@text)
        end
    end
    
    alias :length :stats
    alias :count :stats
	alias :to_hash :to_h
end
