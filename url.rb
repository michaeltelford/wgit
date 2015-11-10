require 'uri'

# @author Michael Telford
# Class modeling a web based URL.
class Url < String
    def initialize(url)
        Url.validate(url)
        @uri = URI(url)
        super
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
    
    def to_uri
        @uri
    end
    
    def to_host
        @uri.host
    end
    
    def concat(link)
        url = self.dup
        url.chop! if url.end_with?("/")
        link = link[1..-1] if link.start_with?("/")
        url + "/" + link
    end
end
