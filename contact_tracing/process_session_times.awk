BEGIN {
    # Invoke using: awk -f process_session_times.awk -F"|" input_file 2> /dev/null
    # Don't redirect stderr if you want to see all warning messages

    min_session_length_in_seconds = 60*15;
}
{
if (NR == 1)
{  # Initialize ap and set time to 0 if disassociation or time column if association
    gsub(/^[ \t]+|[ \t]+$/, "", $2); # now-start_timestamp
    gsub(/^[ \t]+|[ \t]+$/, "", $3); # AP name
    gsub(/^[ \t]+|[ \t]+$/, "", $4); # association/disassociation
    ap = $3;
    if ($4=="association") {start=$1; t=$2} else {t=0};
    seen = 0;
    # print ap t "."$4".";
    next
}
else
{
    # Trim spaces
    gsub(/^[ \t]+|[ \t]+$/, "", $2); # now-start_timestamp
    gsub(/^[ \t]+|[ \t]+$/, "", $3); # AP name
    gsub(/^[ \t]+|[ \t]+$/, "", $4); # association/disassociation
    gsub(/^[ \t]+|[ \t]+$/, "", $5); # Building
    gsub(/^[ \t]+|[ \t]+$/, "", $6); # Floor
    
    if ($3 != ap) # We changed APs
    {
	if (t>0)
	{
	    print "! Last association event on AP " ap " at " $start " did not have a disassociation event" > "/dev/stderr"
	}
	if (seen == 0)
	{
	    print "! User was seen at AP " ap " but no session longer than " min_session_length_in_seconds " seconds was found" > "/dev/stderr"
	}
	ap = $3;
	if ($4=="association") {start=$1; t=$2} else {t=0} ;
	#print "New ap" ap t;
    }
    else { # Same AP
	if ($4=="association")
	{
	    if (t==0)
	    {start=$1; t=$2} # New association -> record time
	    else { print "* Association without disassociation, ignoring current event" > "/dev/stderr" }
	}
	else
	{ 
	    if (t>0) # If first disassociation print time difference and start timestamp
	    {
		if (t-$2 < min_session_length_in_seconds)
		{ print "+ Session does not match minimum length for " ap "," start "," (t-$2) > "/dev/stderr" }
		else { print user "," ap "," $5 "," $6 "," start "," t "," $2 "," $1 "," (t-$2) ; seen = 1; }
		t = 0;
	    }
	    else { print "* Ignoring disassociation event, no association event available" > "/dev/stderr" }
	}
    }
}
}
