require_relative "helpers/test_helper"

# Test class for the Wgit Logger methods.
class TestLogger < TestHelper
  # Runs before every test.
  def setup
  end

  def test_logger
    assert Wgit.logger.is_a?(Logger)
  end

  def test_logger=
    stdout = Logger.new STDOUT
    assert_equal stdout, Wgit.logger=(stdout)
  end

  def test_default_logger
    assert Wgit.default_logger.is_a?(Logger)
    assert_equal 1, Wgit.default_logger.level
    assert_equal 'wgit', Wgit.default_logger.progname
  end

  def test_use_default_logger
    assert Wgit.use_default_logger.is_a?(Logger)
  end

  # Runs after every test.
  def teardown
    Wgit.use_default_logger
    Wgit.logger.level = Logger::WARN
  end
end
