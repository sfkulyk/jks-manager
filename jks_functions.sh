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
NL="
"

debug() {
  echo "DEBUG: $1"
}

# $1: cert name, $2: keystore file, $3: storepass
delete_cert() {
  echo -n "${NL}Write [${red}yes${rst}] or [${red}YES${rst}] to delete [${green}${1}${rst}] from ${green}${2}${rst}: "
  read	
  if [ "$REPLY" == yes -o "$REPLY" == YES ]; then
    echo "${red}Removing certificate [$1]${rst}"
    keytool -delete -alias "${1}" -keystore "${2}" -storepass ${3}
    if [ $? -eq 0 ]; then
      echo "Certificate ${blue}${1}${rst} succesfully removed from ${2}"
    else
      echo "${red}Error deleting ${1} from ${2}${rst}"
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

# $1 - keystore, $2 - keystore pass
init_certs() {
  echo "Opening ${green}${1}${rst} ..."
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
  done<<<$(keytool -list -v -keystore ${1} -storepass ${2}|grep -P "(Alias name:|Serial number:|Valid from:)"|grep "Alias name:" -A 2)
}

# print cert menu
print_certs() {
  typeset -i cnt=1
  printf "[%s] %s %s\n" "Valid to  " "Serial No                       " "Alias"
  for entry in ${certName[@]}; do
    [ $cnt == $ENTRY ] && color="${blueb}" || color=""
    printf "${color}[%s] %s %s${rst}\n" "${certValid[$cnt]}" ${certSerial[$cnt]} "$entry"
    cnt+=1
  done
}

# export_cert $Alias $Keystore $Storepass
export_cert() {
  ALIASNAME=$(echo "${1}"|tr -d '[]()#*?\\/'|tr " " "_")
  while true; do
    echo "${NL}1. ${green}J${rst}KS${NL}2. ${green}P${rst}KCS12${NL}3. ${green}c${rst}rt${NL}4. ${red}Q${rst}uit${NL}${NL}Choose export format for ${green}${1}${rst}: "
    read -rsN1
    case $REPLY in
      j|J|1) FILENAME="${ALIASNAME}.jks"
             echo -n "Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             [ -n "$REPLY" ] && FILENAME="$REPLY"
             keytool -importkeystore -srckeystore "${2}" -destkeystore "${FILENAME}" -srcalias "${1}" -destalias "${1}" -srcstorepass ${3} -deststorepass ${3} -deststoretype jks
             if [ $? -eq 0 ]; then echo "Certificate ${blue}${1}${rst} is succesfully exported to ${FILENAME}"
               else                echo "${red}Error with exporting ${1} to ${FILENAME}${rst}"
             fi;;
      p|P|2) FILENAME="${ALIASNAME}.pkcs12"
             echo -n "Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             [ -n "$REPLY" ] && FILENAME="$REPLY"
             keytool -importkeystore -srckeystore "${2}" -destkeystore "${FILENAME}" -srcalias "${1}" -destalias "${1}" -srcstorepass ${3} -deststorepass ${3} -deststoretype pkcs12
             if [ $? -eq 0 ]; then echo "Certificate ${blue}${1}${rst} is succesfully exported to ${FILENAME}"
               else                echo "${red}Error with exporting ${1} to ${FILENAME}${rst}"
             fi;;
      c|C|3) FILENAME="${ALIASNAME}.cer"
             echo -n "Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             keytool -exportcert -v -alias "${1}" -keystore "${2}" -storepass ${3} -rfc -file "${FILENAME}"
             if [ $? -eq 0 ]; then
               echo "Certificate ${blue}${1}${rst} is succesfully exported to ${FILENAME}"
             else
               echo "${red}Error with exporting ${1} to ${FILENAME}${rst}"
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