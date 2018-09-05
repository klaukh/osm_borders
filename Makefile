# variables to set for the PostgreSQL connection
pwd= osm
username= osm
dbname= osm
host= 127.0.0.1
port= 5432
conn= postgis://$(username):$(pwd)@$(host):$(port)/$(dbname)
cmd= PGPASSWORD=$(pwd) psql -h $(host) -d $(dbname) -U $(username)


help:
	@echo "=============================================================================="
	@echo " OSM Borders - Extract and clean OSM administrative boundaries "
	@echo ""
	@echo "  make user      			# Change user to postgres superuser "
	@echo "  make clean-db	     	# Delete the database "
	@echo "  make make-db	      	# Set up a new PostgreSQL database "
	@echo "  make check	      		# Quick database check "
	@echo "  make connect	      	# Enter to database "
	@echo "  make clean-db	      # Reset the database tables "
	@echo ""
	@echo "  make bounadaries	    # Use osmium and imposm to filter and load "
	@echo "  make boders	    		# Run SQLs to build the borders "
	@echo ""
	@echo "  make help            # help about avaialable commands"
	@echo "=============================================================================="

# commands to run for imposm3, using planet.osm.pbf (base file, not diff)

## POSTGRESQL SETUP
# after insatlling postgresql (pgadmin also recommended)
all: user make-db check boundaries borders

user:
	sudo su postgres
make-db:
	createdb -E UTF8 -O $(username) $(dbname) ;
	createuser --no-superuser --nocreaterole --createdb $(dbname) ;
	psql -d $(dbname) -c "CREATE EXTENSION postgis;" ;
	psql -d $(dbname) -c "CREATE EXTENSION hstore;"  ;
	echo "ALTER USER osm WITH PASSWORD 'osm';" |psql -d $(dbname)

# make sure to the PostgreSQL pg_hba.conf line to
# host all	all	127.0.0.1/32	md5

# if all is successful the following should work
check:
	$(cmd) -c 'select postgis_version();'

connect:
	$(cmd);

boundaries:
	osmium tags-filter planet-latest.osm.pbf \
		r/boundary=administrative \
		--progress -vO -o boundaries.osm.pbf ;
	imposm import -overwritecache -connection $(conn) -mapping mapping.yml -read boundaries.osm.pbf \
		-write -optimize -deployproduction ;

borders:
	$(cmd) ./zres.sql ;
	$(cmd) ./make_borders.sql ;

# clean all tables from the DB
clean-db: $(cmd) clean.sql

