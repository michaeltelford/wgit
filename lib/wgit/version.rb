# frozen_string_literal: true

# Wgit is a WWW indexer/scraper which crawls URL's and retrieves their page
# contents for later use by serialisation.
# @author Michael Telford
module Wgit
  # The current gem version of Wgit.
  VERSION = '0.5.0'

  # Returns the current gem version of Wgit as a String.
  def self.version
    VERSION
  end
end
