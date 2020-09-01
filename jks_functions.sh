#
# Author: Sergii Kulyk aka Saboteur
# Version 1.0
# * List of certificates in JKS
# * View some details (Alias, Serial, Valid date)
# * Export to JKS, PKCS12, CRT
# * Delete certificate
#

red=$(tput bold;tput setaf 1)
green=$(tput bold;tput setaf 2)
blue=$(tput bold;tput setaf 6)
blueb=$(tput bold;tput setab 6)
rst=$(tput sgr0)
MYROWS=$(tput lines)
MYCOLS=$(tput cols)

COLUMNS=1	# for select command
STOREPASS="changeme"
NL="
"

debug() {
  echo "DEBUG: $1"
}

# $1: cert name, $2: keystore file
delete_cert() {
  echo -n "${NL}Write [${red}yes${rst}] or [${red}YES${rst}] to delete [${green}${1}${rst}] from ${green}${2}${rst}: "
  read	
  if [ "$REPLY" == yes -o "$REPLY" == YES ]; then
    echo "${red}Removing certificate [$1]${rst}"
    keytool -delete -alias "${1}" -keystore "${2}" -storepass ${STOREPASS}
    if [ $? -eq 0 ]; then
      echo "Certificate ${blue}${certName[$ENTRY]}${rst} succesfully removed from ${FILENAME}"
    else
      echo "${red}Error deleting ${certName[$ENTRY]} from ${FILENAME}${rst}"
    fi
    sleep 1
  else
    echo "${red}Cancelled.${rst}"
    sleep 1
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
  unset certSerial[$cnt]
  unset certValid[$cnt]
  unset certDays[$cnt]
  certMax=$((certMax-1))
}

init_certs() {
  echo "Opening ${green}${FILE}${rst} ..."
  # initialize cert list from keystore
  typeset -i cnt=1
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
      certMax=$cnt
      cnt+=1
    fi
  done<<<$(keytool -list -v -keystore ${1} -storepass ${STOREPASS}|grep -P "(Alias name:|Serial number:|Valid from:)"|grep "Alias name:" -A 2)
}

print_certs() {
  typeset -i cnt=1
  printf "[%s] %s %s\n" "Valid to  " "Serial No                       " "Alias"
  for entry in ${certName[@]}; do
    [ $cnt == $ENTRY ] && color="${blueb}" || color=""
    printf "${color}[%s] %s %s${rst}\n" "${certValid[$cnt]}" ${certSerial[$cnt]} "$entry"
    cnt+=1
  done
}

export_cert() {
  FILENAME=$(echo "${certName[$ENTRY]}"|tr -d '[]()#*?\\/'|tr " " "_")
  PS3="${NL}Choose export format for ${green}${certName[$ENTRY]}${rst}: "

  select format in "JKS" "PKCS12" "crt" "Quit"; do
    FILENAME="$FILENAME.$(echo -n $format|tr '[:upper:]' '[:lower:]')"
    case $REPLY in
      j|J|1) echo -n "Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             [ -n "$REPLY" ] && FILENAME="$REPLY"
             keytool -importkeystore -srckeystore "${FILE}" -destkeystore "${FILENAME}" -srcalias "${certName[$ENTRY]}" -destalias "${certName[$ENTRY]}" -srcstorepass ${STOREPASS} -deststorepass ${STOREPASS} -deststoretype ${format}
             if [ $? -eq 0 ]; then
               echo "Certificate ${blue}${certName[$ENTRY]}${rst} is succesfully exported to ${FILENAME}"
             else
               echo "${red}Error with exporting ${certName[$ENTRY]} to ${FILENAME}${rst}"
             fi;;
      p|P|2) echo -n "Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             [ -n "$REPLY" ] && FILENAME="$REPLY"
             keytool -importkeystore -srckeystore "${FILE}" -destkeystore "${FILENAME}" -srcalias "${certName[$ENTRY]}" -destalias "${certName[$ENTRY]}" -srcstorepass ${STOREPASS} -deststorepass ${STOREPASS} -deststoretype ${format}
             if [ $? -eq 0 ]; then
               echo "Certificate ${blue}${certName[$ENTRY]}${rst} is succesfully exported to ${FILENAME}"
             else
               echo "${red}Error with exporting ${certName[$ENTRY]} to ${FILENAME}${rst}"
             fi;;
      c|C|3) echo -n "Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             keytool -exportcert -v -alias "${certName[$ENTRY]}" -keystore "${FILE}" -storepass ${STOREPASS} -rfc -file "${FILENAME}"
             if [ $? -eq 0 ]; then
               echo "Certificate ${blue}${certName[$ENTRY]}${rst} is succesfully exported to ${FILENAME}"
             else
               echo "${red}Error with exporting ${certName[$ENTRY]} to ${FILENAME}${rst}"
             fi;;
      q|Q|4) break;;
    esac
  done
  echo "${green}Done.${rst}${NL}"
}

print_details() {
  echo "${NL}Details for certificate [${green}${certName[$ENTRY]}${rst}]:"
  echo "Serial number: ${certSerial[$ENTRY]}"
  echo "Valid to: ${certValid[$ENTRY]}"
  echo "Days left: ${certDays[$ENTRY]}"
  echo "${NL}Press any key"
  read -rsn1
}