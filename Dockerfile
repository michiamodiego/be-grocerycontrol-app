FROM perl:5.34
RUN perl -MCPAN -e 'install Mojolicious'
RUN perl -MCPAN -e 'install DBI'
RUN perl -MCPAN -e 'install DBD::SQLite'
RUN perl -MCPAN -e 'install Data::GUID'
RUN perl -MCPAN -e 'install DateTime'
RUN perl -MCPAN -e 'install Digest::SHA'
WORKDIR /app
EXPOSE 8080
COPY . .
ENTRYPOINT perl app.pl daemon -l http://*:8080

