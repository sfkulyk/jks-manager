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
  echo -n "${NL}Press ${red}y${rst}/${red}Y${rst} to delete [${green}$1${rst}] from ${green}$2${rst}: "
  read -N1
  if [ "$REPLY" == y -o "$REPLY" == Y ]; then
    echo "${NL}${red}Removing certificate [$1]${rst}"
    keytool -delete -alias "$1" -keystore "$2" -storepass "$3"
    if [ $? -eq 0 ]; then
      echo "Certificate ${blue}$1${rst} succesfully removed from $2"
    else
      echo "${red}Error deleting $1 from $2${rst}"
    fi
    sleep 1
  else
    echo "${NL}${red}Cancelled.${rst}"
    sleep 1
    return
  fi

  typeset -i cnt=1 next=2
  found=0
  if [ $TAB == "L" ]; then
    while [ -n "${LcertName[$next]}" ]; do
      [ "${LcertName[$cnt]}" == "$1" ] && found=1
      if [ $found == 1 ] ; then
        LcertName[$cnt]=${LcertName[$next]}
        LcertSerial[$cnt]=${LcertSerial[$next]}
        LcertValid[$cnt]=${LcertValid[$next]}
        LcertDays[$cnt]=${LcertDays[$next]}
        LcertTitle[$cnt]=${LcertTitle[$next]}
      fi
      cnt+=1; next+=1
    done
    unset LcertTitle[$cnt]
    unset LcertName[$cnt]
    unset LcertSerial[$cnt]
    unset LcertValid[$cnt]
    unset LcertDays[$cnt]
    LcertMax=$(($LcertMax-1))
  else
    while [ -n "${RcertName[$next]}" ]; do
      [ "${RcertName[$cnt]}" == "$1" ] && found=1
      if [ $found == 1 ] ; then
        RcertName[$cnt]=${RcertName[$next]}
        RcertSerial[$cnt]=${RcertSerial[$next]}
        RcertValid[$cnt]=${RcertValid[$next]}
        RcertDays[$cnt]=${RcertDays[$next]}
        RcertTitle[$cnt]=${RcertTitle[$next]}
      fi
      cnt+=1; next+=1
    done
    unset RcertTitle[$cnt]
    unset RcertName[$cnt]
    unset RcertSerial[$cnt]
    unset RcertValid[$cnt]
    unset RcertDays[$cnt]
    RcertMax=$(($RcertMax-1))
  fi
}

# $1 - keystore, $2 - keystore pass, $3 - tab
init_certs() {
  localTAB=$3
  echo "Opening ${green}$1${rst} ... as ${localTAB}"
  # initialize cert list from keystore
  typeset -i cnt=1
  while read; do
    if expr "$REPLY" : "Alias name: ">/dev/null; then
      localAlias="${REPLY##*: }"
    elif expr "$REPLY" : "Serial number: ">/dev/null; then
      eval ${localTAB}certSerial[$cnt]="${REPLY##*: }"
    else
      eval ${localTAB}certName[$cnt]="${localAlias}"
      eval ${localTAB}certValid[$cnt]=$(/bin/date --date="${REPLY##*until: }" "+%Y-%m-%d")
      validunix=$(/bin/date --date="${REPLY##*until: }" "+%s")
      eval ${localTAB}certDays[$cnt]=$(( (${validunix} - $(/bin/date "+%s")) / 3600 / 24 ))
      eval ${localTAB}certTitle[$cnt]="$(printf '%s %s\n' ${certValid[$cnt]} ${localAlias})"
      eval ${localTAB}certMax=$cnt
      cnt+=1
    fi
  done<<<$(keytool -list -v -keystore "$1" -storepass "$2"|grep -P "(Alias name:|Serial number:|Valid from:)"|grep "Alias name:" -A 2)
}

# print cert menu
print_certs() {
  typeset -i cnt=1
  typeset -i commonMax=${LcertMax}

  if [ -n "$RFILE" ]; then
    [ "${RcertMax}" -gt "${LcertMax}" ] && commonMax=${RcertMax}
    printf "%10s %20s | %10s %20s\n" " Valid to " "Alias" " Valid to " "Alias"
  else
    printf "%12s %32s %20s\n" "[ Valid to ]" "Serial No" "Alias"
  fi

  while [ $cnt -le $commonMax ]; do
    if [ -n "$RFILE" ]; then
      if   [ $TAB == "L" -a $cnt -eq $LENTRY ]; then lcolor="${blue}"; rcolor=""
      elif [ $TAB == "R" -a $cnt -eq $RENTRY ]; then rcolor="${blue}"; lcolor=""
      else lcolor="" && rcolor=""
      fi
      printf "${lcolor}%10s %-20s${rst} |  ${rcolor}%10s %-20s${rst}\n" "${LcertValid[$cnt]}" "${LcertName[$cnt]}" "${RcertValid[$cnt]}" "${RcertName[$cnt]}"
    else
      if [ $cnt eq $LENTRY ]; then lcolor="${blue}"
      else lcolor=""
      fi
      printf "${lcolor}%10s %32s %-20s${rst}\n" "${LcertValid[$cnt]}" ${LcertSerial[$cnt]} "${LcertName[$cnt]}"
    fi
    cnt+=1
  done
}

# export_cert $Alias $Keystore $Storepass
export_cert() {
  ALIASNAME=$(echo "$1"|tr -d '[]()#*?\\/'|tr " " "_")
  while true; do
    echo -n "${NL}1. ${green}J${rst}KS${NL}2. ${green}P${rst}KCS12${NL}3. ${green}c${rst}rt${NL}4. ${red}Q${rst}uit${NL}${NL}Choose export format for certificate: ${green}$1${rst} from ${green}$2${rst}: "
    read -rsN1
    case $REPLY in
      j|J|1) FILENAME="${ALIASNAME}.jks"
             echo -n "${NL}Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             [ -n "$REPLY" ] && FILENAME="$REPLY"
             keytool -importkeystore -srckeystore "$2" -destkeystore "${FILENAME}" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$3" -deststoretype jks
             if [ $? -eq 0 ]; then echo "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}"
               else                echo "${red}Error with exporting $1 to ${FILENAME}${rst}"
             fi;;
      p|P|2) FILENAME="${ALIASNAME}.pkcs12"
             echo -n "${NL}Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             [ -n "$REPLY" ] && FILENAME="$REPLY"
             keytool -importkeystore -srckeystore "$2" -destkeystore "${FILENAME}" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$3" -deststoretype pkcs12
             if [ $? -eq 0 ]; then echo "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}"
               else                echo "${red}Error with exporting $1 to ${FILENAME}${rst}"
             fi;;
      c|C|3) FILENAME="${ALIASNAME}.cer"
             echo -n "${NL}Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             keytool -exportcert -v -alias "$1" -keystore "$2" -storepass "$3" -rfc -file "${FILENAME}"
             if [ $? -eq 0 ]; then
               echo "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}"
             else
               echo "${red}Error with exporting $1 to ${FILENAME}${rst}"
             fi;;
      q|Q|4) break;;
    esac
  done
  echo "${green}Done.${rst}${NL}"
}

print_details() {
  if [ $TAB == "L" ]; then
    localAlias=${LcertName[$LENTRY]}
    localSerial=${LcertSerial[$LENTRY]}
    localValid=${LcertValid[$LENTRY]}
    localDays=${LcertDays[$LENTRY]}
  else
    localAlias=${RcertName[$RENTRY]}
    localSerial=${RcertSerial[$RENTRY]}
    localValid=${RcertValid[$RENTRY]}
    localDays=${RcertDays[$RENTRY]}
  fi
  echo "${NL}Details for certificate [${green}${localAlias}${rst}]:"
  echo "Serial number: ${localSerial}"
  echo "Valid to: ${localValud}"
  echo "Days left: ${localDays}"
  echo "${NL}Press any key"
  read -rsn1
}

copy_cert() {
  echo -n "${NL}Press ${red}y${rst}/${red}Y${rst} to copy [${green}$1${rst}] from ${green}$2${rst} to ${green}$4${rst}: "
  read -N1
  if [ "$REPLY" == y -o "$REPLY" == Y ]; then
    echo "${NL}${red}Copying certificate [$1]${rst}"
    keytool -importkeystore -srckeystore "$2" -destkeystore "$4" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$5"
    if [ $? -eq 0 ]; then
      echo "Certificate ${blue}$1${rst} succesfully copyed from ${blue}$2${rst} to ${blue}$4${rst}"
    else
      echo "${red}Error copying $1 from $2${rst}"
    fi
    sleep 1
  else
    echo "${NL}${red}Cancelled.${rst}"
    sleep 1
    return
  fi

  if [ "$TAB" == "L" ]; then
    RcertMax=$((${RcertMax}+1))
    RcertTitle[${RcertMax}]=${LcertTitle[${LENTRY}]}
    RcertName[${RcertMax}]=${LcertName[${LENTRY}]}
    RcertSerial[${RcertMax}]=${LcertSerial[${LENTRY}]}
    RcertValid[${RcertMax}]=${LcertValid[${LENTRY}]}
    RcertDays[${RcertMax}]=${LcertDays[${LENTRY}]}
  else
    LcertMax=$((${LcertMax}+1))
    LcertTitle[${LcertMax}]=${RcertTitle[${RENTRY}]}
    LcertName[${LcertMax}]=${RcertName[${RENTRY}]}
    LcertSerial[${LcertMax}]=${RcertSerial[${RENTRY}]}
    LcertValid[${LcertMax}]=${RcertValid[${RENTRY}]}
    LcertDays[${LcertMax}]=${RcertDays[${RENTRY}]}
  fi
}
