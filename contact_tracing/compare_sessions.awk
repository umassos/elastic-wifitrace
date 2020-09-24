BEGIN {
    # Invoke using: awk -f compare_sessions.awk -F"," -v min_session_length_in_seconds=900 /tmp/locations_pRC.xhCxaQo /tmp/user_sessions_pRC.xhCxaQo
    # Reads all the sessions from the first file and compare them with the sessions of the 2nd file
    # Outputs all overlapping sessions by at least min_session_length_in_seconds
    # Output format is:
    # traced_user_name,other_user_name,ap_name,start_contact_timestamp,end_contact_timestamp,duration_of_contact_in_minutes

 #   min_session_length_in_seconds = 60*15;
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
	    if (u[2]==$2) # Same AP
	    {
		user_start=-u[6];
		user_end=-u[7];
		other_start=-$6;
		other_end=-$7;
		# Output format: user_name,other_user_name,AP_name,start_contact,end_contact,contact_duration_in_min
		if (other_start<=user_end-min_session_length_in_seconds && other_end>=user_end) 
		{ # Overlap on end
		    print u[1] "," $1 "," $2 "," $5 "," u[8] "," ((user_end-other_start)/60.0)
		}
		else if (other_end>=user_start+min_session_length_in_seconds && other_start<=user_start)
		{ # Overlap on start
		    print u[1] "," $1 "," $2 "," u[5] "," $8 "," ((other_end-user_start)/60.0)
 		}
		else if  (other_start<=user_start && other_end>=user_end)
		{ # other user window encompasses user window (which is already over mon session length)
		    print u[1] "," $1 "," $2 "," u[5] "," u[8] "," ((user_end-user_start)/60.0)
 		}
		else if (other_start>=user_start && other_end<=user_end)
		{ # other user window contained in user window (but still bigger than min session length)
		    print u[1] "," $1 "," $2 "," $5 "," $8 "," ((other_end-other_start)/60.0)
 		}
		# print u[1] " " u[2] " " u[3] " " u[4] " " u[5] " " u[8] " " u[6] " " u[7]
		# print $1 " " $2 " " $3 " " $4 " " $5 " " $8 " " $6 " " $7
 	    }
	}
    }
}
