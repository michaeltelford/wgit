require_relative 'url'
require 'net/http'

if __FILE__ == $0
    base = "http://idropzone-mtelford.rhcloud.com/"
    links = ["http://www.google.co.uk", "/view/dz_register.php", "search.php?k=netbeans-php"]
    
    links.each do |url|
        puts "\nProcessing: #{url}"
        uri = URI(url)
        Net::HTTP.start(URI(base).host, 80) do |http|
            begin
                # raises ex if link is bogus.
                request = Net::HTTP::Get.new(uri)
            rescue
                puts "Link is bogus! Trying with base..."
                url = base.dup
                Url.concat!(url, uri.to_s)
                
                puts "Processing: #{url}"
                uri = URI(url)
                
                begin
                    request = Net::HTTP::Get.new(uri)
                rescue
                    puts "Link with base is bogus: #{uri.to_s}"
                end
            ensure
                raise if request.nil?
                
                response = http.request(request) # Net::HTTPResponse object
                
                if response.is_a?(Net::HTTPSuccess)
                    puts "Crawled link successfully."
                else
                    puts "Failed to crawl link."
                end
            end
        end
    end
end
