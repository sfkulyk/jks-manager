#
# Java keystore bash manager functions
#
# Author: Sergii Kulyk aka Saboteur
#

# colors
red=$(tput bold;tput setaf 1)
green=$(tput bold;tput setaf 2)
blue=$(tput bold;tput setaf 6)
blueb=$(tput bold;tput setab 6)
rst=$(tput sgr0)

help_function() {
  echo "	${blue}Bash java keystore manager${rst}"
  echo "	(C) Sergii Kulyk aka Saboteur"
  echo "${NL} Usage:"
  echo "	${blue}jks_mgr.sh store.jks [store2.jks]${rst}"
  echo "${NL} Requirements:"
  echo "	keytool from jdk should be available in PATH, standard GNU tools"
  echo "${NL} Features:"
  echo "	View list of certificates in storage"
  echo "	Available commands: view details, rename, delete, export to JKS, PKCS12, CER formats"
  echo "	If two stores provided, you can view them in two-panel mode"
  echo "	Also in two-panel mode additional commands available: copy and compare${NL}"
}

# $1 seconds, $2 text
delay() {
  echo "$2"
  read -N1 -t $1
}

# $1: cert alias, $2: store file, $3: store pass
delete_cert() {
  echo -n "${NL}Press ${red}y${rst}/${red}Y${rst} to delete [${green}$1${rst}] from ${green}$2${rst}: "
  read -N1
  if [ "$REPLY" == y -o "$REPLY" == Y ]; then
    echo "${NL}${red}Removing certificate [$1]${rst}"
    keytool -delete -alias "$1" -keystore "$2" -storepass "$3"
    if [ $? -ne 0 ]; then
      delay 5 "${red}Error deleting $1 from $2${rst}"
      return
    fi
  else
    delay 5 "${NL}${red}Cancelled.${rst}"
    return
  fi

  # shift certificate list up
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
      fi
      cnt+=1; next+=1
    done
    LcertMax=$(($LcertMax-1))
    [ $LENTRY -gt $LcertMax ] && LENTRY=$LcertMax
  else
    while [ -n "${RcertName[$next]}" ]; do
      [ "${RcertName[$cnt]}" == "$1" ] && found=1
      if [ $found == 1 ] ; then
        RcertName[$cnt]=${RcertName[$next]}
        RcertSerial[$cnt]=${RcertSerial[$next]}
        RcertValid[$cnt]=${RcertValid[$next]}
        RcertDays[$cnt]=${RcertDays[$next]}
      fi
      cnt+=1; next+=1
    done
    RcertMax=$(($RcertMax-1))
    [ $RENTRY -gt $RcertMax ] && RENTRY=$RcertMax
  fi
  # unset entry
  eval unset ${TAB}certName[$cnt]
  eval unset ${TAB}certSerial[$cnt]
  eval unset ${TAB}certValid[$cnt]
  eval unset ${TAB}certDays[$cnt]
  eval unset ${TAB}flags[$cnt]
  delay 2 "Certificate ${blue}$1${rst} succesfully removed from ${blue}$2${rst}"
}

# $1 - store file, $2 - store pass, $3 - tab (L or R)
init_certs() {
  localTAB=$3
  echo "Opening ${green}$1${rst} ... as ${localTAB}"
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
      eval ${localTAB}certMax=$cnt
      cnt+=1
    fi
  done<<<$(keytool -list -v -keystore "$1" -storepass "$2"|grep -P "(Alias name:|Serial number:|Valid from:)"|grep "Alias name:" -A 2)
}

# no args. if RFILE is not empty, print dual-tab
print_certs() {
  typeset -i cnt=$POSITION
  typeset -i commonMax=${LcertMax}

  if [ -n "$RFILE" ]; then
    [ "${RcertMax}" -gt "${LcertMax}" ] && commonMax=${RcertMax}
    printf " store: ${blue}%-24s${rst} | store: ${blue}%-24s${rst}\n" "$LFILE" "$RFILE"
    printf " %-10s %-20s | %-10s %-20s\n" "Valid to" "Alias" "Valid to" "Alias"
  else
    printf " store: %s\n" "$LFILE"
    printf " %-10s %-32s %-20s\n" "Valid to" "Serial No" "Alias"
  fi
  echo "-----------------------------------------------------------------"

  if [ $commonMax -gt $(( $POSITION + $pageHeight )) ]; then
    commonMax=$(($POSITION + $pageHeight))
  fi

  while [ $cnt -le $commonMax ]; do
    if [ -n "$RFILE" ]; then
      lcolor="" && rcolor=""
      if [ $cnt -eq $LENTRY ]; then
        [ $TAB == "L" ] && lcolor=${blueb} || lcolor=${blue}
      fi
      if [ $cnt -eq $RENTRY ]; then
        [ $TAB == "R" ] && rcolor=${blueb} || rcolor=${blue}
      fi
      printf "%1s${lcolor}%10s %-20s${rst} |%1s${rcolor}%10s %-20s${rst}\n" "${Lflags[$cnt]}" "${LcertValid[$cnt]}" "${LcertName[$cnt]}" "${Rflags[$cnt]}" "${RcertValid[$cnt]}" "${RcertName[$cnt]}"
    else
      [ $cnt -eq $LENTRY ] && lcolor="${blueb}" || lcolor=""
      printf " ${lcolor}%10s %32s %-20s${rst}\n" "${LcertValid[$cnt]}" ${LcertSerial[$cnt]} "${LcertName[$cnt]}"
    fi
    cnt+=1
  done
}

# $1 Alias $2 store $3 store pass
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
             if [ $? -eq 0 ]; then
               delay 2 echo "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}"
             else
               delay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}"
             fi;;
      p|P|2) FILENAME="${ALIASNAME}.pkcs12"
             echo -n "${NL}Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             [ -n "$REPLY" ] && FILENAME="$REPLY"
             keytool -importkeystore -srckeystore "$2" -destkeystore "${FILENAME}" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$3" -deststoretype pkcs12
             if [ $? -eq 0 ]; then
               delay 2 "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}"
             else
               delay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}"
             fi;;
      c|C|3) FILENAME="${ALIASNAME}.cer"
             echo -n "${NL}Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             keytool -exportcert -v -alias "$1" -keystore "$2" -storepass "$3" -rfc -file "${FILENAME}"
             if [ $? -eq 0 ]; then
               delay 2 "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}"
             else
               delay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}"
             fi;;
      q|Q|4) break;;
    esac
  done
}

# no args
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
  echo "Valid to: ${localValid}"
  echo "Days left: ${localDays}"
  echo "${NL}Press any key"
  read -rsn1
}

# $1 certificate alias $2 - source store $3 source storepass $4 dest store $5 dest store pass
copy_cert() {
  echo -n "${NL}Press ${red}y${rst}/${red}Y${rst} to copy [${green}$1${rst}] from ${green}$2${rst} to ${green}$4${rst}: "
  read -N1
  if [ "$REPLY" == y -o "$REPLY" == Y ]; then
    echo "${NL}${blue}Copying certificate [$1]${rst}"
    keytool -importkeystore -srckeystore "$2" -destkeystore "$4" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$5"
    if [ $? -ne 0 ]; then
      delay 5 echo "${red}Error copying $1 from $2${rst}"
      return
    fi
  else
    delay 5 "${NL}${red}Cancelled.${rst}"
    return
  fi

  if [ "$TAB" == "L" ]; then
    RcertMax=$((${RcertMax}+1))
    RcertName[${RcertMax}]=${LcertName[${LENTRY}]}
    RcertSerial[${RcertMax}]=${LcertSerial[${LENTRY}]}
    RcertValid[${RcertMax}]=${LcertValid[${LENTRY}]}
    RcertDays[${RcertMax}]=${LcertDays[${LENTRY}]}
  else
    LcertMax=$((${LcertMax}+1))
    LcertName[${LcertMax}]=${RcertName[${RENTRY}]}
    LcertSerial[${LcertMax}]=${RcertSerial[${RENTRY}]}
    LcertValid[${LcertMax}]=${RcertValid[${RENTRY}]}
    LcertDays[${LcertMax}]=${RcertDays[${RENTRY}]}
  fi
  delay 2 "Certificate ${blue}$1${rst} succesfully copyed from ${blue}$2${rst} to ${blue}$4${rst}"
}

# $1 source alias, $2 store file $3 store pass
rename_cert() {
  echo -n "${NL}Provide new name for ${blue}$1${rst}: "
  read newAlias
  if [ -z "$newAlias" ]; then
    delay 5 "${NL}${red}Cancelled.${rst}"
    return
  fi
  echo -n "${NL}Press ${red}y${rst}/${red}Y${rst} to rename ${green}$1${rst} from ${green}$2${rst} to ${green}${newAlias}${rst}: "
  read -N1
  if [ "$REPLY" == y -o "$REPLY" == Y ]; then
    echo "${NL}${blue}Renaming certificate [$1]${rst}"
    keytool -importkeystore -srckeystore "$2" -destkeystore "tmp.jks" -srcalias "$1" -destalias "$newAlias" -srcstorepass "$3" -deststorepass "$3"
    if [ $? -ne 0 ]; then
      delay 5 "${red}Error renaming certificate $1 from $2${rst}"
      return
    fi
    keytool -importkeystore -srckeystore "tmp.jks" -destkeystore "$2" -srcalias "$newAlias" -destalias "$newAlias" -srcstorepass "$3" -deststorepass "$3"
    if [ $? -ne 0 ]; then
      delay 5 "${red}Error renaming certificate $1 from $2${rst}"
      return
    fi
    keytool -delete -alias "$1" -keystore "$2" -storepass "$3"
    if [ $? -ne 0 ]; then
      delay 5 "${red}Error renaming certificate $1 from $2${rst}"
      return
    fi
  else
    delay 5 "${NL}${red}Cancelled.${rst}"
    return
  fi
  rm tmp.jks
  if [ "$TAB" == "L" ]; then
    LcertName[$LENTRY]="$newAlias"
  else
    RcertName[$RENTRY]="$newAlias"
  fi
  delay 2 "Certificate ${blue}$1${rst} succesfully renamed to ${blue}${newAlias}${rst}"
}

# $1 tab (L or R)
switch_tab() {
  [ -z "$RFILE" ] && return
  if [ "$1" == "L" ]; then
    [ $POSITION -gt $LENTRY ] && POSITION=$LENTRY
    [ $(( $POSITION+$pageHeight )) -lt $LENTRY ] && POSITION=$(($LENTRY-$pageHeight))
    TAB="L"
  else
    [ $POSITION -gt $RENTRY ] && POSITION=$RENTRY
    [ $(( $POSITION+$pageHeight )) -lt $RENTRY ] && POSITION=$(($RENTRY-$pageHeight))
    TAB="R"
  fi
}

# No args
compare_certs() {
  typeset -i lcnt=1 rcnt=1

  # clear flags
  while [ $lcnt -le $LcertMax ]; do
    rcnt=1
    while [ $rcnt -le $RcertMax ]; do
      Lflags[$lcnt]=""
      Rflags[$rcnt]=""
      rcnt=$(($rcnt+1))
    done
    lcnt=$(($lcnt+1))
  done

  # set flag if we found certificates with same serial No
  lcnt=1
  while [ $lcnt -le $LcertMax ]; do
    rcnt=1
    while [ $rcnt -le $RcertMax ]; do
      if [ "${LcertSerial[$lcnt]}" == "${RcertSerial[$rcnt]}" ]; then
        Lflags[$lcnt]="${blue}*${rst}"
        Rflags[$rcnt]="${blue}*${rst}"
      fi
      rcnt=$(($rcnt+1))
    done
    lcnt=$(($lcnt+1))
  done
}

# automaticaly adjust windows height if it is less then 22
adjust_height() {
  localRows=$(tput lines)
  echo "localRows: $localRows, currentRows: $currentRows, pageHeight: $pageHeight"
  if [ -n "$1" -o $localRows != $currentRows ]; then
    pageHeight=$defHeight
    if [ $(($pageHeight+7)) -gt $localRows ]; then
      pageHeight=$(($localRows-7))
      if [ $pageHeight -lt 0 -a -n "$1" ]; then
        echo "screen height is too smal. Need at least 8 rows"
        exit 1
      fi
      currentRows=$localRows
    fi
  fi
}