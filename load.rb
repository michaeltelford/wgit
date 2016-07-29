load 'lib/pinch/main.rb' # Not the root level symlink main.rb
load 'lib/pinch/crawler.rb'
load 'lib/pinch/url.rb'
load 'lib/pinch/document.rb'
load 'lib/pinch/utils.rb'
load 'lib/pinch/assertable.rb'
load 'lib/pinch/database/database.rb'
load 'lib/pinch/database/model.rb'
load 'lib/pinch/database/mongo_connection_details.rb'
load 'lib/pinch/database/database_helper.rb'
load 'lib/pinch/database/database_default_data.rb'

include Assertable
include DatabaseHelper
