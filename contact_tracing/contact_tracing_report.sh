#/bin/bash

### Parameters:
### $1: user name (person being traced)
### $2: number of days to go back in history to find locations

ELASTIC_BIN_PATH=/elastic/elasticsearch-7.8.0/bin
TEMP_FOLDER=/tmp/wifitrace
REPORT_FOLDER=./report
declare -i CONTACT_LENGTH_IN_SECONDS
CONTACT_LENGTH_IN_SECONDS=60*15

mkdir -p $TEMP_FOLDER
mkdir -p $REPORT_FOLDER

REPORT_TIME=`date +%F-%T`

# Remove problematic characters from a possibly encrypted user name to prevent issue with filenames
file1=`echo "$1" | tr -d '/:;'`

# We retrieve the list of all MAC addresses for the user even if they were not seen in the past $2 days
# Results are stored in tmp/macs_USERNAME
echo --- Retrieving list of MAC addresses for user $1
echo "SELECT mac FROM covid WHERE user_name='$1' GROUP BY mac;" | $ELASTIC_BIN_PATH/elasticsearch-sql-cli 2> /dev/null | awk '/--------/{flag=1;next}/sql>/{flag=0}flag' | head -n -1 > $TEMP_FOLDER/macs_$file1
cat $TEMP_FOLDER/macs_$file1

# Get all records timestamp, assoc/diassoc, ap_name,building,floor for the given user
# (@timestamp must match the timestamp of when the event happened)
# List must be ordered per AP then timestamp for further processing to work correctly
# Results are stored in: tmp/macs_USERNAME_MAC (1 file per MAC)
echo --- Retrieving the list of locations for user $1 in the past $2 days
cat $TEMP_FOLDER/macs_$file1 | while read line
do
    # Remove problematic characters from a possibly encrypted MAC address
    filename=`echo $line | tr -d '/:;'`
    echo "SELECT \"@timestamp\",DATEDIFF('seconds',\"@timestamp\",NOW()),ap_name,event_type,building,floor FROM covid WHERE  mac='$line' AND event_type IS NOT NULL AND \"@timestamp\">TODAY() - INTERVAL $2 days ORDER BY ap_name,\"@timestamp\" ASC;" | $ELASTIC_BIN_PATH/elasticsearch-sql-cli 2> /dev/null | awk '/--------/{flag=1;next}/sql>/{flag=0}flag' | head -n -1 > $TEMP_FOLDER/macs_$file1_$filename
    echo $line: Found `cat $TEMP_FOLDER/macs_$file1_$filename | wc -l` association/disassociation events
done

# Computing actual start/end time per AP by going through all the records
# Results are stored in tmp/locations_USERNAME
echo --- Retrieving locations and session durations
rm -f $TEMP_FOLDER/locations_$file1
cat $TEMP_FOLDER/macs_$file1 | while read line
do
    filename=`echo $line | tr -d '/:;'`
    awk -f process_session_times.awk -F"|" -v user=$1 -v min_session_length_in_seconds=$CONTACT_LENGTH_IN_SECONDS $TEMP_FOLDER/macs_$file1_$filename 1>> $TEMP_FOLDER/locations_$file1  2> /dev/null
done
echo Found `cat $TEMP_FOLDER/locations_$file1 | wc -l` sessions matching criteria

# Find all other users that were at the same APs in the past $2 days
# Results are stored in: tmp/users_USERNAME_APNAME (1 file per AP)
echo --- Retrieving users that were seen at the same APs
cat $TEMP_FOLDER/locations_$file1 | cut -d ',' -f2 | uniq | while read line
do
    echo Looking for users at $line
    echo "SELECT user_name,mac,COUNT(\"@timestamp\") FROM covid WHERE user_name IS NOT NULL AND user_name<>'$1' AND ap_name='$line' AND \"@timestamp\">TODAY() - INTERVAL $2 days GROUP BY user_name,mac;" | $ELASTIC_BIN_PATH/elasticsearch-sql-cli 2> /dev/null | awk '/--------/{flag=1;next}/sql>/{flag=0}flag' | head -n -1 > $TEMP_FOLDER/users_$file1_$line
done

# Get all records timestamp, assoc/diassoc, ap_name,building,floor for all other users
# (@timestamp must match the timestamp of when the event happened)
# List must be ordered per AP then timestamp for further processing to work correctly
# Results are stored in tmp/user_sessions_USERNAME
echo --- Computing sessions for others at the same APs
rm -f $TEMP_FOLDER/user_sessions_$file1
cat $TEMP_FOLDER/locations_$file1 | cut -d ',' -f2 | uniq | while read ap
do
    INPUT=$TEMP_FOLDER/users_$file1_$ap
    while IFS='|' read -r user_name mac count
    do
	echo Calculating sessions for user $user_name - Mac $mac at AP $ap
	echo "SELECT \"@timestamp\",DATEDIFF('seconds',\"@timestamp\",NOW()),ap_name,event_type,building,floor FROM covid WHERE mac='$mac' AND ap_name='$ap' AND event_type IS NOT NULL AND \"@timestamp\">TODAY() - INTERVAL $2 days ORDER BY ap_name,\"@timestamp\" ASC;" | $ELASTIC_BIN_PATH/elasticsearch-sql-cli 2> /dev/null | awk '/--------/{flag=1;next}/sql>/{flag=0}flag' | head -n -1 | awk -f process_session_times.awk -F"|" -v user=$user_name -v min_session_length_in_seconds=$CONTACT_LENGTH_IN_SECONDS 1>> $TEMP_FOLDER/user_sessions_$file1 2> /dev/null
    done < $INPUT
done

# Find all other users that were on the same building/floor regardless of AP
# Results are stored in tmp/users_building_USERNAME_BUILDING_FLOOR (one file per building/floor)
echo --- Retrieving users that were seen on the same building/floor
cat $TEMP_FOLDER/locations_$file1 | cut -d ',' -f3,4 | uniq | while read line
do
    readarray -d , -t csv <<< "$line"
    building=${csv[0]}
    floor=${csv[1]}
    if [ "$building" = "null" ]; then
	echo "One or more AP has no building information"
    elif [ "floor" = "null" ]; then
        echo "One or more AP has no floor information"
    else
	echo "Looking for users in building" $building "floor" $floor
	echo "SELECT user_name,mac,COUNT(\"@timestamp\") FROM covid WHERE user_name IS NOT NULL AND user_name<>'$1' AND building='$building' AND floor=$floor AND \"@timestamp\">TODAY() - INTERVAL $2 days GROUP BY user_name,mac;" | $ELASTIC_BIN_PATH/elasticsearch-sql-cli 2> /dev/null | awk '/--------/{flag=1;next}/sql>/{flag=0}flag' | head -n -1 > $TEMP_FOLDER/users_building_${file1}_${building}_${floor}
    fi
done

# Get all records timestamp, assoc/diassoc, ap_name,building,floor for all other users
# (@timestamp must match the timestamp of when the event happened)
# List must be ordered per AP then timestamp for further processing to work correctly
# Results are stored in tmp/user_sessions_building_USERNAME
echo --- Computing sessions for others in the same building/floor
rm -f $TEMP_FOLDER/user_sessions_building_${file1}
cat $TEMP_FOLDER/locations_$file1 | cut -d ',' -f3,4 | uniq | while read line
do
    readarray -d , -t csv <<< "$line"
    building=${csv[0]}
    floor=${csv[1]}
    if [ "$building" = "null" ]; then
	echo "One or more AP has no building information"
    elif [ "floor" = "null" ]; then
        echo "One or more AP has no floor information"
    else
	INPUT=$TEMP_FOLDER/users_building_${file1}_${building}_${floor}
	while IFS='|' read -r user_name mac count
	do
            echo Calculating sessions for user $user_name - Mac $mac in building $building floor $floor
            echo "SELECT \"@timestamp\",DATEDIFF('seconds',\"@timestamp\",NOW()),ap_name,event_type,building,floor FROM covid WHERE mac='$mac' AND building='$building' AND floor=$floor AND event_type IS NOT NULL AND \"@timestamp\">TODAY() - INTERVAL $2 days ORDER BY ap_name,\"@timestamp\" ASC;" | $ELASTIC_BIN_PATH/elasticsearch-sql-cli 2> /dev/null | awk '/--------/{flag=1;next}/sql>/{flag=0}flag' | head -n -1 | awk -f process_session_times.awk -F"|" -v user=$user_name -v min_session_length_in_seconds=$CONTACT_LENGTH_IN_SECONDS 1>> $TEMP_FOLDER/user_sessions_building_${file1} 2> /dev/null
	done < $INPUT
    fi
done


echo --- Comparing sessions to determine potential contact
# Generate contact info per AP into report/contacts_ap_USERNAME.csv
awk -f compare_sessions.awk -F"," -v min_session_length_in_seconds=$CONTACT_LENGTH_IN_SECONDS $TEMP_FOLDER/locations_${file1} $TEMP_FOLDER/user_sessions_${file1} > $REPORT_FOLDER/contacts_ap_${file1}_${REPORT_TIME}.csv
echo Found `cat $REPORT_FOLDER/contacts_ap_${file1} | wc -l` contact periods at APs
# Generate contact info per building/floor into report/contacts_building_USERNAME.csv
awk -f compare_building_sessions.awk -F"," -v min_session_length_in_seconds=$CONTACT_LENGTH_IN_SECONDS $TEMP_FOLDER/locations_${file1} $TEMP_FOLDER/user_sessions_building_${file1} > $REPORT_FOLDER/contacts_building_${file1}_${REPORT_TIME}.csv
echo Found `cat $REPORT_FOLDER/contacts_building_ap_${file1} | wc -l` contact periods in buildings

echo ---- Generating final contact tracing report to $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "### Contact tracing report for user " $1 " for the past " $2 " days ###" > $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "---------------------------------------------------" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "Top list of contacts per AP (longest contact first)" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "---------------------------------------------------" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
awk -F"," 'END { for (E in a) print "User " E " - Total: " a[E] " min" } { a[$2] += $6 }' $REPORT_FOLDER/contacts_ap_${file1}_${REPORT_TIME}.csv | sort -k5 -n -r >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "--------------------------------" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "Detail of contact periods at APs" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "--------------------------------" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
awk -F"," '{print "Contact with " $2 " at AP " $3 " from " $4 " to " $5 " (duration " $6 " minutes)"}' $REPORT_FOLDER/contacts_ap_${file1}_${REPORT_TIME}.csv >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "---------------------------------------------------------" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "Top list of contacts per building (longest contact first)" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "---------------------------------------------------------" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
awk -F"," 'END { for (E in a) print "User " E " - Total: " a[E] " min" } { a[$2] += $6 }' $REPORT_FOLDER/contacts_building_${file1}_${REPORT_TIME}.csv | sort -k5 -n -r >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "--------------------------------------" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "Detail of contact periods in buildings" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
echo "--------------------------------------" >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
awk -F"," '{print "Contact with " $2 " in building " $7 " floor " $8 " from " $4 " to " $5 " (duration " $6 " minutes)"}' $REPORT_FOLDER/contacts_building_${file1}_${REPORT_TIME}.csv >> $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
cat $REPORT_FOLDER/contact_report_${file1}_${REPORT_TIME}.txt
