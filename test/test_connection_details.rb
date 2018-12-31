require_relative "helpers/test_helper"

# Test class for the DB connection details funcs.
class TestConnectionDetails < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test and clears the connection details.
  def setup
    load 'lib/wgit/database/mongo_connection_details.rb'
  end

  # Runs after every test and sets the correct connection details for other
  # tests.
  def teardown
    load 'lib/wgit/database/mongo_connection_details.rb'
    Wgit.set_connection_details_from_env
  end
  
  def test_set_connection_details
    h = {
      'host'  => "blah.mongolab.com",
      'port'  => "12345",
      'uname' => "minitest",
      'pword' => "rocks!!!",
      'db'    => "test",
    }
    
    assert_equal({
      host:   "blah.mongolab.com",
      port:   "12345",
      uname:  "minitest",
      pword:  "rocks!!!",
      db:     "test",
    }, Wgit.set_connection_details(h))
    assert_raises(FrozenError) { Wgit.set_connection_details(h) }
  end

  def test_set_connection_details_fails
    h = {
      'host'  => "blah.mongolab.com",
      'port'  => "12345",
      'uname' => "minitest",
      # 'pword' => "rocks!!!", Required.
      'db'    => "test",
    }
    
    assert_raises(KeyError) { Wgit.set_connection_details(h) }
  end

  def test_set_connection_details_from_env
    assert_equal([
      :host, :port, :uname, :pword, :db
    ], Wgit.set_connection_details_from_env.keys)
    assert_raises(FrozenError) { Wgit.set_connection_details_from_env }
  end
end
