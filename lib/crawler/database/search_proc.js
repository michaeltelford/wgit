db.system.js.save({"_id":"search", "value":function(text, limit, skip, case_sensitive, whole_sentenance, whole_word, sort) {
    if (typeof text === 'undefined' || text.trim().length === 0) { throw "The text param must be provided"; }
    text = text.trim();
    
    // Set param defaults.
    limit               = typeof limit !== 'undefined' ? limit                          : 10;
    skip                = typeof skip !== 'undefined' ? skip                            : 0;
    case_sensitive      = typeof case_sensitive !== 'undefined' ? case_sensitive        : false;
    whole_sentenance    = typeof whole_sentenance !== 'undefined' ? whole_sentenance    : false;
    whole_word          = typeof whole_word !== 'undefined' ? whole_word                : false;
    sort                = typeof sort !== 'undefined' ? sort                            : {}
    
    // Search for matching docs.
    var docs = [];
    var query = { $text : { $search : text } }
    var cursor = db.documents.find(query);
    while (cursor.hasNext()) {
        docs.push(cursor.next());
    }
    
    // Apply search ranking algorithm.
    // TODO.
    
    return docs;
}});