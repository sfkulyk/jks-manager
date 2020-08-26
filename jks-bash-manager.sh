#!/bin/ksh
red=$(tput bold;tput setaf 1)
green=$(tput bold;tput setaf 2)
blue=$(tput bold;tput setaf 6)
rst=$(tput sgr0)
COLUMNS=1	# for select command
STOREPASS="changeme"
NL="
"

debug() {
  echo "DEBUG: $1"
}

# $1: cert name, $2: keystore file
delete_cert() {
  echo -n "Write [${red}yes${rst}] or [${red}YES${rst}] to delete [${green}${1}${rst}] from ${green}${2}${rst}: "
  read	
  if [ "$REPLY" == yes -o "$REPLY" == YES ]; then
    keytool -delete -alias "${1}" -keystore "${2}" -storepass ${STOREPASS}
    echo "${red}Removing certificate [$1]${rst}"
  else
    echo "${red}Cancelled.${rst}"
    return
  fi

  typeset -i cnt=2 next=3
  found=0
  while [ -n "${certName[$next]}" ]; do
    [ "${certName[$cnt]}" == "${1}" ] && found=1
    if [ $found == 1 ] ; then
      certName[$cnt]=${certName[$next]}
      certSerial[$cnt]=${certSerial[$next]}
      certValid[$cnt]=${certValid[$next]}
      certDays[$cnt]=${certDays[$next]}
      certTitle[$cnt]=${certTitle[$next]}
    fi
    cnt+=1; next+=1
  done
  unset certTitle[$cnt]
  unset certName[$cnt]
}

if [ -z "$1" ]; then
  echo -n "Provide keystore name (press ENTER to use default ${green}truststore.jks${rst}): "
  read
  [ -z "$REPLY" ] && FILE="truststore.jks"
else
  FILE="$1"
fi

echo "Opening ${green}${FILE}${rst} ..."
RESULT=$(keytool -list -v -keystore $FILE -storepass ${STOREPASS}|grep -P "(Alias name:|Serial number:|Valid from:)"|grep "Alias name:" -A 2)

# initialize cert list from keystore
typeset -A certName
typeset -A certSerial
typeset -A certValid
typeset -A certDays
typeset -A certTitle
typeset -i cnt=2
while read; do
  if expr "$REPLY" : "Alias name: ">/dev/null; then
    certName[$cnt]="${REPLY##*: }"
  elif expr "$REPLY" : "Serial number: ">/dev/null; then
    certSerial[$cnt]="${REPLY##*: }"
  else
    certValid[$cnt]=$(/bin/date --date="${REPLY##*until: }" "+%Y-%m-%d")
    validunix=$(/bin/date --date="${REPLY##*until: }" "+%s")
    certDays[$cnt]=$(( (${validunix} - $(/bin/date "+%s")) / 3600 / 24 ))
    certTitle[$cnt]=$(printf "%s %s\n" "${certValid[$cnt]}" "${certName[$cnt]}")
    cnt+=1
  fi
done<<<"$RESULT"

# main loop
echo "${NL}Keystore ${green}${FILE}${rst} list:"
while true; do
  PS3="${NL}Choose certificate entry: "
  select item in "${blue}exit${rst}" "${certTitle[@]}"; do
    if [ "$item" == "${blue}exit${rst}" ]; then
      echo "${green}Good bye${rst}"
      exit 0
    fi
    ENTRY=$REPLY
    echo "Selected: ${green}${certName[$ENTRY]}${rst}${NL}"
    PS3="${NL}Choose action for ${green}${certName[$ENTRY]}${rst}: "
    select action in "${blue}Exit to list${rst}" "Details" "Export" "Delete"; do
      case $REPLY in
        1) echo "${NL}Keystore ${green}${FILE}${rst} list:"
           break 2;;
        2) echo "${NL}Details for entry: [${green}${certName[$ENTRY]}${rst}]"
           echo "Serial number: ${certSerial[$ENTRY]}"
           echo "Valid to: ${certValid[$ENTRY]}"
           echo "Days left: ${certDays[$ENTRY]}";;
        3) PS3="${NL}Choose export format for ${green}${certName[$ENTRY]}${rst}: "
           FILENAME=$(echo "${certName[$ENTRY]}"|tr -d '[]()#*?\\/'|tr " " "_")
           select format in "JKS" "PKCS12" "crt" "${red}Cancel${rst}"; do
             case $REPLY in
             1|2) ext=$( echo $format | tr '[:upper:]' '[:lower:]')
                FILENAME="$FILENAME.${ext}"
                echo -n "Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
                read
                [ -n "$REPLY" ] && FILENAME="$REPLY"
                keytool -importkeystore -srckeystore "${FILE}" -destkeystore "${FILENAME}" -srcalias "${certName[$ENTRY]}" -destalias "${certName[$ENTRY]}" -srcstorepass ${STOREPASS} -deststorepass ${STOREPASS} -deststoretype ${format}
                break;;
             3) echo -n "Provide export file name (press ENTER to use: ${green}${FILENAME}.crt${rst}) :"
                read
                keytool -exportcert -v -alias "${certName[$ENTRY]}" -keystore "${FILE}" -storepass ${STOREPASS} -rfc -file "${FILENAME}.crt"
                break;;
             4) PS3="${NL}Choose action for ${green}${certName[$ENTRY]}${rst}: "
                break;;
            esac
            done
           echo "${green}Done.${rst}${NL}";;
        4) delete_cert "${certName[$ENTRY]}" "${FILE}"
           echo "${NL}Keystore ${green}${FILE}${rst} list:"
           break 2;;
      esac
    done
  done
done
