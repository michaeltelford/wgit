require_relative 'utils'
require 'uri'

# @author Michael Telford
# Class modeling a web based URL.
class Url < String
    attr_accessor :source, :crawled, :date_crawled
    
    def initialize(url, source = nil, crawled = false, date_crawled = nil)
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
end
