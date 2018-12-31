require_relative "helpers/test_helper"

# Test class for the load script (used in dev).
class TestLoad < TestHelper
  # Runs before every test.
  def setup
  end
  
  def test_load
    # TODO: Supress the load output by writing it to a file.
    assert load 'load.rb'
  end
end
