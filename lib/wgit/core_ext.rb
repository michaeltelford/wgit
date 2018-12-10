require_relative 'url'

# Script which extends Ruby's core functionality when parsed.
# Needs to be required separately using `require 'wgit/core_ext'`.

class String
  # Converts a String into a Wgit::Url object.
  #
  # @return [Wgit::Url] The converted URL.
  def to_url
    Wgit::Url.new(self)
  end
end

module Enumerable
  # Converts each String instance into a Wgit::Url object and returns the new 
  # Array.
  #
  # @return [Array<Wgit::Url>] The converted URL's.
  def to_urls
    map do |element|
      process_url_element(element)
    end
  end
  
  # Converts each String instance into a Wgit::Url object and returns the 
  # updated array. Modifies the receiver.
  #
  # @return [Array<Wgit::Url>] Self containing the converted URL's.
  def to_urls!
    map! do |element|
      process_url_element(element)
    end
  end
end

private

# Converts the element to a Wgit::Url if the element is a String.
def process_url_element(element)
  if element.is_a? String
    element.to_url
  else
    element
  end
end
