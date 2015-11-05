require 'uri'

# @author Michael Telford
# Class modeling a web based URL.
class Url < String
    
    def initialize(url)
        url = Url.to_url(url)
		Url.validate(url)
        super
    end
    
	def self.to_url(host)
        url = host.dup.strip
		unless host.start_with?("http://") or host.start_with?("https://")
			url = "http://" + url
		end
		unless host.end_with?("/")
			url = url + "/"
		end
		url
	end
	
	def self.validate(url)
		if URI.regexp.match(url).nil?
			raise "Invalid url: #{url}"
		end
		true
	end
    
	def to_url
		url = self.dup.strip
		unless self.start_with?("http://") or self.start_with?("https://")
			url = "http://" + url
		end
		unless self.end_with?("/")
			url = url + "/"
		end
		url
	end
	
	def to_host
		url = self.dup.strip
		if self.start_with?("http://")
			url = url[7..-1]
        elsif self.start_with?("https://")
			url = url[8..-1]
		end
		if self.end_with?("/")
			url = url[0..-2]
		end
		url
    end
	
	def save
		yield self
	end
end
