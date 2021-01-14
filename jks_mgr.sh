#!/bin/ksh
#
# Java keystore bash manager
#
# Author: Sergii Kulyk aka Saboteur
# Version 1.4
# * List of certificates in JKS
# * Export to JKS, PKCS12, CRT
# * Delete certificate
# * Rename certificate
# * dual tab support
# * Copy certificate
# * Functional key support (F1, F3, F5, F6, F8, F10)
# * page height implemented with scrolling
# * cOmpare certificates ( by serial Number)
# * help added
# * auto screen height with default 15+7
# * View certificate details, fixed F3 button
# * Auto screen width, Certificate alias can be shortened to fit the screen
# * Add import certificate from web site
#

default_store_pwd="changeit"
escape_char=$(printf "\u1b") # for keypress navigation
TAB="L"         # LEFT panel is default (for single mode)
POSITION=1      # Screen position
pageHeight=10   # active menu height
aliasWidth=12   # default alias width for dual mode
compareFlag=0
NL="
"               # new line
# define variables
typeset -A LcertName LcertSerial LcertValid LcertDays Lflags
typeset -i LcertMax=0 LENTRY=1
typeset -A RcertName RcertSerial RcertValid RcertDays Rflags
typeset -i RcertMax=0 RENTRY=1
# colors
red=$(tput bold;tput setaf 1)
green=$(tput bold;tput setaf 2)
blue=$(tput bold;tput setaf 6)
blueb=$(tput bold;tput setab 6)
rst=$(tput sgr0)

help_function() {
  echo "    ${blue}Bash java keystore manager${rst}"
  echo "    (C) Sergii Kulyk aka Saboteur"
  echo "${NL} Usage:"
  echo "    ${blue}jks_mgr.sh store.jks [store2.jks]${rst}"
  echo "${NL} Requirements:"
  echo "    keytool from jdk should be available in PATH, standard GNU tools"
  echo "${NL} Features:"
  echo "    View list of certificates in storage"
  echo "    Available commands: view details, rename, delete, export to JKS, PKCS12, CER formats"
  echo "    If two stores provided, you can view them in two-panel mode"
  echo "    Also in two-panel mode additional commands available: copy and compare${NL}"
}

# function wait for x seconds or continue on pressing enter
# $1 seconds, $2 text
delay() {
  echo "$2"
  read -N1 -t $1
}

# function automaticaly adjust windows height if it is less then 22
adjust_height() {
  localHeight=$(( $(tput lines)-7 )) # 7 lines for header and footer
  if [ $pageHeight -ne $localHeight ]; then
    pageHeight=$localHeight
    if [ $pageHeight -lt 0 ]; then
      if [ -a -n "$1" ]; then
        echo "Screen height is too smal. Need at least 7 rows"
        exit 1
      else
        pageHeight=10 # default height
      fi
    fi
    clear
  fi
  localWidth=$(( ( $(tput cols) - 25 ) / 2 - 1 )) # 25 cols for valid date, divider and spaces
  if [ $localWidth -ne $aliasWidth ]; then
    aliasWidth=$localWidth
    [ $aliasWidth -lt 1 ] && aliasWidth=12
    clear
  fi
}

# function $1: cert alias, $2: store file, $3: store pass
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
  [ compareFlag -eq 1  ] && compare_certs
  delay 2 "Certificate ${blue}$1${rst} succesfully removed from ${blue}$2${rst}"
}

# function to read certs from keystore
# $1 - store file, $2 - store pass, $3 - tab (L or R)
init_certs() {
  [ -n "$3" ] && localTAB=$3 || localTAB=L
  echo "Opening ${green}$1${rst} ... as ${localTAB}"
  typeset -i cnt=1
  while read; do
    if [ "$REPLY" == "--" ]; then
       continue
    elif expr "$REPLY" : "Alias name: ">/dev/null; then
      [ "$localTAB" == L ] && LcertName[$cnt]="${REPLY##*: }" || RcertName[$cnt]="${REPLY##*: }"
    elif expr "$REPLY" : "Serial number: ">/dev/null; then
      [ "$localTAB" == L ] && LcertSerial[$cnt]="${REPLY##*: }" || RcertSerial[$cnt]="${REPLY##*: }"
    else
      validunix=$(/bin/date --date="${REPLY##*until: }" "+%s")
      if [ "$localTAB" == L ]; then
           LcertValid[$cnt]=$(/bin/date --date="${REPLY##*until: }" "+%Y-%m-%d") || RcertValid[$cnt]=$(/bin/date --date="${REPLY##*until: }" "+%Y-%m-%d")
           LcertDays[$cnt]=$(( (${validunix} - $(/bin/date "+%s")) / 3600 / 24 ))
           LcertMax=$cnt
      else
           RcertValid[$cnt]=$(/bin/date --date="${REPLY##*until: }" "+%Y-%m-%d") || RcertValid[$cnt]=$(/bin/date --date="${REPLY##*until: }" "+%Y-%m-%d")
           RcertDays[$cnt]=$(( (${validunix} - $(/bin/date "+%s")) / 3600 / 24 ))
           RcertMax=$cnt
      fi
      cnt+=1
    fi
  done<<<"$(keytool -list -v -keystore $1 -storepass $2|grep -P '(Alias name:|Serial number:|Valid from:)'|grep 'Alias name:' -A 2)"
}

# re-print screen
# no args. if RFILE is not empty, print dual-tab
print_certs() {
  typeset -i cnt=$POSITION
  typeset -i commonMax=${LcertMax}

  adjust_height

  if [ -n "$RFILE" ]; then
    [ "${RcertMax}" -gt "${LcertMax}" ] && commonMax=${RcertMax}
    printf " store: ${blue}%-${aliasWidth}s${rst}     | store: ${blue}%-${aliasWidth}s${rst}\n" "$LFILE" "$RFILE"
    printf " %-10s %-${aliasWidth}s | %-10s %-${aliasWidth}s\n" "Valid to" "Alias" "Valid to" "Alias"
  else
    printf " store: %s\n" "$LFILE"
    if [ -n "$SHOW_SERIAL" ]; then
      printf " %-10s %-39s %s\n" "Valid to" "Serial No" "Alias"
    else
      printf " %-10s %s\n" "Valid to" "Alias"
    fi
  fi
  delimiter=$(( $(tput cols) - 2 ))
  printf " "
  eval printf "%0.s-" {1..${delimiter}}
  printf "\n"

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
      printf "%1s${lcolor}%10s %-${aliasWidth}s${rst} |%1s${rcolor}%10s %-${aliasWidth}s${rst}\n" "${Lflags[$cnt]}" "${LcertValid[$cnt]}" "${LcertName[$cnt]:0:$aliasWidth}" "${Rflags[$cnt]}" "${RcertValid[$cnt]}" "${RcertName[$cnt]:0:$aliasWidth}"
    else
      [ $cnt -eq $LENTRY ] && lcolor="${blueb}" || lcolor=""
      if [ -n "$SHOW_SERIAL" ]; then
        printf " ${lcolor}%10s %-39s %s${rst}\n" "${LcertValid[$cnt]}" ${LcertSerial[$cnt]} "${LcertName[$cnt]}"
      else
        localWidth=$(( $(tput cols) - 13 ))
        printf " ${lcolor}%10s %-${aliasWidth}s${rst}\n" "${LcertValid[$cnt]}" "${LcertName[$cnt]:0:$localWidth}"
      fi
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
             DESTPASS="${default_store_pwd}"
             echo -n "${NL}Provide password for $FILENAME (press ENTER to use: ${green}${DESTPASS}${rst}) :"
             read
             [ -n "$REPLY" ] && DESTPASS="$REPLY"
             keytool -importkeystore -srckeystore "$2" -destkeystore "${FILENAME}" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$DESTPASS" -deststoretype jks
             if [ $? -eq 0 ]; then
               delay 2 echo "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}"
             else
               delay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}"
             fi;;
      p|P|2) FILENAME="${ALIASNAME}.pkcs12"
             echo -n "${NL}Provide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
             read
             [ -n "$REPLY" ] && FILENAME="$REPLY"
             DESTPASS="${default_store_pwd}"
             echo -n "${NL}Provide password for $FILENAME (press ENTER to use: ${green}${DESTPASS}${rst}) :"
             read
             [ -n "$REPLY" ] && DESTPASS="$REPLY"
             keytool -importkeystore -srckeystore "$2" -destkeystore "${FILENAME}" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$DESTPASS" -deststoretype pkcs12
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

# print certificate details
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
  keytool -list -v -alias "$localAlias" -keystore "$2" -storepass "$3" 2>/dev/null| sed -n '/Alias:/p;/Creation date:/p;/Owner:/p;/Issuer:/p;/Serial number:/p;/Valid from:/p;/DNSName:/p'
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

  typeset -i counter=0
  if [ "$TAB" == "L" ]; then
    while [ $counter -le ${RcertMax} ]; do
      if [ "${RcertName[${counter}]}" == "${LcertName[${LENTRY}]}" ]; then
        break
      fi
      counter=$(($counter+1))
    done
    if [ $counter -gt $RcertMax ]; then
      RcertMax=$((${RcertMax}+1))
    fi
    RcertName[${counter}]=${LcertName[${LENTRY}]}
    RcertSerial[${counter}]=${LcertSerial[${LENTRY}]}
    RcertValid[${counter}]=${LcertValid[${LENTRY}]}
    RcertDays[${counter}]=${LcertDays[${LENTRY}]}
  else
    while [ $counter -le ${LcertMax} ]; do
      if [ "${LcertName[${counter}]}" == "${RcertName[${RENTRY}]}" ]; then
        break
      fi
      counter=$(($counter+1))
    done
    if [ $counter -gt $LcertMax ]; then
      LcertMax=$((${LcertMax}+1))
    fi
    LcertName[${counter}]=${RcertName[${RENTRY}]}
    LcertSerial[${counter}]=${RcertSerial[${RENTRY}]}
    LcertValid[${counter}]=${RcertValid[${RENTRY}]}
    LcertDays[${counter}]=${RcertDays[${RENTRY}]}
  fi
  [ compareFlag -eq 1 ] && compare_certs
  delay 2 "Certificate ${blue}$1${rst} succesfully copied from ${blue}$2${rst} to ${blue}$4${rst}"
}

# import certificate from provided web-site to active keystore
import_from_www() {
  echo -n "${NL}Please enter URL without https - [${green}site${rst}] or [${green}site:port${rst}] (or empty string to cancel): "
  read URL
  if [ -n "$URL" ]; then
    SITE=$(echo "$URL"|cut -d: -f1)
    echo "$URL"|grep :>/dev/null
    if [ $? -eq 0 ]; then
      PORT=$(echo "$URL"|cut -d: -f2)
    else
      PORT="443"
    fi
    echo "${NL}${blue}Getting certificate from [$SITE:$PORT]${rst}"
    openssl s_client -showcerts -connect "$SITE:$PORT" </dev/null 2>/dev/null|openssl x509 -outform PEM >temp.pem
    if [ $? -ne 0 ]; then
      delay 5 echo "${red}Unable to download certificate from $SITE:$PORT${rst}"
      rm temp.pem
      return
    fi
    if [ "$TAB" == "L" ]; then
      storefile=$LFILE
      storepass=$LSTOREPASS
    else
      storefile=$RFILE
      storepass=$RSTOREPASS
    fi
    keytool -import -file temp.pem -keystore "$storefile" -storepass "$storepass" -noprompt -alias "$SITE"
    if [ $? -ne 0 ]; then
      delay 5 echo "${red}Can't add certificate to keystore${rst}"
      rm temp.pem
      return
    fi
    delay 2 echo "${blue}Certificate $SITE was imported to $storefile${rst}"
    if [ "$TAB" == "L" ]; then
      init_certs "$LFILE" "$LSTOREPASS" "L"
    else
      init_certs "$RFILE" "$RSTOREPASS" "R"
    fi
    [ compareFlag -eq 1 ] && compare_certs
  else
    delay 5 "${NL}${red}Cancelled.${rst}"
  fi
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

# Compare certificates by serial number and put * if found matched
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
  compareFlag=1
}

# Begin main program
# Parse arguments - if first provided for left menu
if [ -n "$1" -a "$1" != "--help" ]; then
  LFILE="$1"
  echo -n "Provide password for ${green}$LFILE${rst}(press ENTER to use default ${green}${default_store_pwd}${rst} ): "
  read
  [ -z "$REPLY" ] && LSTOREPASS="$default_store_pwd" || LSTOREPASS="$REPLY"
else
  help_function
  exit 0
fi

# Parse arguments - if second provided for dual-mode
if [ -n "$2" ]; then
  RFILE="$2"
  echo -n "Provide password for ${green}$RFILE${rst}(press ENTER to use default ${green}${default_store_pwd}${rst} ): "
  read
  [ -z "$REPLY" ] && RSTOREPASS="$default_store_pwd" || RSTOREPASS="$REPLY"
fi

# load left tab
init_certs "$LFILE" "$LSTOREPASS" "L"

# load right tab if exists
if [ -n "$RFILE" ]; then
  init_certs "$RFILE" "$RSTOREPASS" "R"
fi

# init screen
clear

# main loop
while true; do
  tput home
  print_certs
  
  if [ -n "$RFILE" ]; then
    echo "${NL} F3:${green}I${rst}nfo F5:${green}C${rst}opy F6:${green}R${rst}ename F8:${red}D${rst}elete c${green}O${rst}mpare ${green}E${rst}xport i${green}M${rst}port  F10:${red}Q${rst}uit"
  else
    echo "${NL} F3:${green}I${rst}nfo F6:${green}R${rst}ename F8:${red}D${rst}elete ${green}E${rst}xport i${green}M${rst}port F10:${red}Q${rst}uit"
  fi

  # check for pressed keys. Special keys could take up to 4 characters
  read -rsN1 keypress
  if [ "$keypress" == "$escape_char" ]; then
    read -sn1 -t 0.01 k1
    read -sn1 -t 0.01 k2
    read -sn1 -t 0.01 k3
    read -sn1 -t 0.01 k4
    keypress=${k1}${k2}${k3}${k4}
    unset k1 k2 k3 k4
  fi
  tput el1 # clear line from escaped chars

  case "$keypress" in
    q|Q|'[21~')  echo "${NL}${green}Good bye${rst}"; exit 0;;
    '[A') if [ $TAB == "L" ]; then
            LENTRY=$(( $LENTRY-1 )); [ $LENTRY -lt 1 ] && LENTRY=1
            if [ $POSITION -gt $LENTRY ]; then
              POSITION=$(($POSITION-1))
              [ $POSITION -le 1 ] && POSITION=1
              clear
            fi
          else
            RENTRY=$(( $RENTRY-1 )); [ $RENTRY -lt 1 ] && RENTRY=1
            if [[ $POSITION -gt $RENTRY ]]; then
              POSITION=$(($POSITION-1))
              [ $POSITION -le 1 ] && POSITION=1
              clear
            fi
          fi;;
    '[B') if [ $TAB == 'L' ]; then
            LENTRY=$(( $LENTRY+1 ))
            [ $LENTRY -gt $LcertMax ] && LENTRY=$LcertMax
            if [[ $(($POSITION+$pageHeight)) -lt $LENTRY ]]; then
              POSITION=$(($POSITION+1))
              [ $POSITION -gt $LcertMax ] && POSITION=$LcertMax
              clear
            fi
          else
            RENTRY=$(( $RENTRY+1 ))
            [ $RENTRY -gt $RcertMax ] && RENTRY=$RcertMax
            if [[ $(($POSITION+$pageHeight)) -lt $RENTRY ]]; then
              POSITION=$(( $POSITION + 1))
              [ $POSITION -gt $RcertMax ] && POSITION=$RcertMax
              clear
            fi
          fi;;
   '[D')  switch_tab L;;
   '[C')  switch_tab R;;
    o|O)  compare_certs;clear;;
    e|E)  if [ $TAB == "L" ]; then
            export_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS"
          else
            export_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS"
          fi;clear;;
    c|C|'[15~')  [ -z "$RFILE" ] && continue
          if [ $TAB == "L" ]; then
            copy_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS" "$RFILE" "$RSTOREPASS"
          else
            copy_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS" "$LFILE" "$LSTOREPASS"
          fi;clear;;
    d|D|'[19~')  if [ $TAB == "L" ]; then
            delete_cert "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}"
          else
            delete_cert "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}"
          fi;clear;;
    i|I|'[13~'|'OR')  if [ ${TAB} == "L" ]; then
            print_details "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}"
          else
            print_details "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}"
          fi;clear;;
    r|R|'[17~')  if [ $TAB == "L" ]; then
            rename_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS"
          else
            rename_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS"
          fi;clear;;
   '	' ) [ "$TAB" == "L" ] && switch_tab R || switch_tab L;;
   m|M)  import_from_www;clear;;
    *)    clear;;
  esac
done
