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
      'DB_HOST'     => 'blah.mongolab.com',
      'DB_PORT'     => '12345',
      'DB_USERNAME' => 'minitest',
      'DB_PASSWORD' => 'rocks!!!',
      'DB_DATABASE' => 'test',
    }
    expected = {
      host:  'blah.mongolab.com',
      port:  '12345',
      uname: 'minitest',
      pword: 'rocks!!!',
      db:    'test',
    }
    assert_equal(expected, Wgit.set_connection_details(h))
    # Test that we can reset the connection if required.
    assert_equal(expected, Wgit.set_connection_details(h))
  end

  def test_set_connection_details_fails
    req_keys = 'DB_HOST, DB_PORT, DB_USERNAME, DB_PASSWORD, DB_DATABASE'
    h = {
      'DB_HOST'     => 'blah.mongolab.com',
      'DB_PORT'     => '12345',
      'DB_USERNAME' => 'minitest',
      # 'DB_PASSWORD' => 'rocks!!!', Required.
      'DB_DATABASE' => 'test',
    }
    
    ex = assert_raises(KeyError) { Wgit.set_connection_details(h) }
    assert_equal(
      "Some or all of the required keys are not present: #{req_keys}",
      ex.message
    )
  end

  def test_set_connection_details_from_env
    assert_equal([
      :host, :port, :uname, :pword, :db
    ], Wgit.set_connection_details_from_env.keys)
  end
end
