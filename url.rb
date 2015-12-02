require_relative 'utils'
require 'uri'

# @author Michael Telford
# Class modeling a web based URL.
class Url < String
    attr_accessor :source, :crawled, :date_crawled
    
    def initialize(url_or_doc, source = nil, crawled = false, date_crawled = nil)
        if (url_or_doc.is_a?(String))
            url = url_or_doc
        else
            # Init from a mongo collection document.
            url = url_or_doc[:url]
            source = url_or_doc[:source]
            crawled = url_or_doc[:crawled]
            crawled = false if crawled.nil?
            date_crawled = url_or_doc[:date_crawled]
        end
        Url.validate(url)
        @uri = URI(url)
        @source = source
        @crawled = crawled
        @date_crawled = date_crawled
        super(url)
    end
    
    def self.validate(url)
        unless url.start_with?("http://") or url.start_with?("https://")
            raise "Invalid url (missing protocol prefix): #{url}"
        end
        if URI.regexp.match(url).nil?
            raise "Invalid url: #{url}"
        end
        true
    end
    
    def self.relative_link?(link)
        link_host = URI.split(link)[2]
        link_host.to_s.strip.empty?
    end
    
    def self.prefix_protocol!(url, secure = false)
        unless url.start_with?("http://") or url.start_with?("https://")
            if secure
                url.replace("https://#{url}")
            else
                url.replace("http://#{url}")
            end
        end
    end
    
    def crawled=(bool)
        @crawled = bool
        @date_crawled = Utils.time_stamp if bool
    end
    
    def to_uri
        @uri
    end
    
    def to_host
        @uri.host
    end
    
    def to_h
        ignore = [:@uri]
        h = Utils.to_h(self, ignore)
        Hash[h.to_a.insert(0, ["url", self])] # Insert url at position 0.
    end
    
    def concat(link)
        url = self.dup
        url.chop! if url.end_with?("/")
        link = link[1..-1] if link.start_with?("/")
        url + "/" + link
    end
    
    alias :to_hash :to_h
    alias :host :to_host
end
