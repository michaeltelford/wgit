# frozen_string_literal: true

# Wgit is a WWW indexer/scraper which crawls URL's and retrieves their page
# contents for later use.
#
# @author Michael Telford
module Wgit
  # The current gem version of Wgit.
  VERSION = '0.10.2'

  # Returns the current gem version of Wgit as a String.
  def self.version
    VERSION
  end

  # Returns the current gem version in a presentation String.
  def self.version_str
    "wgit v#{VERSION}"
  end
end
