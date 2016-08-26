require_relative 'url'

# @author Michael Telford
# Script which extends Ruby's core functionality when parsed.
# Needs to required separately using `require 'wgit/core_ext'`. 

class String
  # Converts a String into a Wgit::Url object. 
  def to_url
    Wgit::Url.new(self)
  end
end
