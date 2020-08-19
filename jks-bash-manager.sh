#!/usr/env bash
red=$(tput bold;tput setaf 1)
green=$(tput bold;tput setaf 2)
blue=$(tput bold;tput setaf 6)
reset=$(tput sgr0)

if [ -z "$1" ]; then
  read -p "Provide keystore name (press ENTER to use default ${green}truststore.jks${reset}): "
  [ -z "$REPLY" ] && FILE="truststore.jks"
else
  FILE="$1"
fi
STOREPASS="changeme"

NL="
"
echo "Opening ${green}${FILE}${reset} ..."
RESULT=$(keytool -list -v -keystore $FILE -storepass ${STOREPASS}|grep -P "(Alias name:|Serial number:|Valid from:)"|grep "Alias name:" -A 2)

declare -A certificates
declare -i counter=1
alias=""
serial=""
valid=""
while read; do
  if [[ $REPLY =~ Alias ]]; then
    alias=${REPLY##*: }
  elif [[ $REPLY =~ Serial ]]; then
    serial=${REPLY##*: }
  else
    valid=$(/bin/date --date="${REPLY##*until: }" "+%Y-%m-%d")
    validunix=$(/bin/date --date="${REPLY##*until: }" "+%s")
    days=$(( (${validunix} - $(/bin/date "+%s")) / 3600 / 24 ))
    certificates[$counter,0]="$alias"
    certificates[$counter,1]="$serial"
    certificates[$counter,2]="$valid"
    certificates[$counter,3]="$days"
    certs[$counter]=$(printf "%s %s\n" "${certificates[$counter,2]}" "${certificates[$counter,0]}")
    counter+=1
  fi
done<<<"$RESULT"

COLUMNS=1	# for select command
echo "${NL}Keystore ${green}${FILE}${reset} list:"
while true; do
  PS3="${NL}Choose certificate entry: "
  select item in "${certs[@]}" "${blue}exit${reset}"; do
    if [ "$item" == "${blue}exit${reset}" ]; then
      echo "${green}Good bye${reset}"
      exit 0
    fi
    ENTRY=$REPLY
    echo ""
    PS3="${NL}Choose action: "
    select action in "Details" "Export" "Delete" "${blue}Back to list${reset}"; do
      case $REPLY in
        1) echo "${NL}Details for entry: [${green}${certificates[$ENTRY,0]}${reset}]"
           echo "Serial number: ${certificates[$ENTRY,1]}"
           echo "Valid to: ${certificates[$ENTRY,2]}"
           echo "Days left: ${certificates[$ENTRY,3]}";;
        2) echo "${NL}Exporting entry [${green}${certificates[$ENTRY,0]}${reset}]"
           FILENAME=$(echo "${certificates[$ENTRY,0]}"|tr -d '[]()#*?\\/'|tr " " "_")
           select format in "JKS" "PKCS12" "crt" "Cancel"; do
             case $REPLY in
             1|2) FILENAME="$FILENAME.${format~~}"
                read -p "Provide export file name (press ENTER to use: ${green}${FILENAME}${reset}) :"
                [[ -n "$REPLY" ]] && FILENAME="$REPLY"
                keytool -importkeystore -srckeystore "${FILE}" -destkeystore "${FILENAME}" -srcalias "${certificates[$ENTRY,0]}" -destalias "${certificates[$ENTRY,0]}" -srcstorepass ${STOREPASS} -deststorepass ${STOREPASS} -deststoretype ${format}
                break;;
             3) read -p "Provide export file name (press ENTER to use: ${green}${FILENAME}.crt${reset}) :"
                keytool -exportcert -v -alias "${certificates[$ENTRY,0]}" -keystore "${FILE}" -storepass ${STOREPASS} -rfc -file "${FILENAME}.crt"
                break;;
             4) break;;
            esac
            done
           echo "${green}Done.${reset}${NL}";;
        3) read -p "Write [${red}yes${reset}] or [${red}YES${reset}] to delete [${green}${certificates[$ENTRY,0]}${reset}] from ${green}${FILE}${reset}: "
           if [[ $REPLY =~ yes|YES ]]; then
             echo "${red}deleting...${reset}"
             #keytool -delete -alias "${certificates[$ENTRY,0]}" -keystore "${FILENAME}" -storepass ${STOREPASS}
           else
             echo "${red}Cancelled.${reset}"
           fi
           echo "${NL}Keystore ${green}${FILE}${reset} list:"
           break 2;;
        4) echo ""
           echo "${NL}Keystore ${green}${FILE}${reset} list:"
           break 2;;
      esac
    done
  done
done