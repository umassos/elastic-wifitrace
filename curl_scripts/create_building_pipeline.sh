echo Deleting old pipeline
curl -XDELETE "http://localhost:9200/_ingest/pipeline/enrich_building"
echo Deleting old enrich policy
curl -XDELETE "http://localhost:9200/_enrich/policy/covid-building-enrich"
echo Creating enrich policy
curl -XPUT "http://localhost:9200/_enrich/policy/covid-building-enbuildrich" -H 'Content-Type: application/json' -d @enrich_building_policy.json
echo Executing enrich policy
curl -XPOST "http://localhost:9200/_enrich/policy/covid-building-enrich/_execute"
echo Creating Ingest pipeline
curl -XPUT "http://localhost:9200/_ingest/pipeline/enrich_building" -H 'Content-Type: application/json' -d @building_ingest_pipeline.json