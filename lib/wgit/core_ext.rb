require_relative 'url'

# @author Michael Telford
# Script which extends Ruby's core functionality when parsed.
# Needs to be required separately using `require 'wgit/core_ext'`. 

class String
  # Converts a String into a Wgit::Url object. 
  def to_url
    Wgit::Url.new(self)
  end
end

module Enumerable
  # Converts each String instance into a Wgit::Url object and returns the new 
  # array. 
  def to_urls
    map do |element|
      process_url_element(element)
    end
  end
  
  # Converts each String instance into a Wgit::Url object and returns the 
  # updated array. 
  def to_urls!
    map! do |element|
      process_url_element(element)
    end
  end
end

private

def process_url_element(element)
  if element.is_a? String
    element.to_url
  else
    element
  end
end
