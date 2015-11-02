# @author Michael Telford
# Class modeling a collection of HTML web documents.
class Documents < Hash
	def initialize(default = nil)
		super
	end
    
    #def []=(url, value)
    #    raise "Url already exists" if self.has_key?(url)
    #    super
    #end
    
    def filter!(urls)
        urls = urls - self.keys
    end
end
