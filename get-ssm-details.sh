#!/bin/bash

JSON_PATH="json/inventory json/patch/list json/patch/summary"
CSV_PATH="csv/inventory csv/patch/list csv/patch/summary"
INSTANCEIDS_TEXTFILE="instance-id.txt"

if [ ! -d "$JSON_PATH" ]; then
  mkdir -p $JSON_PATH
fi

if [ ! -d "$CSV_PATH" ]; then
  mkdir -p $CSV_PATH
fi

RED='\033[01;31m'
YELLOW='\033[0;33m'
NONE='\033[00m'

print_help(){
  echo -e "${YELLOW}Use the following Command:"
  echo -e "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e "${RED}./<script-name> --action <action-name>"
  echo -e "${YELLOW}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  printf "Choose one of the available actions below:\n"
  printf " get-inventory-list\n get-patch-list\n get-patch-summary\n $NONE"
}

ARG="$#"
if [[ $ARG -eq 0 ]]; then
  print_help
  exit
fi

while test -n "$1"; do
 case "$1" in
  --action)
ACTION=$2
shift
;;
*)
print_help
exit
;;
esac
shift
done

get_inventory_list(){
  for instanceid in `cat $INSTANCEIDS_TEXTFILE` ; do

    FILENAME=$instanceid"-inventory"
    echo "Getting the inventory details for $instanceid in json/inventory/$FILENAME.json"

    LIST="aws ssm list-inventory-entries --instance-id $instanceid --type-name AWS:Application --output json"
    $LIST  > json/inventory/$FILENAME.json
    NEXT_TOKEN=$($LIST | jq .NextToken | tr -d '"')

    echo "..."

    while [ "${NEXT_TOKEN}" != "null" ]
    do
      LIST="aws ssm list-inventory-entries --instance-id $instanceid --type-name AWS:Application --next-token $NEXT_TOKEN --output json"
      $LIST  >> json/inventory/$FILENAME.json
      NEXT_TOKEN=$($LIST | jq .NextToken | tr -d '"')
      echo "..."
    done

    echo "Generating CSV file"

    echo "..."

    echo '"Publisher","Name","URL","Summary","Version","ApplicationType","PackageId","InstalledTime","Architecture"' > csv/inventory/$FILENAME.csv | cat json/inventory/$FILENAME.json | jq -r '.Entries[] | [.Publisher, .Name, .URL, .Summary, .Version, .ApplicationType, .PackageId, .InstalledTime, .Architecture] | @csv' >> csv/inventory/$FILENAME.csv

    echo "Generated CSV file: csv/inventory/$FILENAME.csv"

  done
}

get_patch_list(){
  for instanceid in `cat $INSTANCEIDS_TEXTFILE` ; do

    FILENAME=$instanceid"-patch"
    echo "Getting the patch details for $instanceid in json/patch/list/$FILENAME.json"

    LIST="aws ssm describe-instance-patches --instance-id $instanceid --output json"
    $LIST  > json/patch/list/$FILENAME.json
    NEXT_TOKEN=$($LIST | jq .NextToken | tr -d '"')

    echo "..."

    while [ "${NEXT_TOKEN}" != "null" ]
    do
      LIST="aws ssm describe-instance-patches --instance-id $instanceid --next-token $NEXT_TOKEN --output json"
      $LIST  >> json/patch/list/$FILENAME.json
      NEXT_TOKEN=$($LIST | jq .NextToken | tr -d '"')
      echo "..."
    done

    echo "Generating CSV file"

    echo "..."

    echo '"KBId","Severity","Classification","Title","State","InstalledTime"' > csv/patch/list/$FILENAME.csv | cat json/patch/list/$FILENAME.json | jq -r '.Patches[] | [.KBId, .Severity, .Classification, .Title, .State, .InstalledTime] | @csv' >> csv/patch/list/$FILENAME.csv

    echo "Generated CSV file: csv/patch/list/$FILENAME.csv"

  done
}

get_patch_summary(){
  for instanceid in `cat $INSTANCEIDS_TEXTFILE` ; do

    JSONFILENAME=$instanceid"-patchsummary"
    CSVFILENAME="$instanceid-patchsummary"
    FORMATTEDCSVFILENAME='formatted-instances-patchsummary'

    echo "Getting the patch details for $instanceid in json/patch/summary/$JSONFILENAME.json"

    LIST="aws ssm describe-instance-patch-states --instance-id $instanceid --output json"
    $LIST  > json/patch/summary/$JSONFILENAME.json

    TIMESTAMP=$($LIST | jq -r .InstancePatchStates[].OperationEndTime)

    echo "Converting timestamp to date"
    LASTUPDATED='"'$(date -d @$TIMESTAMP)'"'
    echo "Last Updated time is: "$LASTUPDATED

    echo "Generating CSV file"

    echo "..."

    cat json/patch/summary/$JSONFILENAME.json | jq -r '.InstancePatchStates[] | [.MissingCount, .InstalledCount, .FailedCount] | @csv' >> csv/patch/summary/$CSVFILENAME.csv

    instanceid='"'$instanceid'"'

    RESULT=$(awk -F"," -v value="$LASTUPDATED" 'BEGIN { OFS = "," } {$4=value; print}' csv/patch/summary/$CSVFILENAME.csv)

    echo $RESULT >> csv/patch/summary/tmp-$CSVFILENAME.csv

    RESULT=$(awk -v column=1 -v value="$instanceid" '
      BEGIN {
        FS = OFS = ",";
      }
      {
        for ( i = NF + 1; i > column; i-- ) {
          $i = $(i-1);
        }
        $i = value;
        print $0;
      }
      ' csv/patch/summary/tmp-$CSVFILENAME.csv)

echo $RESULT > csv/patch/summary/tmp-$CSVFILENAME.csv

done

for file in csv/patch/summary/tmp-*.csv ; do
  cat $file >> csv/patch/summary/$FORMATTEDCSVFILENAME.csv
done

sed -i '1 i\
"InstanceId","UpdatesNeeded","UpdatesInstalled","UpdatesWithErrors","OperationEndTime"' csv/patch/summary/$FORMATTEDCSVFILENAME.csv

echo "Generated CSV file: csv/patch/summary/$FORMATTEDCSVFILENAME.csv"
}

if [[ $ARG -ne 2 ]];
  then
  echo "Incorrect No. of Arguments Provided"
  print_help
  exit 1

elif [ "$ACTION" = "get-inventory-list" ];then
  get_inventory_list

elif [ "$ACTION" = "get-patch-list" ];then
  get_patch_list

elif [ "$ACTION" = "get-patch-summary" ];then
  get_patch_summary

else
  echo "incorrect action specified"
  print_help
fi
