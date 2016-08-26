
# @author Michael Telford
module Wgit
  DB_PROVIDER = :MongoLabs.freeze

  # OpenShift (MongoDB 2.4)
  if DB_PROVIDER == :OpenShift
    CONNECTION_DETAILS = {
      :host           => "127.0.0.1",
      :port           => "27017",
      :db             => "admin",
      :uname          => "admin",
      :pword          => "R5jUKv1fessb"
    }.freeze
  # MongoLabs (MongoDB 3.0)
  elsif DB_PROVIDER == :MongoLabs
    CONNECTION_DETAILS = {
      :host           => "ds037205.mongolab.com",
      :port           => "37205",
      :db             => "crawler",
      :uname          => "rubyapp",
      :pword          => "R5jUKv1fessb",
    }.freeze
  else
    raise "Database provider '#{DB_PROVIDER}' is not recognized"
  end
end
