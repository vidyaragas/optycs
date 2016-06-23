##########################
#1. download todays bhavfile
#2. download todays volatility file
#3. download lotsize file
#########################
tmon=$(date +"%b")
month=${tmon^^}
mon=$(date +"%m")
year=$(date +"%Y")
day=$(date +"%d")
rest="bhav.csv.zip"
restcsv="bhav.csv"
filename=fo$day$month$year$rest
csvfilename=fo$day$month$year$restcsv
cmnfilename=latestbhav.csv
voltrest=".csv"
voltfilename=FOVOLT_$day$mon$year$voltrest
echo $filename 
echo $csvfilename
echo $cmnfilename
echo "======================Downloading $filename ============================="
wget -U Mozilla/5.0 https://www.nseindia.com/content/historical/DERIVATIVES/$year/$month/$filename
unzip $filename 
mv  $csvfilename ../data/$cmnfilename
rm -r $filename 
echo "======================Downloading $voltfilename ============================="
wget -U Mozilla/5.0 https://www.nseindia.com/archives/nsccl/volt/$voltfilename
mv $voltfilename ../data/volatility.csv
echo "======================Downloading lotsize file ============================"
wget -U Mozilla/5.0 https://www.nseindia.com/content/fo/fo_mktlots.csv
mv fo_mktlots.csv ../data/.

