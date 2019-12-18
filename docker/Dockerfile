FROM mongo:4.2

ENV MONGO_INITDB_ROOT_USERNAME rubyapp
ENV MONGO_INITDB_ROOT_PASSWORD abcdef
ENV MONGO_INITDB_DATABASE admin

COPY mongo-init.js /docker-entrypoint-initdb.d/
