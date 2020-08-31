#!/bin/ksh
. $(dirname $0)/jks_functions.sh
#
# Author: Sergii Kulyk aka Saboteur
# Version 1.0
# * List of certificates in JKS
# * View some details (Alias, Serial, Valid date)
# * Export to JKS, PKCS12, CRT
# * Delete certificate
#

COLUMNS=1	# for select command
STOREPASS="changeme"
NL="
"

if [ -z "$1" ]; then
  echo -n "Provide keystore name (press ENTER to use default ${green}truststore.jks${rst}): "
  read
  [ -z "$REPLY" ] && FILE="truststore.jks"
else
  FILE="$1"
fi

typeset -A certName
typeset -A certSerial
typeset -A certValid
typeset -A certDays
typeset -A certTitle
init_certs "$FILE"

# main loop
while true; do
  print_certs
  echo -n "${NL}Choose certificate entry: "
  read ENTRY
  if [ -z "$ENTRY" ]; then continue; fi
  if [ "$ENTRY" == "1" ]; then echo "${green}Good bye${rst}"; exit 0; fi

  echo "Selected: ${green}${certName[$ENTRY]}${rst}${NL}"

  PS3="${NL}Choose action for ${green}${certName[$ENTRY]}${rst}: "
  select action in "${blue}Exit to list${rst}" "Details" "Export" "Delete"; do
    case $REPLY in
      1) echo "${NL}Keystore ${green}${FILE}${rst} list:"
         break;;
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
         break;;
    esac
  done
done
