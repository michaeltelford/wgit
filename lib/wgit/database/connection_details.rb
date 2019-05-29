module Wgit
  # The connection details for the database. This must be set if you want to
  # store and access webpages in a database. Don't set the constant directly,
  # instead use the funcs contained within the Wgit module.
  CONNECTION_DETAILS = {}

  # Set the database's connection details from the given hash and freeze them.
  # It is your responsibility to ensure the correct hash vars are present and
  # set. Due to the freezing of the CONNECTION_DETAILS, this func is designed
  # to be called only once.
  #
  # @param hash [Hash] Containing the database connection details to use.
  #   The hash should contain the following keys (of type String):
  #   host, port, uname, pword, db
  # @raise [KeyError, FrozenError] If any of the required connection
  #   details are missing or if the connection details have already been set.
  # @return [Hash] Containing the database connection details from hash.
  def self.set_connection_details(hash)
    CONNECTION_DETAILS[:host]   = hash.fetch('host')
    CONNECTION_DETAILS[:port]   = hash.fetch('port')
    CONNECTION_DETAILS[:uname]  = hash.fetch('uname')
    CONNECTION_DETAILS[:pword]  = hash.fetch('pword')
    CONNECTION_DETAILS[:db]     = hash.fetch('db')

    CONNECTION_DETAILS.freeze
  end

  # Set the database's connection details from the ENV and freeze them. It is
  # your responsibility to ensure the correct ENV vars are present and set.
  # Due to the freezing of the CONNECTION_DETAILS, this func is designed to be
  # called only once.
  #
  # The ENV should contain the following keys (of type String):
  # DB_HOST, DB_PORT, DB_USERNAME, DB_PASSWORD, DB_DATABASE
  #
  # @raise [KeyError, FrozenError] If any of the required connection
  #   details are missing or if the connection details have already been set.
  # @return [Hash] Containing the database connection details from the ENV.
  def self.set_connection_details_from_env
    CONNECTION_DETAILS[:host]   = ENV.fetch('DB_HOST')
    CONNECTION_DETAILS[:port]   = ENV.fetch('DB_PORT')
    CONNECTION_DETAILS[:uname]  = ENV.fetch('DB_USERNAME')
    CONNECTION_DETAILS[:pword]  = ENV.fetch('DB_PASSWORD')
    CONNECTION_DETAILS[:db]     = ENV.fetch('DB_DATABASE')

    CONNECTION_DETAILS.freeze
  end
end
