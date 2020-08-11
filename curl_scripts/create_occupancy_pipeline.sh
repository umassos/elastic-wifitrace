echo Deleting old pipeline
curl -XDELETE "http://localhost:9200/_ingest/pipeline/enrich_occupancy"
curl -XDELETE "http://localhost:9200/_ingest/pipeline/enrich_building_occupancy"
echo Deleting old enrich policy
curl -XDELETE "http://localhost:9200/_enrich/policy/covid-building-occupancy-enrich"
curl -XDELETE "http://localhost:9200/_enrich/policy/covid-occupancy-enrich"
echo Creating enrich policy
curl -XPUT "http://localhost:9200/_enrich/policy/covid-building-occupancy-enrich" -H 'Content-Type: application/json' -d @enrich_building_occupancy_policy.json
curl -XPUT "http://localhost:9200/_enrich/policy/covid-occupancy-enrich" -H 'Content-Type: application/json' -d @enrich_occupancy_policy.json
echo Executing enrich policy
curl -XPOST "http://localhost:9200/_enrich/policy/covid-building-occupancy-enrich/_execute"
curl -XPOST "http://localhost:9200/_enrich/policy/covid-occupancy-enrich/_execute"
echo Creating Ingest pipeline
curl -XPUT "http://localhost:9200/_ingest/pipeline/enrich_occupancy" -H 'Content-Type: application/json' -d @occupancy_ingest_pipeline.json
curl -XPUT "http://localhost:9200/_ingest/pipeline/enrich_building_occupancy" -H 'Content-Type: application/json' -d @occupancy_building_ingest_pipeline.json