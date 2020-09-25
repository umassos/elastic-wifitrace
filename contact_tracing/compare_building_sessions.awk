BEGIN {
    # Invoke using: awk -f compare_building_sessions.awk -F"," -v min_session_length_in_seconds=900 /tmp/locations_pRC.xhCxaQo /tmp/user_sessions_building_pRC.xhCxaQo
    # Reads all the sessions from the first file and compare them with the sessions of the 2nd file
    # Outputs all overlapping sessions by at least min_session_length_in_seconds
    # Output format is:
    # traced_user_name,contact_user_name,traced_ap_name,start_contact_timestamp,end_contact_timestamp,duration_of_contact_in_minutes,building,floor,contact_user_ap_name

#    min_session_length_in_seconds = 60*15;
}
{
    if(NR == FNR) # Copy user file in memory
    {
	user_file[FNR]=$0;
	user_files_total_lines=FNR;
    }
    else # Reading user file here
    {
	for (line=1; line<=user_files_total_lines; line++)
	{
	    split(user_file[line],u,",");
	    if ((u[3]==$3) && (u[4]==$4)) # Same building/floor
	    {
		traced_start=-u[6];
		traced_end=-u[7];
		contactedstart=-$6;
		contactedend=-$7;
		# Output format: traced_user_name,contact_user_name,traced_ap_name,start_contact_timestamp,end_contact_timestamp,duration_of_contact_in_minutes,building,floor,contact_user_ap_name
		if (contactedstart<=traced_end-min_session_length_in_seconds && contactedend>=traced_end) 
		{ # Overlap on end
		    print u[1] "," $1 "," $2 "," $5 "," u[8] "," ((traced_end-contactedstart)/60.0) "," $3 "," $4 "," u[2]
		}
		else if (contactedend>=traced_start+min_session_length_in_seconds && contactedstart<=traced_start)
		{ # Overlap on start
		    print u[1] "," $1 "," $2 "," u[5] "," $8 "," ((contactedend-traced_start)/60.0) "," $3 "," $4 "," u[2]
 		}
		else if  (contactedstart<=traced_start && contactedend>=traced_end)
		{ # other user window encompasses user window (which is already over mon session length)
		    print u[1] "," $1 "," $2 "," u[5] "," u[8] "," ((traced_end-traced_start)/60.0) "," $3 "," $4 "," u[2]
 		}
		else if (contactedstart>=traced_start && contactedend<=traced_end)
		{ # other user window contained in user window (but still bigger than min session length)
		    print u[1] "," $1 "," $2 "," $5 "," $8 "," ((contactedend-contactedstart)/60.0) "," $3 "," $4 "," u[2]
 		}
 	    }
	}
    }
}
