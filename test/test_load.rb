require "minitest/autorun"

# @author Michael Telford
class TestLoad < Minitest::Test
    def setup
        # Runs before every test.
    end
    
    def test_load
        # TODO: Supress the load output.
        #assert load 'load.rb'
    rescue LoadError => ex
        flunk ex.message
    end
end
