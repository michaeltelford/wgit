# @author Michael Telford
# Class modeling a web based URL.
class Url < String
    def initialize(url)
        super
    end
    
	def to_url
		url = self.dup
		unless self.start_with?("http://") or self.start_with?("https://")
			url = "http://" + url
		end
		unless self.end_with?("/")
			url = url + "/"
		end
		url
	end
	
	def to_s
		url = self.dup
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
end
