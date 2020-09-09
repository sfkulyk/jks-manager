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
# * page height implemented
# * cOmpare certificates ( by serial No)

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
typeset -A LcertName LcertSerial LcertValid LcertDays Lflags
typeset -i LcertMax=0 LENTRY=1
typeset -A RcertName RcertSerial RcertValid RcertDays Rflags
typeset -i RcertMax=0 RENTRY=1

TAB="L"	# LEFT is default
POSITION=1
pageHeight=15

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
    echo "${NL}Choose your action (${red}Q${rst}uit, ${green}E${rst}xport, ${green}C${rst}opy, ${green}I${rst}nfo, ${red}D${rst}elete, ${green}R${rst}ename, c${green}O${rst}mpare): "
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
            LENTRY=$(( $LENTRY-1 )); [ $LENTRY -lt 1 ] && LENTRY=1
            if [ $POSITION -gt $LENTRY ]; then
              POSITION=$(($POSITION-1))
              [ $POSITION -le 1 ] && POSITION=1
            fi
          else
            RENTRY=$(( $RENTRY-1 )); [ $RENTRY -lt 1 ] && RENTRY=1
            if [[ $POSITION -gt $RENTRY ]]; then
              POSITION=$(($POSITION-1))
              [ $POSITION -le 1 ] && POSITION=1
            fi
          fi;;
    '[B') if [ $TAB == 'L' ]; then
            LENTRY=$(( $LENTRY+1 ))
            [ $LENTRY -gt $LcertMax ] && LENTRY=$LcertMax
            if [[ $(($POSITION+$pageHeight)) -lt $LENTRY ]]; then
              POSITION=$(($POSITION+1))
              [ $POSITION -gt $LcertMax ] && POSITION=$LcertMax
            fi
          else
            RENTRY=$(( $RENTRY+1 ))
            [ $RENTRY -gt $RcertMax ] && RENTRY=$RcertMax
            if [[ $(($POSITION+$pageHeight)) -lt $RENTRY ]]; then
              POSITION=$(( $POSITION + 1))
              [ $POSITION -gt $RcertMax ] && POSITION=$RcertMax
            fi
          fi;;
   '[D')  switch_tab L;;
   '[C')  switch_tab R;;
    o|O)  compare_certs;;
    e|E)  if [ $TAB == "L" ]; then
            export_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS"
          else
            export_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS"
          fi
          clear;;
    c|C|'[15~')  [ -z "$RFILE" ] && continue
          if [ $TAB == "L" ]; then
            copy_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS" "$RFILE" "$RSTOREPASS"
          else
            copy_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS" "$LFILE" "$LSTOREPASS"
          fi
          clear;;
    d|D|'[19~')  if [ $TAB == "L" ]; then
            delete_cert "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}"
          else
            delete_cert "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}"
          fi
          clear;;
    i|I|'[13~')  if [ ${TAB} == "L" ]; then
            print_details "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}"
          else
            print_details "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}"
          fi
          clear;;
    r|R|'[17~')  if [ $TAB == "L" ]; then
            rename_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS"
          else
            rename_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS"
          fi
          clear;;
   '	' ) [ "$TAB" == "L" ] && switch_tab R || switch_tab L
          clear;;
    *)    clear;;
  esac
done
