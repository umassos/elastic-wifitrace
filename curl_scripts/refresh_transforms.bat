echo off
echo Stopping transforms
curl -XPOST "http://localhost:9200/_transform/covid-building-floor/_stop"
curl -XPOST "http://localhost:9200/_transform/covid-logfile/_stop"
curl -XPOST "http://localhost:9200/_transform/covid-user-mac-per-ap/_stop"
timeout 5
echo Delete old transforms
curl -XDELETE "http://localhost:9200/_transform/covid-building-floor"
curl -XDELETE "http://localhost:9200/_transform/covid-logfile"
curl -XDELETE "http://localhost:9200/_transform/covid-user-mac-per-ap"
echo Delete index contents
curl -XPOST "http://localhost:9200/covid-building-floor/_delete_by_query" -H "Content-Type: application/json" -d @query_all.json
curl -XPOST "http://localhost:9200/covid-logfile/_delete_by_query" -H "Content-Type: application/json" -d @query_all.json
curl -XPOST "http://localhost:9200/covid-user-mac-per-ap/_delete_by_query" -H "Content-Type: application/json" -d @query_all.json
echo Create transforms
curl -XPUT "http://localhost:9200/_transform/covid-logfile" -H "Content-Type: application/json" -d @transform_logfile.json
curl -XPUT "http://localhost:9200/_transform/covid-building-floor" -H "Content-Type: application/json" -d @transform_building_floor.json
curl -XPUT "http://localhost:9200/_transform/covid-user-mac-per-ap" -H "Content-Type: application/json" -d @transform_user_mac_per_ap.json
echo Start transforms
curl -XPOST "http://localhost:9200/_transform/covid-building-floor/_start"
curl -XPOST "http://localhost:9200/_transform/covid-logfile/_start"
curl -XPOST "http://localhost:9200/_transform/covid-user-mac-per-ap/_start"
echo Done