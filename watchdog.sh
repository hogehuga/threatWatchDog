#!/bin/bash

## init
### set date
TODAY=$(date +"%Y-%m-%d")
DAY1=$(date --date '1 days ago' +"%Y-%m-%d")
DAY2=$(date --date '2 days ago' +"%Y-%m-%d")
###
KEVFile="./tmp/kev.csv"
EPSSToday="./tmp/epssToday.csv"
EPSSYesterday="./tmp/epssYesterday.csv"
EPSSJoin="./tmp/epssJoin.csv"
DB="./tmp/epss.db"

## file get
### kev file
#wget -q --no-check-certificate -O $KEVFile https://www.cisa.gov/sites/default/files/csv/known_exploited_vulnerabilities.csv
### epss file
#### file check
wget -q --no-check-certificate --spider https://epss.cyentia.com/epss_scores-$TODAY.csv.gz
ret=$?
if [ $ret -ne 0 ]; then
	echo "The file for $TODAY is not yet available in local-timezone."
	echo "We will use the file from the previous day($DAY1)"
	TODAY=$DAY1
	YESTERDAY=$DAY2
fi
### download
wget -q --no-check-certificate -O $EPSSToday.gz https://epss.cyentia.com/epss_scores-$TODAY.csv.gz
wget -q --no-check-certificate -O $EPSSYesterday.gz https://epss.cyentia.com/epss_scores-$YESTERDAY.csv.gz
### Extract gz file
gunzip ./tmp/*.gz

## Analyzed
### EPSS
echo "[insert db]: wait .."
join --nocheck-order -j 1 -t "," -a 1 <(tail -n +2 $EPSSToday) <(tail -n +2 $EPSSYesterday) -e "" -o 1.1,1.2,1.3,2.2,2.3 > $EPSSJoin
sed -i -e "s/$/,,/g" $EPSSJoin
sqlite3 $DB <<-EOF
create table epss(cveid text,todayepss real,todaypercentile real,yesterdayepss real,yesterdaypercentile real,epssdiff real,percentilediff real);
.mode csv
.import --skip 1 $EPSSJoin epss
update epss SET epssdiff = NULL;
update epss SET percentilediff = NULL;
update epss SET yesterdayepss = NULL where yesterdayepss = "";
update epss SET yesterdaypercentile = NULL where yesterdaypercentile = "";
update epss SET epssdiff = todayepss - yesterdayepss;
update epss SET percentilediff = todaypercentile - yesterdaypercentile;
EOF
### KEV Catalog

## Report
### header
echo -e "$TODAY.csv.gz file report.\n"
printf '|%-15s|%-8s|%-18s|%-18s|\n' CVE-ID Diff "EPSS(-1day)" "Percentile(-1day)"
printf '|%-15s|%-8s|%-18s|%-18s|\n' --------------- -------- ------------------ ------------------

### formatting
DIFFDATA=`sqlite3 $DB "select cveid,epssdiff,todayepss,yesterdayepss,todaypercentile,yesterdaypercentile from epss where epssdiff > 0.1 order by epssdiff desc;"`

echo "$DIFFDATA" | while read line
do
	data=$(echo $line | sed -e "s/|/\ /g")
	printf '|%-15s|%-7s |%-8s(%-7s) |%-8s(%-7s) |\n' $data
done

## Cleanup
rm ./tmp/*
