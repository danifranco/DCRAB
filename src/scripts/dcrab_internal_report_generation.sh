#!/bin/bash
# DCRAB SOFTWARE
# Version: 2.0
# Autor: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# To make the internal report based on collected statistics from jobs. The idea is to execute this script once
# a day to update the report 
#
# ===============================================================================================================

DCRAB_IREPORT="/scratch/administracion/admin/dcrab/dcrab_ireport_$(date +%d%m%Y)"
DCRAB_IREPORT_DATA_DIR="/scratch/administracion/admin/dcrab/data"
DCRAB_NUMBER_OF_BARS=20

# Initialize necessary variables
firstDate=$(ls -lt --time-style="+%s" $DCRAB_IREPORT_DATA_DIR | grep -v total | tail -1 | sed 's|\s\s*| |g' | cut -d' ' -f6)
firstDateFormated=$(date -d@$firstDate +%d/%m/%y)
firstDateReduced=$(date -d $(date -d@$firstDate +%m/%d/%y) +"%s")
lastDate=$(ls -lt --time-style="+%s" $DCRAB_IREPORT_DATA_DIR | grep -v total | head -1 | sed 's|\s\s*| |g' | cut -d' ' -f6)
lastDateFormated=$(date -d@$lastDate +%d/%m/%y)
lastDateReduced=$(date -d $(date -d@$lastDate +%m/%d/%y) +"%s")
days=$(echo "( ($lastDateReduced - $firstDateReduced)/(24*3600) ) +1" | bc)
lastFile=$(ls -lt --time-style="+%s" $DCRAB_IREPORT_DATA_DIR | grep -v total | head -1 | sed 's|\s\s*| |g' | cut -d' ' -f7)
nNodes=$(cat  $DCRAB_IREPORT_DATA_DIR/$lastFile | cut -d' ' -f2)
time=$(cat  $DCRAB_IREPORT_DATA_DIR/$lastFile | cut -d' ' -f1) 
ibMax=$(cat $DCRAB_IREPORT_DATA_DIR/$lastFile | cut -d' ' -f3)
ibMax=$(echo "scale=3; $ibMax / (1024 * 1024 * $time * $nNodes) " | bc)
ibMin=$(cat $DCRAB_IREPORT_DATA_DIR/$lastFile | cut -d' ' -f3)
ibMin=$(echo "scale=3; $ibMin / (1024 * 1024 * $time * $nNodes) " | bc)
diskMax=$(cat $DCRAB_IREPORT_DATA_DIR/$lastFile | cut -d' ' -f4)
diskMax=$(echo "scale=3; (($diskMax * 512 )/1024 )/1024" | bc)
diskMin=$(cat $DCRAB_IREPORT_DATA_DIR/$lastFile | cut -d' ' -f4)
diskMin=$(echo "scale=3; (($diskMin * 512 )/1024 )/1024" | bc)
declare -a ibData
declare -a ibCounter; for i in $(seq 0 $((DCRAB_NUMBER_OF_BARS - 1))); do ibCounter[$i]=0; done
declare -a diskData
declare -a diskCounter; for i in $(seq 0 $((DCRAB_NUMBER_OF_BARS - 1))); do diskCounter[$i]=0; done
declare -a ibDataPerDay; for i in $(seq 0 $((days - 1))); do ibDataPerDay[$i]=0; done
declare -a diskDataPerDay; for i in $(seq 0 $((days - 1))); do diskDataPerDay[$i]=0; done
ibString=""
diskString=""
ibStringPerDay=""
diskStringPerDay=""

# Collect all the data from all the jobs 
i=0
for file in $DCRAB_IREPORT_DATA_DIR/*
do
	i=$((i+1))

	# File date
	date=$(ls -lt --time-style="+%s" $file | grep -v total | head -1 | sed 's|\s\s*| |g' |  cut -d' ' -f6)

	# File data
	time=$(cat $file | cut -d' ' -f1)	
	nNodes=$(cat $file | cut -d' ' -f2)
	ibValue=$(cat $file | cut -d' ' -f3)
	diskValue=$(cat $file | cut -d' ' -f4)

	# IB
	ib_aux=$(echo "scale=3; $ibValue / (1024 * 1024 * $time * $nNodes) " | bc)
	ibData[$i]=$ib_aux
	[ $(echo "$ibMax < $ib_aux" | bc) -eq 1 ] && ibMax=$ib_aux
        [ $(echo "$ibMin > $ib_aux" | bc) -eq 1 ] && ibMin=$ib_aux

	# Disk
	disk_aux=$(echo "scale=3; (($diskValue * 512 )/1024 )/1024" | bc)
	diskData[$i]=$disk_aux
	[ $(echo "$diskMax < $disk_aux" | bc) -eq 1 ] && diskMax=$disk_aux
        [ $(echo "$diskMin > $disk_aux" | bc) -eq 1 ] && diskMin=$disk_aux
	
	d=$(echo "($date - $firstDate)/(24*3600)" | bc)
	# IB per day
	ibDataPerDay[$d]=$(echo "${ibDataPerDay[$d]} + $ib_aux" | bc) 	

	# Disk per day
	diskDataPerDay[$d]=$(echo "${diskDataPerDay[$d]} + $disk_aux" | bc)
done

# Calculate the intervals for the charts
ib_interval=$(echo "scale=3; ($ibMax - $ibMin)/$DCRAB_NUMBER_OF_BARS" | bc)
disk_interval=$(echo "scale=3; ($diskMax - $diskMin)/$DCRAB_NUMBER_OF_BARS" | bc)

# Counter the number of jobs in each interval
for j in $(seq 1 $i); do
	# IB
	position=$(echo "(${ibData[${j}]} - $ibMin)/$ib_interval" | bc)
	[ $position -eq $DCRAB_NUMBER_OF_BARS ] && position=$((position -1))
	ibCounter[$position]=$( echo "${ibCounter[${position}]} + 1" | bc ) 
	
	# Disk
	position=$(echo "(${diskData[${j}]} - $diskMin)/$disk_interval" | bc)
	[ $position -eq $DCRAB_NUMBER_OF_BARS ] && position=$((position -1))
	diskCounter[$position]=$( echo "${diskCounter[${position}]} + 1" | bc ) 
done

# Construct the rows of the first two charts
for j in $(seq 0 $((DCRAB_NUMBER_OF_BARS -1)) )
do
	if [ $j -eq 0 ]; then
		ibString="$ibString [ '[$(echo "$ibMin + ($ib_interval * $j)" | bc),$(echo "$ibMin + ($ib_interval * ($j + 1))" | bc)]', ${ibCounter[$j]} ],"
		diskString="$diskString [ '[$(echo "$diskMin + ($disk_interval * $j)" | bc),$(echo "$diskMin + ($disk_interval * ($j + 1))" | bc)]', ${diskCounter[$j]} ],"
	else
		ibString="$ibString [ '($(echo "$ibMin + ($ib_interval * $j)" | bc),$(echo "$ibMin + ($ib_interval * ($j + 1))" | bc)]', ${ibCounter[$j]} ],"
		diskString="$diskString [ '($(echo "$diskMin + ($disk_interval * $j)" | bc),$(echo "$diskMin + ($disk_interval * ($j + 1))" | bc)]', ${diskCounter[$j]} ],"
	fi
done

# Construct the rows of the rest charts
for j in $(seq 0 $((days-1)) )
do
	# Calculate the day
	d=$(echo "$firstDateReduced * ($j * 3600*24)" | bc)
	d=$(date -d@$d +%d/%m/%y)

	ibStringPerDay="$ibStringPerDay ['$d', ${ibDataPerDay[$j]}],"	
	diskStringPerDay="$diskStringPerDay ['$d', ${diskDataPerDay[$j]}],"	
done

# Generate the report
printf "%s \n" "<html>" > $DCRAB_IREPORT
printf "%s \n" "<head><title>DCRAB INTERNAL STATISTICS</title>" >> $DCRAB_IREPORT
printf "%s \n" "<script type=\"text/javascript\" src=\"https://www.gstatic.com/charts/loader.js\"></script>" >> $DCRAB_IREPORT
printf "%s \n" "<script type=\"text/javascript\">" >> $DCRAB_IREPORT
printf "%s \n" "google.charts.load('current', {'packages':['bar','corechart']});" >> $DCRAB_IREPORT
printf "%s \n" "google.charts.setOnLoadCallback(drawVisualization);" >> $DCRAB_IREPORT
printf "%s \n" "" >> $DCRAB_IREPORT
printf "%s \n" "function drawVisualization() {" >> $DCRAB_IREPORT

# IB chart
printf "%s \n" "var data1 = google.visualization.arrayToDataTable([" >> $DCRAB_IREPORT
printf "%s \n" "['Interval', 'Number of jobs']," >> $DCRAB_IREPORT
printf "%s \n" "$ibString" >> $DCRAB_IREPORT
printf "%s \n" "]);" >> $DCRAB_IREPORT
printf "%s \n" "var options1 = {" >> $DCRAB_IREPORT
printf "%s \n" "chart: {" >> $DCRAB_IREPORT
printf "%s \n" "title: 'Infiniband Statistics'," >> $DCRAB_IREPORT
printf "%s \n" "subtitle: 'From $firstDateFormated to $lastDateFormated ($i jobs analized)'," >> $DCRAB_IREPORT
printf "%s \n" "}," >> $DCRAB_IREPORT
printf "%s \n" "bars: 'vertical'," >> $DCRAB_IREPORT
printf "%s \n" "vAxis: {format: 'decimal'}," >> $DCRAB_IREPORT
printf "%s \n" "height: 400," >> $DCRAB_IREPORT
printf "%s \n" "legend: { position: 'none' }," >> $DCRAB_IREPORT
printf "%s \n" "bar: { groupWidth: \"90%\" }," >> $DCRAB_IREPORT
printf "%s \n" "axes: {" >> $DCRAB_IREPORT
printf "%s \n" "x: {" >> $DCRAB_IREPORT
printf "%s \n" "0: { label: 'MBps per node'} // Top x-axis." >> $DCRAB_IREPORT
printf "%s \n" "}," >> $DCRAB_IREPORT
printf "%s \n" "y: {" >> $DCRAB_IREPORT
printf "%s \n" "0: {label: 'Number of jobs'}" >> $DCRAB_IREPORT
printf "%s \n" "}" >> $DCRAB_IREPORT
printf "%s \n" "}," >> $DCRAB_IREPORT
printf "%s \n" "};" >> $DCRAB_IREPORT
printf "%s \n" "var chart = new google.charts.Bar(document.getElementById('chart_div1'));" >> $DCRAB_IREPORT
printf "%s \n" "chart.draw(data1,google.charts.Bar.convertOptions(options1));" >> $DCRAB_IREPORT

# Disk chart
printf "%s \n" "var data2 = google.visualization.arrayToDataTable([" >> $DCRAB_IREPORT
printf "%s \n" "['Interval', 'Number of jobs']," >> $DCRAB_IREPORT
printf "%s \n" "$diskString" >> $DCRAB_IREPORT
printf "%s \n" "]);" >> $DCRAB_IREPORT
printf "%s \n" "var options2 = {" >> $DCRAB_IREPORT
printf "%s \n" "chart: {" >> $DCRAB_IREPORT
printf "%s \n" "title: 'Lscratch I/O'," >> $DCRAB_IREPORT
printf "%s \n" "subtitle: 'From $firstDateFormated to $lastDateFormated ($i jobs analized)'," >> $DCRAB_IREPORT
printf "%s \n" "}," >> $DCRAB_IREPORT
printf "%s \n" "bars: 'vertical'," >> $DCRAB_IREPORT
printf "%s \n" "vAxis: {format: 'decimal'}," >> $DCRAB_IREPORT
printf "%s \n" "height: 400," >> $DCRAB_IREPORT
printf "%s \n" "legend: { position: 'none' }," >> $DCRAB_IREPORT
printf "%s \n" "bar: { groupWidth: \"90%\" }," >> $DCRAB_IREPORT
printf "%s \n" "axes: {" >> $DCRAB_IREPORT
printf "%s \n" "x: {" >> $DCRAB_IREPORT
printf "%s \n" "0: { label: 'MB'} // Top x-axis." >> $DCRAB_IREPORT
printf "%s \n" "}," >> $DCRAB_IREPORT
printf "%s \n" "y: {" >> $DCRAB_IREPORT
printf "%s \n" "0: {label: 'Number of jobs'}" >> $DCRAB_IREPORT
printf "%s \n" "}" >> $DCRAB_IREPORT
printf "%s \n" "}," >> $DCRAB_IREPORT
printf "%s \n" "};" >> $DCRAB_IREPORT
printf "%s \n" "var chart = new google.charts.Bar(document.getElementById('chart_div2'));" >> $DCRAB_IREPORT
printf "%s \n" "chart.draw(data2,google.charts.Bar.convertOptions(options2));" >> $DCRAB_IREPORT

# IB per day chart
printf "%s \n" "var data3 = google.visualization.arrayToDataTable([" >> $DCRAB_IREPORT
printf "%s \n" "['Day', 'MBps per day']," >> $DCRAB_IREPORT
printf "%s \n" "$ibStringPerDay" >> $DCRAB_IREPORT
printf "%s \n" "]);" >> $DCRAB_IREPORT
printf "%s \n" "var options3 = {" >> $DCRAB_IREPORT
printf "%s \n" "vAxis: {" >> $DCRAB_IREPORT
printf "%s \n" "title: 'MBps'" >> $DCRAB_IREPORT
printf "%s \n" "}," >> $DCRAB_IREPORT
printf "%s \n" "title: 'Infiniband usage per day'," >> $DCRAB_IREPORT
printf "%s \n" "curveType: 'function'," >> $DCRAB_IREPORT
printf "%s \n" "legend: { position: 'bottom' }" >> $DCRAB_IREPORT
printf "%s \n" "};" >> $DCRAB_IREPORT
printf "%s \n" "var chart = new google.visualization.LineChart(document.getElementById('chart_div3'));" >> $DCRAB_IREPORT
printf "%s \n" "chart.draw(data3, options3);" >> $DCRAB_IREPORT

# Disk per day chart
printf "%s \n" "var data4 = google.visualization.arrayToDataTable([" >> $DCRAB_IREPORT
printf "%s \n" "['Day', 'MB per day']," >> $DCRAB_IREPORT
printf "%s \n" "$diskStringPerDay" >> $DCRAB_IREPORT
printf "%s \n" "]);" >> $DCRAB_IREPORT
printf "%s \n" "var options4 = {" >> $DCRAB_IREPORT
printf "%s \n" "vAxis: {" >> $DCRAB_IREPORT
printf "%s \n" "title: 'MB'" >> $DCRAB_IREPORT
printf "%s \n" "}," >> $DCRAB_IREPORT
printf "%s \n" "title: 'Lscratch usage per day'," >> $DCRAB_IREPORT
printf "%s \n" "curveType: 'function'," >> $DCRAB_IREPORT
printf "%s \n" "legend: { position: 'bottom' }" >> $DCRAB_IREPORT
printf "%s \n" "};" >> $DCRAB_IREPORT
printf "%s \n" "var chart = new google.visualization.LineChart(document.getElementById('chart_div4'));" >> $DCRAB_IREPORT
printf "%s \n" "chart.draw(data4, options4);" >> $DCRAB_IREPORT

printf "%s \n" "}" >> $DCRAB_IREPORT
printf "%s \n" "</script>" >> $DCRAB_IREPORT
printf "%s \n" "</head>" >> $DCRAB_IREPORT
printf "%s \n" "<body>" >> $DCRAB_IREPORT
printf "%s \n" "<center><h1>DCRAB INTERNAL STATISTICS </h1></center>"  >> $DCRAB_IREPORT
printf "%s \n" "<div id=\"chart_div1\" style=\"margin: 100px; padding-bottom: 100px;\"></div>" >> $DCRAB_IREPORT
printf "%s \n" "<div id=\"chart_div2\" style=\"margin: 100px; padding-bottom: 100px;\"></div>" >> $DCRAB_IREPORT
printf "%s \n" "<div id=\"chart_div3\" style=\"margin: 100px; padding-bottom: 100px;\"></div>" >> $DCRAB_IREPORT
printf "%s \n" "<div id=\"chart_div4\" style=\"margin: 100px; padding-bottom: 100px;\"></div>" >> $DCRAB_IREPORT
printf "%s \n" "</body>" >> $DCRAB_IREPORT
printf "%s \n" "</html>" >> $DCRAB_IREPORT
