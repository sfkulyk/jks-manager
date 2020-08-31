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
rst=$(tput sgr0)
COLUMNS=1	# for select command
STOREPASS="changeme"
NL="
"

debug() {
  echo "DEBUG: $1"
}

# $1: cert name, $2: keystore file
delete_cert() {
  echo -n "Write [${red}yes${rst}] or [${red}YES${rst}] to delete [${green}${1}${rst}] from ${green}${2}${rst}: "
  read	
  if [ "$REPLY" == yes -o "$REPLY" == YES ]; then
    keytool -delete -alias "${1}" -keystore "${2}" -storepass ${STOREPASS}
    echo "${red}Removing certificate [$1]${rst}"
  else
    echo "${red}Cancelled.${rst}"
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
}

init_certs() {
  echo "Opening ${green}${FILE}${rst} ..."
  # initialize cert list from keystore
  typeset -i cnt=2
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
      cnt+=1
    fi
  done<<<$(keytool -list -v -keystore ${1} -storepass ${STOREPASS}|grep -P "(Alias name:|Serial number:|Valid from:)"|grep "Alias name:" -A 2)
}

print_certs() {
  typeset -i cnt=2
  printf " 1) ${blue}exit${rst}\n"
  for entry in ${certName[@]}; do
    printf "%2d) [%s] %s\n" $cnt "${certValid[$cnt]}" "$entry"
    cnt+=1
  done
}
