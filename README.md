# osm_borders
Use PostgreSQL clean OSM administrative boundaries

### Required:
* `PostgreSQL`
* `PostGIS` extension for `PostgreSQL`
* `osmium` for filtering `*.pbf` file(s)
* `imposm` for importing into PostgreSQL

### Suggested:
* `make` for leveraging the pre-built commands

Ensure that you set up `PostgreSQL` to accept your username and password to
create, modify, and delete databases prior to running

### Using the `Makefile`
Open the `Makefile`, adjust the values in the preamble to match your
system, username, etc., the run the `Makefile` in total or by individual
commands

### License:
GNU GPL v3.0

### Improvements
Forking and modifying strongly requested. Submission of issues and PRs
is strongly desired so all might benefit

