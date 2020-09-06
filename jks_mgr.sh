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
FILE="truststore.jks"
STOREPASS="changeme"

typeset -A certName
typeset -A certSerial
typeset -A certValid
typeset -A certDays
typeset -A certTitle
typeset -i certMax=0
typeset -i ENTRY=1
init_certs "$FILE" "$STOREPASS"
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
    '[A') ENTRY=$(($ENTRY-1)); [ ${ENTRY} -le 1 ] && ENTRY=1;;
    '[B') ENTRY=$(($ENTRY+1)); [ ${ENTRY} -ge $certMax ] && ENTRY=$certMax;;
    e|E)  export_cert "${certName[$ENTRY]}" "${FILE}" "${STOREPASS}";clear;;
    d|D)  delete_cert "${certName[$ENTRY]}" "${FILE}" "${STOREPASS}";clear;;
    i|I)  print_details "${certName[$ENTRY]}" "${FILE}" "${STOREPASS}";clear;;
   '[D') echo LEFT ;;
   '[C') echo RIGHT ;;
    *)   clear;;
  esac
done
