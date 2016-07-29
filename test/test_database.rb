require "minitest/autorun"
require_relative "helpers/test_helper"
require_relative "../lib/pinch/database/database_helper"

# @author Michael Telford
class TestDatabase < Minitest::Test
  include DatabaseHelper
  
  # Runs before every test.
  def setup
    #
  end
end
