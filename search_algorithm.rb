# @author Michael Telford
# Class for implementing search algorithm logic which should be applied to a 
# set of search results.
class SearchAlgorithm
    def self.most_text_hits!(results)
        results.sort_by! { |doc| doc.text.length }
        results.reverse! # Most hits first.
    end
end
