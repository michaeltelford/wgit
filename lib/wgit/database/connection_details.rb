require_relative '../assertable'

module Wgit
  extend Assertable

  # The connection details for the database. This must be set if you want to
  # store and access webpages in a database. Don't set the constant directly,
  # instead use the funcs contained within the Wgit module.
  CONNECTION_DETAILS = {}

  # The keys required for a successful database connection.
  CONNECTION_KEYS_REQUIRED = [
    'DB_HOST', 'DB_PORT', 'DB_USERNAME', 'DB_PASSWORD', 'DB_DATABASE'
  ]

  # Set the database's connection details from the given hash. It is your
  # responsibility to ensure the correct hash vars are present and set.
  #
  # @param hash [Hash] Containing the database connection details to use.
  #   The hash should contain the following keys (of type String):
  #   DB_HOST, DB_PORT, DB_USERNAME, DB_PASSWORD, DB_DATABASE
  # @raise [KeyError] If any of the required connection details are missing.
  # @return [Hash] Containing the database connection details from hash.
  def self.set_connection_details(hash)
    assert_required_keys(hash, CONNECTION_KEYS_REQUIRED)

    CONNECTION_DETAILS[:host]  = hash.fetch('DB_HOST')
    CONNECTION_DETAILS[:port]  = hash.fetch('DB_PORT')
    CONNECTION_DETAILS[:uname] = hash.fetch('DB_USERNAME')
    CONNECTION_DETAILS[:pword] = hash.fetch('DB_PASSWORD')
    CONNECTION_DETAILS[:db]    = hash.fetch('DB_DATABASE')

    CONNECTION_DETAILS
  end

  # Set the database's connection details from the ENV. It is your
  # responsibility to ensure the correct ENV vars are present and set.
  #
  # The ENV should contain the following keys (of type String):
  # DB_HOST, DB_PORT, DB_USERNAME, DB_PASSWORD, DB_DATABASE
  #
  # @raise [KeyError] If any of the required connection details are missing.
  # @return [Hash] Containing the database connection details from the ENV.
  def self.set_connection_details_from_env
    self.set_connection_details(ENV)
  end
end
