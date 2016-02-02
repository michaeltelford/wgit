
DB_PROVIDER = :OpenShift

# OpenShift
if DB_PROVIDER == :OpenShift
    CONNECTION_DETAILS = {
        :host           => "127.0.0.1",
        :port           => "27017",
        :db             => "admin",
        :uname          => "admin",
        :pword          => "R5jUKv1fessb"
    }
# MongoLabs
elsif DB_PROVIDER == :MongoLabs
    CONNECTION_DETAILS = {
        :host           => "ds037205.mongolab.com",
        :port           => "37205",
        :db             => "crawler",
        :uname          => "rubyapp",
        :pword          => "R5jUKv1fessb",
    }
else
    raise "Database provider '#{DB_PROVIDER}' is not recognized"
end
