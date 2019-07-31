require_relative 'helpers/test_helper'

# Test class for the DB connection details funcs.
class TestConnectionDetails < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test and clears the connection details.
  def setup
    load 'lib/wgit/database/connection_details.rb'
  end

  # Runs after every test and sets the correct connection details for other
  # tests.
  def teardown
    load 'lib/wgit/database/connection_details.rb'
    Wgit.set_connection_details_from_env
  end

  def test_set_connection_details
    h = {
      'DB_CONNECTION_STRING' => 'mongodb://me:pass@server.com:27017/test',
    }
    expected = {
      connection_string: 'mongodb://me:pass@server.com:27017/test',
    }

    assert_equal(expected, Wgit.set_connection_details(h))
    # Test that we can reset the connection if required.
    assert_equal(expected, Wgit.set_connection_details(h))
  end

  def test_set_connection_details_fails
    req_keys = 'DB_CONNECTION_STRING'
    h = {
      'DB_HOST' => 'blah.mongolab.com', # Missing connection string.
    }

    ex = assert_raises(KeyError) { Wgit.set_connection_details(h) }
    assert_equal(
      "Some or all of the required keys are not present: #{req_keys}",
      ex.message
    )
  end

  def test_set_connection_details_from_env
    assert_equal([
      :connection_string
    ], Wgit.set_connection_details_from_env.keys)
  end
end
