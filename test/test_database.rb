require "minitest/autorun"
require_relative "helpers/test_helper"
require_relative "helpers/test_database_helper"

# @author Michael Telford
class TestDatabase < Minitest::Test
  include TestDatabaseHelper
  
  # Runs before every test.
  def setup
    #
  end
end
