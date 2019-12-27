db.auth("rubyapp", "abcdef");

db = db.getSiblingDB("crawler");

db.createUser({
  user: "rubyapp",
  pwd: "abcdef",
  roles: [
    {
      role: "root",
      db: "admin",
    },
  ],
});

db.createCollection("urls");
db.createCollection("documents");

db.urls.createIndex({ "url" : 1 }, { "unique" : true, "name": "unique_url" });
db.documents.createIndex({ "url.url" : 1 }, { "unique" : true, "name": "unique_url" });
db.documents.createIndex({
  "text": "text",
  "author": "text",
  "keywords": "text",
  "title": "text"
}, { "name": "text_search" });
