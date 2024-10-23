# frozen_string_literal: true

# Script which extends Ruby's core functionality when parsed.
# Needs to be required separately to 'wgit' using `require 'wgit/core_ext'`.

require_relative "url"

# Extend the standard String functionality.
class String
  # Converts a String into a Wgit::Url object.
  #
  # @return [Wgit::Url] The converted URL.
  def to_url
    Wgit::Url.parse(self)
  end
end

# Extend the standard Enumerable functionality.
module Enumerable
  # Converts each String instance into a Wgit::Url object and returns the new
  # Array.
  #
  # @return [Array<Wgit::Url>] The converted URL's.
  def to_urls
    map { |element| process_url_element(element) }
  end

  # Converts each String instance into a Wgit::Url object and returns self
  # having modified the receiver.
  #
  # @return [Array<Wgit::Url>] Self containing the converted URL's.
  def to_urls!
    map! { |element| process_url_element(element) }
  end
end

private

# Converts the element to a Wgit::Url if the element is a String.
def process_url_element(element)
  element.is_a?(String) ? element.to_url : element
end
