# frozen_string_literal: true

require_relative '../assertable'

module Wgit
  extend Assertable

  # The connection details for the database. This must be set if you want to
  # store and access webpages in a database. Don't set the constant directly,
  # instead use the funcs contained within the Wgit module.
  CONNECTION_DETAILS = {}

  # The keys required for a successful database connection.
  CONNECTION_KEYS_REQUIRED = ['DB_CONNECTION_STRING'].freeze

  # Set the database's connection details from the given hash. It is your
  # responsibility to ensure the correct hash vars are present and set.
  #
  # @param hash [Hash] Containing the database connection details to use.
  #   The hash should contain the following keys (of type String):
  #   DB_CONNECTION_STRING
  # @raise [KeyError] If any of the required connection details are missing.
  # @return [Hash] Containing the database connection details from hash.
  def self.set_connection_details(hash)
    assert_required_keys(hash, CONNECTION_KEYS_REQUIRED)
    CONNECTION_DETAILS[:connection_string] = hash.fetch('DB_CONNECTION_STRING')
    CONNECTION_DETAILS
  end

  # Set the database's connection details from the ENV. It is your
  # responsibility to ensure the correct ENV vars are present and set.
  #
  # The ENV should contain the following keys (of type String):
  # DB_CONNECTION_STRING
  #
  # @raise [KeyError] If any of the required connection details are missing.
  # @return [Hash] Containing the database connection details from the ENV.
  def self.set_connection_details_from_env
    set_connection_details(ENV)
  end
end
