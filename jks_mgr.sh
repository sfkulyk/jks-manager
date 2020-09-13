#!/bin/ksh
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
# * help added
# * auto screen height with default 15+7
#

escape_char=$(printf "\u1b")	# for keypress navigation

NL="
"			# new line
TAB="L"			# LEFT panel is default
POSITION=1		# Screen position
pageHeight=10		# active menu height
aliasWidth=12           # default alias witdh for dual mode

# load functions
. $(dirname $0)/functions.sh

# Parse arguments - first keystore and store password
if [ -n "$1" -a "$1" != "--help" ]; then
  LFILE="$1"
  echo -n "Provide password for ${green}$LFILE${rst}(press ENTER to use default ${green}changeme${rst} ): "
  read
  [ -z "$REPLY" ] && LSTOREPASS="changeme" || LSTOREPASS="$REPLY"
else
  help_function
  exit 0
fi

# check if second keystore provided
if [ -n "$2" ]; then
  RFILE="$2"
  echo -n "Provide password for ${green}$RFILE${rst}(press ENTER to use default ${green}changeme${rst} ): "
  read
  [ -z "$REPLY" ] && RSTOREPASS="changeme" || RSTOREPASS="$REPLY"
fi

# init screen
clear
tput init

# define variables
typeset -A LcertName LcertSerial LcertValid LcertDays Lflags
typeset -i LcertMax=0 LENTRY=1
typeset -A RcertName RcertSerial RcertValid RcertDays Rflags
typeset -i RcertMax=0 RENTRY=1

# load left tab
init_certs "$LFILE" "$LSTOREPASS" "L"

# load right tab if exists
if [ -n "$RFILE" ]; then
  init_certs "$RFILE" "$RSTOREPASS" "R"
fi

# main loop
while true; do
  tput home
  print_certs
  
  if [ -n "$RFILE" ]; then
    echo "${NL} F3:${green}I${rst}nfo F5:${green}C${rst}opy F6:${green}R${rst}ename F8:${red}D${rst}elete c${green}O${rst}mpare ${green}E${rst}xport F10:${red}Q${rst}uit"
  else
    echo "${NL} F3:${green}I${rst}nfo F6:${green}R${rst}ename F8:${red}D${rst}elete ${green}E${rst}xport F10:${red}Q${rst}uit"
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
          fi;;
    c|C|'[15~')  [ -z "$RFILE" ] && continue
          if [ $TAB == "L" ]; then
            copy_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS" "$RFILE" "$RSTOREPASS"
          else
            copy_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS" "$LFILE" "$LSTOREPASS"
          fi;;
    d|D|'[19~')  if [ $TAB == "L" ]; then
            delete_cert "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}"
          else
            delete_cert "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}"
          fi;;
    i|I|'[13~')  if [ ${TAB} == "L" ]; then
            print_details "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}"
          else
            print_details "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}"
          fi;;
    r|R|'[17~')  if [ $TAB == "L" ]; then
            rename_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS"
          else
            rename_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS"
          fi;;
   '	' ) [ "$TAB" == "L" ] && switch_tab R || switch_tab L;;
    *)    clear;;
  esac
  clear
done
