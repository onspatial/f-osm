# Reproducing Results from the Paper

This document outlines the steps required to reproduce the results presented in our paper:  
**_"F-OSM: Enriched Foursquare POI Dataset with OpenStreetMap Available as Structured and Graph Data"_**.

All source code, sample datasets, and processing scripts used in the study are provided in this repository. By following the instructions below, you will be able to recreate the full data processing pipeline, perform enrichment using OpenStreetMap (OSM) data, and generate both structured and graph-based representations of the final dataset. This includes environment setup, data acquisition, preprocessing, and evaluation scripts.

# Environment Setup

The experiments were conducted on a machine running **Ubuntu 22.04.1** with the following specifications:

- **Memory**: 256 GB RAM
- **Processor**: Intel(R) Xeon(R) CPU E5-2643 v2 @ 3.50GHz (24 cores)
- **Python version**: 3.10.12
- **PostgreSQL version**: 17.4
- **PostGIS version**: 3.5.2
- **Nominatim version**: 5.1.0

We recommend using `pipenv` to manage the Python environment and ensure reproducibility. To install all dependencies and activate the environment, run:

```bash
pipenv install
pipenv shell
```

If you prefer not to use pipenv, you can install the required packages manually using pip:

```bash
pip install pandas==2.2.3 \
            pyarrow==20.0.0 \
            numpy==2.2.6 \
            DateTime==5.5 \
            geopandas==1.0.1 \
            requests==2.32.3
```

Make sure your environment matches these versions to avoid compatibility issues during data processing or analysis.

# Data Preparation

## Download the Data

### Foursquare Data

To obtain the Foursquare POI data, run the script [**fsq_download.py**](code/datacollection/fsq_download.py). This script downloads the complete dataset and saves it in the `data/` directory as a single file named `foursquare.csv`.

```bash
python code/datacollection/fsq_download.py
```

**Memory Note:** The script concatenates large amounts of data and may consume substantial memory. If you encounter performance issues, we recommend using the provided Bash script [concat.sh](code/datacollection/concat.sh), which performs more memory-efficient concatenation:

```bash
bash code/datacollection/concat.sh
```

Before importing the dataset into PostgreSQL, we sanitize the `geom` column in `foursquare.csv` by setting its value to `""`. This prevents binary-string errors during import. Geometries are later reconstructed using the latitude and longitude fields.

### OpenStreetMap (OSM) Data:

To enrich the Foursquare data with geographic features, we use the global OSM dataset in PBF format. The data can be downloaded from the [Planet OSM](https://planet.openstreetmap.org/) archive. The full [file](https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf) is approximately 80 GB, so ensure sufficient disk space before proceeding.

We downloaded using the following command:

```bash
wget https://osm-planet-us-west-2.s3.dualstack.us-west-2.amazonaws.com/planet/pbf/2025/planet-250414.osm.pbf
```

Save the file in a designated directory (e.g., `data/osm/`) for subsequent processing.

## Import Data into PostgreSQL

We use PostgreSQL to store and manage the Foursquare and OSM datasets. The data is imported into a new database named **`fsq-osm`**, which contains two main tables: `foursquare` and `osm`.

### Step 1: Create the Database

Run the following command to create a new PostgreSQL database:

```bash
createdb fsq-osm
```

### Step 2: Connect to the Database

Use the `psql` CLI tool to connect to the newly created database:

```bash
psql -d fsq-osm
```

---

Once connected, you can execute SQL commands to create the necessary schema and import data. Detailed SQL import commands and schema definitions are provided in the import.sql file in the repository.

We store the data in a new database called `fsq-osm`, which will have two tables: `foursquare` and `osm`.

To create a new database, you can use the following command:

```bash
createdb fsq-osm
```

Then, connect to the database using the following command:

### Foursquare Data:

To import the [downloaded](code/datacollection/fsq_download.sql) Foursquare data into PostgreSQL, we first create the `foursquare` table in the `fsq-osm` database. You can use the following SQL command to create the table:

```sql
 CREATE TABLE foursquare (
    fsq_place_id        text, name                text,
    latitude            text, longitude           text,
    address             text, locality            text,
    region              text, postcode            text,
    admin_region        text, post_town           text,
    po_box              text, country             text,
    date_created        text, date_refreshed      text,
    date_closed         text, tel                 text,
    website             text, email               text,
    facebook_id         text, instagram           text,
    twitter             text, fsq_category_ids    text,
    fsq_category_labels text, placemaker_url      text,
    geom                text, bbox                text
    );
```

Then we can import the data from the `foursquare.csv` file into the `foursquare` table using the following command:

```sql
\copy foursquare FROM 'foursquare.csv' WITH ( FORMAT csv, HEADER, DELIMITER ',', QUOTE '"', ESCAPE '"', NULL '' );
```

### OSM Data:

First the downloaded OSM data is converted into PostgreSQL. To convert the OSM data into PostgreSQL, we use [`nominatim`](https://nominatim.org/) tool.

You can install it using the following command:

```bash
pip install nominatim-db nominatim-api
```

Then, you can use the following command to import the OSM data into PostgreSQL:

```bash
nominatim import --osm-file data/osm/planet-250414.osm.pbf
```

For the most recent version and detailed instructions, please refer to the official documentation on the [Nominatim website](https://nominatim.org)

After importing, we only use the places that have address and name from the OSM data:

```sql
CREATE TABLE places_filtered AS

SELECT p.*, n.*, (n.lat::numeric  / 10000000) AS lat_deg, (n.lon::numeric  / 10000000) AS lon_deg
FROM place p JOIN planet_osm_nodes n
ON n.id = p.osm_id
WHERE p.address IS NOT NULL and p.osm_name IS NOT NULL;
```

Then we export the data to a CSV file using the following command:

```sql
\copy places_filtered TO 'osm.csv' CSV HEADER
```

Next, we import the `osm` data in the `fsq-osm` database. You can use the following SQL command:

```sql
CREATE TABLE osm (
  osm_type TEXT,
  osm_id BIGINT,
  class TEXT,
  type TEXT,
  admin_level INTEGER,
  osm_name TEXT,
  osm_address TEXT,
  extratags TEXT,
  geometry GEOMETRY,
  id BIGINT,
  lat BIGINT,
  lon BIGINT,
  tags TEXT,
  lat_deg DOUBLE PRECISION,
  lon_deg DOUBLE PRECISION
);
```

Then we can import the data from the `osm.csv` file into the `osm` table using the following command:

```sql
\copy osm FROM 'osm.csv' CSV HEADER
```

Now we have the `foursquare` and `osm` tables in the `fsq-osm` database.

# Preprocessing the Data

After importing the data into PostgreSQL, we need to process the data to prepare it for analysis. The following steps outline how to process the Foursquare and OSM data.

## Adding Geometry Columns:

We use PostGIS to calculate the geometry from the latitude and longitude values in the `foursquare` and `osm` tables.
For the `foursquare` table, we add a new column called `fsq_geom` to store the geometry. The `fsq_geom` column is of type `geometry(Point, 4326)`, which is a point geometry in the WGS 84 coordinate system (EPSG:4326).
To add the `fsq_geom` column, we first need to ensure that the PostGIS extension is enabled in the database. You can enable it using the following command:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

Next, we can add the `fsq_geom` column to the `foursquare` table and calculate the geometry using the latitude and longitude values. The latitude and longitude columns in the `foursquare` table are named `latitude` and `longitude`, respectively.

We can add the `fsq_geom` column to the `foursquare` table using the following SQL command:

```sql
ALTER TABLE foursquare ADD COLUMN fsq_geom geometry(Point, 4326);
UPDATE foursquare
SET geom = ST_SetSRID(
                ST_MakePoint(longitude::double precision, latitude::double precision)
                ,4326 )
WHERE latitude ~ '^\-?\d+(\.\d+)?$' AND longitude ~ '^\-?\d+(\.\d+)?$';
```

For the `osm` table, we use the same command to add the `osm_geom` column. Please note that the `latitude` and `longitude` columns in the `osm` table are named `lat_deg` and `lon_deg`, respectively.

## Adding Indexes:

To speed up the queries, we add indexes to the `geom` column in both tables. You can use the following SQL commands to add the indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_foursquare_geom ON foursquare USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_osm_geom ON osm USING GIST (geom);
```

## Joining Foursquare and OSM Data:

To join the Foursquare and OSM data, we can use the `ST_DWithin` function to find the points that are within a certain distance from each other. We can use a distance of 100 meters as a threshold to consider two points as the same location.

```sql
CREATE TABLE fsq_osm AS
SELECT f.*, o.*
FROM foursquare f
LEFT OUTER JOIN osm o
ON ST_DWithin(f.fsq_geom, o.osm_geom, 0.001)

```

This SQL command creates a new table called `fsq_osm` that contains the joined data from both tables. The `ST_DWithin` function checks if the geometries of the Foursquare and OSM points are within 0.001 degrees (approximately 100 meters) of each other.

As a case study, we can use the following SQL command to only select the data for 'US' country:

```sql
CREATE TABLE fsq_osm_usa AS
SELECT f.*, o.*
FROM foursquare f
LEFT OUTER JOIN osm o
ON ST_DWithin(f.fsq_geom, o.osm_geom, 0.001)
WHERE f.fsq_country='US';
```

This will create a new table called `fsq_osm_usa` that contains the joined data from both tables for locations in the United States.

# Calculating the Similarity:

To calculate the similarity between the Foursquare and OSM data, we use two approaches. The distance between longitude and latitude of foursquare and osm as a separate column in the data. We also provide a similarity score between the name of the place in foursquare and osm.

Using the name_similarity_score, you can see how similar the names are and using coordinate distance you can see how close the location in spatially.

```sql
ALTER TABLE fsq_osm ADD COLUMN name_similarity_score DOUBLE PRECISION;
ALTER TABLE fsq_osm ADD COLUMN fsq_osm_distance DOUBLE PRECISION;
```

```sql
UPDATE fsq_osm
SET fsq_osm_distance = ST_Distance(fsq_geom, osm_geom);
```

```sql
UPDATE fsq_osm
SET name_similarity_score = GREATEST(similarity(LOWER(fsq_name), LOWER(osm_name)), 0.0);
```

# Exporting the Final Dataset

To export the final dataset, we can use the `\copy` command to export the `fsq_osm` table to a CSV file. You can use the following SQL command:

```sql
\copy fsq_osm TO 'fsq_osm.csv' CSV HEADER
```

This command exports the `fsq_osm` table to a CSV file named `fsq_osm.csv` in the current directory. The `CSV HEADER` option ensures that the column names are included in the first row of the CSV file.
