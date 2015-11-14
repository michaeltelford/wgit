# @author Michael Telford
# Module containing the DB data model structure.
module Model
    def self.url(url, source = nil, crawled = false, date_crawled = nil)
        {
            :url            => url,
            :source         => source,
            :crawled        => crawled,
            :date_crawled   => date_crawled
        }
    end
    
    def self.document(doc)
        raise "doc must respond to to_hash" unless doc.respond_to?(:to_hash)
        doc.to_hash(false)
    end
    
    def self.common_insert_data
        {
            :date_added     => Model.time_stamp,
            :date_modified  => Model.time_stamp
        }
    end
    
    def self.time_stamp
        Time.new.strftime("%Y-%m-%d %H:%M:%S").to_s
    end
end
