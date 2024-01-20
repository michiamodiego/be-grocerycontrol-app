FROM perl:5.34
RUN perl -MCPAN -e 'install Mojolicious' && \ 
	perl -MCPAN -e 'install DBI' && \
	perl -MCPAN -e 'install DBD::SQLite' && \
	perl -MCPAN -e 'install Data::GUID' && \
	perl -MCPAN -e 'install DateTime' && \
	perl -MCPAN -e 'install Digest::SHA'
WORKDIR /app
EXPOSE 8080
COPY . .
ENTRYPOINT perl app.pl daemon -l http://*:8080

