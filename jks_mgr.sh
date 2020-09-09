#!/bin/ksh
. $(dirname $0)/functions.sh
#
# Java keystore bash manager
#
# Author: Sergii Kulyk aka Saboteur
# Version 1.1
# * List of certificates in JKS
# * View some details (Alias, Serial, Valid date)
# * Export to JKS, PKCS12, CRT
# * Delete certificate
# * dual tab support
# * Copy certificate
# * Rename certificate
# * Functional key support

COLUMNS=1	# for select command
NL="
"

#if [ -z "$1" ]; then
#  echo -n "Provide keystore name (press ENTER to use default ${green}truststore.jks${rst}): "
#  read
#  [ -z "$REPLY" ] && FILE="truststore.jks"
#else
#  FILE="$1"
#fi
LFILE="Ltruststore.jks"
LSTOREPASS="changeme"
RFILE="Rtruststore.jks"
RSTOREPASS="changeme"
typeset -A LcertName LcertSerial LcertValid LcertDays LcertTitle
typeset -i LcertMax=0 LENTRY=1
typeset -A RcertName RcertSerial RcertValid RcertDays RcertTitle
typeset -i RcertMax=0 RENTRY=1

TAB="L"	# LEFT is default

# init left tab
init_certs "$LFILE" "$LSTOREPASS" "L"

# init right tab if second file is set
if [ -n "$RFILE" ]; then
  init_certs "$RFILE" "$RSTOREPASS" "R"
fi

clear
tput init

escape_char=$(printf "\u1b")
# main loop
while true; do
  tput home
  print_certs

  if [ -n "$RFILE" ]; then
    echo "${NL}Choose your action (${red}Q${rst}uit, ${green}E${rst}xport, ${green}C${rst}opy, ${green}I${rst}nfo, ${red}D${rst}elete, ${green}R${rst}ename): "
  else
    echo "${NL}Choose your action (${red}Q${rst}uit, ${green}E${rst}xport, ${green}I${rst}nfo, ${red}D${rst}elete, ${green}R${rst}ename): "
  fi

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
            LENTRY=$(( $LENTRY-1 )); [ $LENTRY -le 1 ] && LENTRY=1
          else
            RENTRY=$(( $RENTRY-1 )); [ $RENTRY -le 1 ] && RENTRY=1
          fi;;
    '[B') if [ $TAB == 'L' ]; then
            LENTRY=$(( $LENTRY+1 )); [ $LENTRY -gt $LcertMax ] && LENTRY=$LcertMax
          else
            RENTRY=$(( $RENTRY+1 )); [ $RENTRY -gt $RcertMax ] && RENTRY=$RcertMax
          fi;;
   '[D')  TAB="L";;
   '[C')  TAB="R";;
    e|E)  if [ $TAB == "L" ]; then
            export_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS";clear
          else
            export_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS";clear
          fi;;
    c|C|'[15~')  [ -z "$RFILE" ] && continue
          if [ $TAB == "L" ]; then
            copy_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS" "$RFILE" "$RSTOREPASS";clear
          else
            copy_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS" "$LFILE" "$LSTOREPASS";clear
          fi;;
    d|D|'[19~')  if [ $TAB == "L" ]; then
            delete_cert "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}";clear
          else
            delete_cert "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}";clear
          fi;;
    i|I|'[13~')  if [ ${TAB} == "L" ]; then
            print_details "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}";clear
          else
            print_details "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}";clear
          fi;;
    r|R|'[17~')  if [ $TAB == "L" ]; then
            rename_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS";clear
          else
            rename_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS";clear
          fi;;
   '	' ) [ "$TAB" == "L" ] && TAB=R || TAB=L;;
    *)    clear;;
  esac
done
