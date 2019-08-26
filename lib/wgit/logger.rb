# FYI: The default logger is set at the bottom of this file.

require 'logger'

module Wgit
  # The Logger instance used by Wgit. Set your own custom logger after
  # requiring this file if needed.
  @logger = nil

  # Returns the current Logger instance.
  # @return [Logger] The current Logger instance.
  def self.logger
    @logger
  end

  # Sets the current Logger instance.
  # @param logger [Logger] The Logger instance to use.
  # @return [Logger] The current Logger instance having being set.
  def self.logger=(logger)
    @logger = logger
  end

  # Returns the default Logger instance.
  # @return [Logger] The default Logger instance.
  def self.default_logger
    logger = Logger.new(STDOUT, progname: 'wgit', level: :info)
    logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{progname}] #{msg}\n"
    end
    logger
  end

  # Sets the default Logger instance to be used by Wgit.
  # @return [Logger] The default Logger instance.
  def self.use_default_logger
    @logger = self.default_logger
  end
end

Wgit.use_default_logger
