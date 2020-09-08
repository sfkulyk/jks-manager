#!/bin/ksh
. $(dirname $0)/functions.sh
#
# Author: Sergii Kulyk aka Saboteur
# Version 1.0
# * List of certificates in JKS
# * View some details (Alias, Serial, Valid date)
# * Export to JKS, PKCS12, CRT
# * Delete certificate
#
escape_char=$(printf "\u1b")
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
init_certs "${LFILE}" "${LSTOREPASS}" "L"

# init right tab if second file is set
if [ -n "$RFILE" ]; then
  init_certs "${RFILE}" "${RSTOREPASS}" "R"
fi

clear
tput init

# main loop
while true; do
  tput home
  print_certs

  echo "${NL}Choose your action (${red}Q${rst}uit, ${green}E${rst}xport, ${green}I${rst}nfo, ${red}D${rst}elete): "
  read -rsN1
  [ "${REPLY}" == "${escape_char}" ] && read -rsN2
  tput el1 # clear line from escaped chars

  case "${REPLY}" in
    q|Q)  echo "${NL}${green}Good bye${rst}"; exit 0;;
    '[A') if [ ${TAB} == "L" ]; then
            LENTRY=$(( ${LENTRY}-1 )); [ ${LENTRY} -le 1 ] && LENTRY=1
          else
            RENTRY=$(( ${RENTRY}-1 )); [ ${RENTRY} -le 1 ] && RENTRY=1
          fi;;
    '[B') if [ $TAB == 'L' ]; then
            LENTRY=$(( ${LENTRY}+1 )); [ ${LENTRY} -gt ${LcertMax} ] && LENTRY=${LcertMax}
          else
            RENTRY=$(( ${RENTRY}+1 )); [ ${RENTRY} -gt ${RcertMax} ] && RENTRY=${RcertMax}
          fi;;
    e|E)  if [ ${TAB} == "L" ]; then
            export_cert "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}";clear
          else
            export_cert "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}";clear
          fi;;
    d|D)  if [ ${TAB} == "L" ]; then
            delete_cert "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}";clear
          else
            delete_cert "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}";clear
          fi;;
    i|I)  if [ ${TAB} == "L" ]; then
            print_details "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}";clear
          else
            print_details "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}";clear
          fi;;
   '[D')  TAB="L";;
   '[C')  TAB="R";;
   '	' ) [ "$TAB" == "L" ] && TAB=R || TAB=L;;
    *)    clear;;
  esac
done
