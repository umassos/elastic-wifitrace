echo off
echo Stopping transforms
curl -XPOST "http://localhost:9200/_transform/covid-building-floor/_stop"
curl -XPOST "http://localhost:9200/_transform/covid-logfile/_stop"
echo Delete old transforms
curl -XDELETE "http://localhost:9200/_transform/covid-building-floor"
curl -XDELETE "http://localhost:9200/_transform/covid-logfile"
echo Delete index contents
curl -XPOST "http://localhost:9200/covid-building-floor/_delete_by_query" -H "Content-Type: application/json" -d @query_all.json
curl -XPOST "http://localhost:9200/covid-logfile/_delete_by_query" -H "Content-Type: application/json" -d @query_all.json
echo Create transforms
curl -XPUT "http://localhost:9200/_transform/covid-logfile" -H "Content-Type: application/json" -d @transform_logfile.json
curl -XPUT "http://localhost:9200/_transform/covid-building-floor" -H "Content-Type: application/json" -d @transform_building_floor.json
echo Start transforms
curl -XPOST "http://localhost:9200/_transform/covid-building-floor/_start"
curl -XPOST "http://localhost:9200/_transform/covid-logfile/_start"
echo Done