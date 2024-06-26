#!/usr/bin/env bash
#
# Java keystore bash manager
# Author: Sergii Kulyk aka Saboteur
# Version 1.19
#
# Update:
# cp jks_mgr.sh jks_mgr.sh.old && curl -k https://raw.githubusercontent.com/sfkulyk/jks-manager/master/jks_mgr.sh > jks_mgr.sh
#
# Change history
# * First working version - list of certificates in JKS and navigate
# * Export certificate to JKS, PKCS12, CRT
# * Delete certificate
# * Rename certificate
# * Add two-panel mode
# * Copy certificate (two-panel mode only)
# * Implemented page heigh and scrolling
# * comPare certificates (two panel mode only, primary key - Serial Number)
# * Console help added
# * Auto screen height adjust
# * View certificate details
# * Add functional key support (F1, F3, F5, F6, F8, F10)
# * Auto screen width adjust, certificate alias name can be shortened to fit the screen
# * import certificate from web site
# * Colored expiration indication (yellow for <60 days, red for <20 days)
# * Filter to show/hide serial number column (single-mode only)
# * export to PEM file
# * --update console option. Or just download from github manually
# * DEBUG function. Just for development purposes
# * --version console option
# * --help console option to see usage help
# * show/hide certificate entry type column
# * inline help (F1)
# * Add suffixes to certificate entry type CA(clientAuth) / SA(serverAuth)
# * underline effect for active options
# * v1.15 Now you can sort certificates by Alias Name (up/down), certificate expiration (up/down)
# * import certificate from pem and cer files v1.16
# * v1.18 Separate option to export .crt and .key files without bag attributes
# * v1.19 Separate option to export certificate and key in kubernetes/openshift yaml format for routes
#

# If you change default password, don't forget to clear it before sharing your file outside
default_store_pwd="changeit"
CUR_VERSION="$(grep -oP '^# Version \K.*' $0)"

# highlight certificate with expiration date less then x days
WARNING_DAYS=60
CRITICAL_DAYS=20

# Init arrays and other variables
typeset -a LcertName LcertSerial LcertValid LcertDays Lflags Ltype
typeset -i LcertMax=0 LENTRY=1
typeset -a RcertName RcertSerial RcertValid RcertDays Rflags Rtype
typeset -i RcertMax=0 RENTRY=1
typeset -i POSITION=1      # Screen position
escape_char=$(printf "\u1b") # for keypress navigation
TAB="L"         # LEFT panel is default (for single mode)
pageHeight=10   # active menu height
aliasWidth=12   # default alias width for single mode
compareFlag=0
SHOW_SERIAL=""  # OFF by default. Only for single-panel mode
DEBUG=""        # If not empty, shows keytool/openssl cmds and wait for confirm
sort_mode="du"  # Default sort mode

# Init colors
red='[1m[31m'
redb='[1m[46m[31m'
green='[1m[32m'
blue='[1m[36m'
blueb='[1m[46m'
yellow='[1m[33m'
yellowb='[1m[46m[33m'
uline='[4m'
nline='[24m'
rst='(B[m'

# Init special keys
F1_KEY=$'\e[11~'
F3_KEY=$'\e[13~'
F5_KEY=$'\e[15~'
F6_KEY=$'\e[17~'
F8_KEY=$'\e[19~'
F10_KEY=$'\e[21~'
UP_KEY=$'\e[A'
DOWN_KEY=$'\e[B'
LEFT_KEY=$'\e[D'
RIGHT_KEY=$'\e[C'
TAB_KEY=$'\t'
DEL_KEY=$'\e[3~'

# Checking for mandatory external software
which keytool>/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo " ERROR: ${red}keytool${rst} is not found."
    echo " Please check that your PATH contains path to your \$JAVA_HOME/bin"
fi

help_function() {
    printf " ${blue}Keystore manager ${CUR_VERSION}\n"
    printf "   ${green}(C) Sergii Kulyk aka Saboteur${rst}\n"
    printf " ${blue}Requirements:${rst}\n"
    printf "   ${green}sed${rst}, ${green}grep${rst} and ${green}keytool ${rst}from jdk should be available in PATH\n"
    printf " ${blue}Features:${rst}\n"
    printf "   Available actions with certificates and keystores (JKS and PKCS12):\n"
    printf "     View details, Rename, Delete, Export to: JKS/PKCS12/CER/PEM formats,\n"
    printf "     Sort by alias/expiration\n"
    printf "     Import (directly from web-site)\n"
    printf "     Two-panel mode allows to Copy and Compare between keystores\n"
    printf " ${blue}Usage:${rst}\n"
    printf " ${green}jks_mgr.sh <keystore>${rst}\n"
    printf "     open jks mgr in single-panel mode\n"
    printf " ${green}jks_mgr.sh <keystore1> <keystore2>${rst}\n"
    printf "     open jks mgr in two-panel mode\n"
    printf " ${green}jks_mgr.sh --update${rst}\n"
    printf "     Automatically check and download new version from github:\n"
    printf "     ${blue}https://raw.githubusercontent.com/sfkulyk/jks-manager/master/jks_mgr.sh${rst}\n"
    printf " ${green}jks_mgr.sh --version${rst}\n"
    printf "     Show current version\n"
    printf " ${green}jks_mgr.sh --help${rst}\n"
    printf "     Show this help\n"
}

inline_help() {
    printf "\n\n ${blue}Keystore manager ${CUR_VERSION}\n"
    printf " ${green}(C) Sergii Kulyk aka Saboteur${rst}\n"
    printf "\n All hotkeys supported in uppercase and lowercase\n"
    printf " ${green}up${rst}/${green}down${rst} arrows: Navigate up/down\n"
    printf " ${green}left${rst}/${green}right${rst} arrows, tab key: Switch panel in two-panel mode\n"
    printf " ${green}F1${rst}/${green}H${rst}: Show this help page\n"
    printf " ${green}F3${rst}/${green}I${rst}: Show the following certificate info:\n"
    printf "    Alias, Creation date, Entry type, Owner, Issuer\n"
    printf "    Serial number, Valid dates, DNSName\n"
    printf " ${green}F5${rst}/${green}C${rst}: Copy certificate (only for two-panel mode\n"
    printf " ${green}F6${rst}/${green}R${rst}: Rename active certificate alias\n"
    printf " ${green}F8${rst}/${green}D${rst}: Delete active certificate\n"
    printf " ${green}F10${rst}/${green}Q${rst}: Quit program\n"
    printf " ${green}E${rst}: Export certificate to JKS, PKCS12, CRT and PEM formats\n"
    printf " ${green}M${rst}: Import certificate from web-site.\n"
    printf "    You will be asked for DNS and optionally port (default is 443)\n"
    printf "    For example: google.com\n"
    printf "                 google.com:443\n"
    printf " ${green}O${rst}: change sort order: by Alias or by Expiration up/down. \n"
    printf " ${green}P${rst}: comPare certificates (by SerialID). Existing in both will be marked with *\n"
    printf "     if opposite panel contain certificate with the same Serial ID\n"
    printf " ${green}S${rst}: show/hide Serial ID (only for single-panel mode)\n"
    printf " ${green}T${rst}: show/hide certificate entry Type - \n"
    printf "    Show PrivateKeyEntry/TrustedCertEntry + suffixes CA(clientAuth)/SA(serverAuth)\n"
    printf "\n run ${green}jks_mgr.sh --help${rst} to see usage help"
    printf "\n Press any key to return"
    read -N1
}

# wait for x seconds or continue on pressing enter
# $1 seconds, $2 text
printdelay() {
    printf "$2"
    read -N1 -t $1
}

debug() {
    [ -z "$DEBUG" ] && return
    printf "Press any key to execute the following command:\n${green}$1${rst}\n"
    read -N1
}

# automatically adjust windows height and width if it is less then 22
adjust_window() {
    read WindowHeight WindowWidth<<<$(stty size)
    localHeight=$((${WindowHeight}-7))
    if [ $pageHeight -ne $localHeight ]; then
    pageHeight=$localHeight
        if [ $pageHeight -lt 0 ]; then
            if [ -a -n "$1" ]; then
                printf "Screen height is too smal. Need at least 7 rows\n"
                exit 1
            else
                pageHeight=10 # default height
            fi
        fi
        clear
    fi

    if [ -n "$RFILE" ]; then # two-panel
        used=24 # Valid to
        [ -n "$SHOW_TYPE" ] && used=$(( $used+30 ))
        localWidth=$(( ( $WindowWidth - $used ) / 2 - 1 )) # 25 cols for valid date, divider and spaces
        if [ $localWidth -ne $aliasWidth ]; then
            aliasWidth=$localWidth
            [ $aliasWidth -lt 1 ] && aliasWidth=1
            clear
        fi
    else
        used=13 # Valid to
        [ -n "$SHOW_SERIAL" ] && used=$(( $used+40 ))
        [ -n "$SHOW_TYPE" ] && used=$(( $used+14 ))
        localWidth=$(( $WindowWidth - $used ))
        if [ $localWidth -ne $aliasWidth ]; then
            aliasWidth=$localWidth
            [ $aliasWidth -lt 1 ] && aliasWidth=1
            clear
        fi
    fi
}

sort_certs() {
    typeset -i ext_cnt int_cnt currDays current
    case $sort_mode in
      du) sort_mode="dd";;
      dd) sort_mode="nu";;
      nu) sort_mode="nd";;
      *)  sort_mode="du";;
    esac

# sort left panel
    ext_cnt=$LcertMax
    while [ $ext_cnt -gt 0 ]; do
      case $sort_mode in
        du) currDays=-9999;;
        dd) currDays=9999;;
        nu) currName="~";;
        nd) currName="";;
      esac
      int_cnt=1
      current=1
      while [ $int_cnt -le $LcertMax ]; do
      case $sort_mode in
        du) [ -n "${LcertName[$int_cnt]}" ] && [ ${LcertDays[$int_cnt]} -ge $currDays ] && current=$int_cnt && currDays=${LcertDays[$int_cnt]};;
        dd) [ -n "${LcertName[$int_cnt]}" ] && [ ${LcertDays[$int_cnt]} -le $currDays ] && current=$int_cnt && currDays=${LcertDays[$int_cnt]};;
        nu) [ -n "${LcertName[$int_cnt]}" ] && [ "${LcertName[$int_cnt]}" \< "$currName" ] && current=$int_cnt && currName=${LcertName[$int_cnt]};;
        nd) [ -n "${LcertName[$int_cnt]}" ] && [ "${LcertName[$int_cnt]}" \> "$currName" ] && current=$int_cnt && currName=${LcertName[$int_cnt]};;
      esac

        int_cnt+=1
      done
      NewName[$ext_cnt]=${LcertName[$current]}
      NewSerial[$ext_cnt]=${LcertSerial[$current]}
      NewValid[$ext_cnt]=${LcertValid[$current]}
      NewDays[$ext_cnt]=${LcertDays[$current]}
      NewFlag[$ext_cnt]=${Lflags[$current]}
      NewType[$ext_cnt]=${Ltype[$current]}
      LcertName[$current]=""
      ext_cnt=$(( $ext_cnt-1 ))
    done

    int_cnt=1
    while [ $int_cnt -le $LcertMax ]; do
      LcertName[$int_cnt]=${NewName[$int_cnt]}
      LcertSerial[$int_cnt]=${NewSerial[$int_cnt]}
      LcertValid[$int_cnt]=${NewValid[$int_cnt]}
      LcertDays[$int_cnt]=${NewDays[$int_cnt]}
      Lflags[$int_cnt]=${NewFlag[$int_cnt]}
      Ltype[$int_cnt]=${NewType[$int_cnt]}
      int_cnt=$(( int_cnt + 1 ))
    done

# sort right panel
    [ -n "$RFILE" ] || return
    ext_cnt=$RcertMax
    while [ $ext_cnt -gt 0 ]; do
      case $sort_mode in
        du) currDays=-9999;;
        dd) currDays=9999;;
        nu) currName="~";;
        nd) currName="";;
      esac
      int_cnt=1
      current=1
      while [ $int_cnt -le $RcertMax ]; do
      case $sort_mode in
        du) [ -n "${RcertName[$int_cnt]}" ] && [ ${RcertDays[$int_cnt]} -ge $currDays ] && current=$int_cnt && currDays=${RcertDays[$int_cnt]};;
        dd) [ -n "${RcertName[$int_cnt]}" ] && [ ${RcertDays[$int_cnt]} -le $currDays ] && current=$int_cnt && currDays=${RcertDays[$int_cnt]};;
        nu) [ -n "${RcertName[$int_cnt]}" ] && [ "${RcertName[$int_cnt]}" \< "$currName" ] && current=$int_cnt && currName=${RcertName[$int_cnt]};;
        nd) [ -n "${RcertName[$int_cnt]}" ] && [ "${RcertName[$int_cnt]}" \> "$currName" ] && current=$int_cnt && currName=${RcertName[$int_cnt]};;
      esac

        int_cnt+=1
      done
      NewName[$ext_cnt]=${RcertName[$current]}
      NewSerial[$ext_cnt]=${RcertSerial[$current]}
      NewValid[$ext_cnt]=${RcertValid[$current]}
      NewDays[$ext_cnt]=${RcertDays[$current]}
      NewFlag[$ext_cnt]=${Rflags[$current]}
      NewType[$ext_cnt]=${Rtype[$current]}
      RcertName[$current]=""
      ext_cnt=$(( $ext_cnt-1 ))
    done

    int_cnt=1
    while [ $int_cnt -le $RcertMax ]; do
      RcertName[$int_cnt]=${NewName[$int_cnt]}
      RcertSerial[$int_cnt]=${NewSerial[$int_cnt]}
      RcertValid[$int_cnt]=${NewValid[$int_cnt]}
      RcertDays[$int_cnt]=${NewDays[$int_cnt]}
      Rflags[$int_cnt]=${NewFlag[$int_cnt]}
      Rtype[$int_cnt]=${NewType[$int_cnt]}
      int_cnt=$(( int_cnt + 1 ))
    done

}
# $1: cert alias, $2: store file, $3: store pass
delete_cert() {
    printf "\nPress ${red}y${rst}/${red}Y${rst} to delete [${green}$1${rst}] from ${green}$2${rst}: "
    read -N1
    if [ "$REPLY" == y -o "$REPLY" == Y ]; then
        printf "\n${red}Removing certificate [$1]${rst}\n"
        keytool -delete -alias "$1" -keystore "$2" -storepass "$3"
        if [ $? -ne 0 ]; then
            printdelay 5 "${red}Error deleting $1 from $2${rst}"
            return
        fi
    else
        printdelay 5 "\n${red}Cancelled.${rst}"
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
                Lflags[$cnt]=${Lflags[$next]}
                Ltype[$cnt]=${Ltype[$next]}
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
                Rflags[$cnt]=${Rflags[$next]}
                Rtype[$cnt]=${Rtype[$next]}
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
    eval unset ${TAB}type[$cnt]
    [ $compareFlag -eq 1 ] && compare_certs
    printdelay 2 "Certificate ${blue}$1${rst} succesfully removed from ${blue}$2${rst}"
}

# Read certificate information from keystore
# $1 - store file, $2 - store pass, $3 - tab (L or R)
init_certs() {
    [ -n "$3" ] && localTAB=$3 || localTAB=L
    printf "Opening ${green}$1${rst} ... as ${localTAB}\n"
    typeset -i cnt=0

    if [ ! -s $1 ]; then
      printf "File ${blue}$1${rst} doesn't exists. Do you want to create new empty store (${green}y${rst}/${red}n${rst})?: "
      read -N1
      if [ "$REPLY" != y -a "$REPLY" != Y ]; then
        printf "${red}Aborted.${rst}\n"
        exit 0
      fi
      if [ "$localTAB" == L ]; then
        LFileEmpty=1
      else
        RFileEmpty=1
      fi
      return 0
    fi

    while read; do
        if [ "$REPLY" == "--" ]; then
             continue
        elif expr "$REPLY" : "Alias name: ">/dev/null; then
            cnt+=1
            eval ${localTAB}certMax=$cnt
            eval ${localTAB}certName[$cnt]=\"${REPLY##*: }\"
        elif expr "$REPLY" : "Serial number: ">/dev/null; then
            eval ${localTAB}certSerial[$cnt]="${REPLY##*: }"
        elif expr "$REPLY" : "Entry type: PrivateKeyEntry">/dev/null; then
            eval ${localTAB}type[$cnt]="Private"
        elif expr "$REPLY" : "Entry type: trustedCertEntry">/dev/null; then
            eval ${localTAB}type[$cnt]="Trusted"
        elif expr "$REPLY" : "Valid from: ">/dev/null; then
            validunix=$(/bin/date --date="${REPLY##*until: }" "+%s")
            tmpDays=$(( (${validunix} - $(/bin/date "+%s")) / 3600 / 24 ))
            eval ${localTAB}certDays[$cnt]=${tmpDays}
            if [ ${tmpDays} -lt ${CRITICAL_DAYS} ]; then
                eval ${localTAB}certValid[$cnt]="${red}$(/bin/date --date="${REPLY##*until: }" "+%Y-%m-%d")"
            elif [ ${tmpDays} -lt ${WARNING_DAYS} ]; then
                eval ${localTAB}certValid[$cnt]="${yellow}$(/bin/date --date="${REPLY##*until: }" "+%Y-%m-%d")"
            else
                eval ${localTAB}certValid[$cnt]="$(/bin/date --date="${REPLY##*until: }" "+%Y-%m-%d")"
            fi
        elif expr "$REPLY" : ".*clientAuth.*">/dev/null; then
            if [ "${localTAB}" == L ]; then
              Ltype[$cnt]="${Ltype[$cnt]}_CA"
            else
              Rtype[$cnt]="${Rtype[$cnt]}_CA"
            fi
        elif expr "$REPLY" : ".*serverAuth.*">/dev/null; then
            if [ "${localTAB}" == L ]; then
              Ltype[$cnt]="${Ltype[$cnt]}_SA"
            else
              Rtype[$cnt]="${Rtype[$cnt]}_SA"
            fi
        fi
    done<<<"$(keytool -list -v -keystore $1 -storepass $2 2>/dev/null|sed -nr '/Alias/,/(Certificate\[2\]|\*\*\*\*\*)/p'|grep -P '(Alias name:|Entry type:|Serial number:|Valid from:|serverAuth|clientAuth)')"
}

# Main print panels procedure.
# I believe this procedure can be optimized to print only changed things to improve overall performance...
print_certs() {
    typeset -i cnt=$POSITION
    typeset -i commonMax=${LcertMax}

    adjust_window
    hdr_alias="Alias"
    ValidSort=""
    NameSort=""
    [ "${sort_mode}" == "du" ] && ValidSort="${green}>${rst}"
    [ "${sort_mode}" == "dd" ] && ValidSort="${green}<${rst}"
    [ "${sort_mode}" == "nu" ] && NameSort="${green}>${rst}"
    [ "${sort_mode}" == "nd" ] && NameSort="${green}<${rst}"

    if [ -n "$RFILE" ]; then # two-panel
        [ "${RcertMax}" -gt "${LcertMax}" ] && commonMax=${RcertMax}
        headerWidth=$(( $aliasWidth + 5 ))
        [ -n "$SHOW_TYPE" ] && headerWidth=$(( $headerWidth + 14 ))
        printf " store: ${blue}%-$(( $headerWidth ))s${rst}" "$LFILE"
        printf "| store: ${blue}%-$(( $headerWidth -1 ))s${rst}\n" "$RFILE"
        printf "%1s%-9s " "${ValidSort}" "Valid to"
        [ -n "$SHOW_TYPE" ] && printf " %-13s" "Storetype"
        printf "%1s%-${aliasWidth}s |" "${NameSort}" "${hdr_alias:0:$aliasWidth}"

        printf "%1s%-9s " "${ValidSort}" "Valid to"
        [ -n "$SHOW_TYPE" ] && printf " %-13s" "Storetype"
        printf "%1s%-${aliasWidth}s\n" "${NameSort}" "${hdr_alias:0:$aliasWidth}"
    else # single panel
        printf " store: ${blue}%s${rst}\n" "$LFILE"
        printf "%1s%-9s " "${ValidSort}" "Valid to"
        [ -n "$SHOW_SERIAL" ] && printf " %-39s" "Serial No"
        [ -n "$SHOW_TYPE" ] && printf " %-13s" "Storetype"
        printf "%1s%-${aliasWidth}s\n" "${NameSort}" "${hdr_alias:0:$aliasWidth}"
    fi
    read WindowHeight WindowWidth<<<$(stty size)
    delimiter=$((${WindowWidth}-2))
    printf " "
    eval printf "%0.s-" {1..${delimiter}}
    printf "\n"

    if [ $commonMax -gt $(( $POSITION + $pageHeight )) ]; then
        commonMax=$(($POSITION + $pageHeight))
    fi

    while [ $cnt -le $commonMax ]; do
        if [ -n "$RFILE" ]; then # two-panels
            lcolor="" && rcolor=""
            if [ $cnt -eq $LENTRY ]; then
                [ $TAB == "L" ] && lcolor=${blueb} || lcolor=${blue}
            fi
            if [ $cnt -eq $RENTRY ]; then
                [ $TAB == "R" ] && rcolor=${blueb} || rcolor=${blue}
            fi

            printf "%1s${lcolor}%10s${rst}${lcolor}" "${Lflags[$cnt]}" "${LcertValid[$cnt]}"
            [ -n "$SHOW_TYPE" ] && printf " %-13s" ${Ltype[$cnt]}
            printf " %-${aliasWidth}s${rst}" "${LcertName[$cnt]:0:$aliasWidth}"
            printf " |%1s${rcolor}%10s${rst}${rcolor}" "${Rflags[$cnt]}" "${RcertValid[$cnt]}"
            [ -n "$SHOW_TYPE" ] && printf " %-13s" ${Rtype[$cnt]}
            printf " %-${aliasWidth}s${rst}" "${RcertName[$cnt]:0:$aliasWidth}"
            printf "\n"

        else # single panel
            [ $cnt -eq $LENTRY ] && lcolor="${blueb}" || lcolor=""
            printf " ${lcolor}%10s${rst}${lcolor}" "${LcertValid[$cnt]}"
            [ -n "$SHOW_SERIAL" ] && printf " %-39s" ${LcertSerial[$cnt]}
            [ -n "$SHOW_TYPE" ] && printf " %-13s" ${Ltype[$cnt]}
            printf " %-${aliasWidth}s${rst}\n" "${LcertName[$cnt]:0:$aliasWidth}"
        fi
        cnt+=1
    done
}

# $1 Alias $2 store $3 store pass $4 cert type
export_cert() {
    ALIASNAME=$(printf "$1"|tr -d '[]()#*?\\/'|tr " " "_")
    while true; do
        printf "\n1. ${green}J${rst}KS (Java KeyStore file)\n2. ${green}P${rst}KCS12 separate file\n3. ${green}c${rst}rt format\n4. P${green}E${rst}M\n5. ${green}S${rst}eparate .crt and .key files\n6. ${green}K${rst}ubernetes yaml for route\n0. ${red}Q${rst}uit\n\nChoose export format for certificate: ${green}$1${rst} from ${green}$2${rst}: "
        read -rsN1
        case $REPLY in
            j|J|1) FILENAME="${ALIASNAME}.jks"
                printf "\nProvide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
                read
                [ -n "$REPLY" ] && FILENAME="$REPLY"
                DESTPASS="${default_store_pwd}"
                printf "\nProvide password for $FILENAME (press ENTER to use: ${green}${DESTPASS}${rst}) :"
                read
                [ -n "$REPLY" ] && DESTPASS="$REPLY"
                keytool -importkeystore -srckeystore "$2" -destkeystore "${FILENAME}" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$DESTPASS" -deststoretype jks
                if [ $? -eq 0 ]; then
                    printdelay 2 "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}\n"
                else
                    printdelay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}\n"
                fi
                break;;
            p|P|2) FILENAME="${ALIASNAME}.pkcs12"
                printf "\nProvide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
                read
                [ -n "$REPLY" ] && FILENAME="$REPLY"
                DESTPASS="${default_store_pwd}"
                printf "\nProvide password for $FILENAME (press ENTER to use: ${green}${DESTPASS}${rst}) :"
                read
                [ -n "$REPLY" ] && DESTPASS="$REPLY"
                keytool -importkeystore -srckeystore "$2" -destkeystore "${FILENAME}" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$DESTPASS" -deststoretype pkcs12
                if [ $? -eq 0 ]; then
                    printdelay 2 "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}\n"
                else
                    printdelay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}\n"
                fi
                break;;
            c|C|3) FILENAME="${ALIASNAME}.cer"
                printf "\nProvide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
                read
                [ -n "$REPLY" ] && FILENAME="$REPLY"
                keytool -exportcert -v -alias "$1" -keystore "$2" -storepass "$3" -rfc -file "${FILENAME}"
                if [ $? -eq 0 ]; then
                    printdelay 2 "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}\n"
                else
                    printdelay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}\n"
                fi
                break;;
            e|E|4) FILENAME="${ALIASNAME}.pem"
                printf "\nProvide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
                read
                [ -n "$REPLY" ] && FILENAME="$REPLY"
                [ -f pck12.tmp ] && rm -rf pck12.tmp
                keytool -importkeystore -srckeystore "$2" -destkeystore pck12.tmp -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$3" -deststoretype pkcs12
                if [ $? -eq 0 ]; then
                    openssl pkcs12 -in pck12.tmp -passin "pass:$3" -out "$FILENAME"
                    if [ $? -eq 0 ]; then
                        printdelay 2 "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}\n"
                    else
                        printdelay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}\n"
                    fi
                else
                    printdelay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}\n"
                fi
                [ -f pck12.tmp ] && rm -rf pck12.tmp
                break;;
            s|S|5) FILENAME="${ALIASNAME}"
                if [ "${4:0:7}" != "Private" ]; then
                    printdelay 5 "\n${red}This is trusted certificate, it doesn't have key. Cancelled${rst}\n"
                    break
                fi
                printf "\nProvide export file basename (press Enter to use: ${green}${FILENAME}${rst}) :"
                read
                [ -n "$REPLY" ] && FILENAME="$REPLY"
                [ -f pck12.tmp ] && rm -rf pck12.tmp
                keytool -importkeystore -srckeystore "$2" -destkeystore pck12.tmp -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$3" -deststoretype pkcs12 2>/dev/null
                if [ $? -eq 0 ]; then
                    openssl pkcs12 -in pck12.tmp -passin "pass:$3" -out ${FILENAME}.crt -clcerts -nokeys 2>/dev/null | sed -n '/-----BEGIN/,/-----END/p'
                    result1=$?
                    openssl pkcs12 -in pck12.tmp -passin "pass:$3" -out ${FILENAME}.key -nocerts -nodes 2>/dev/null | sed -n '/-----BEGIN/,/-----END/p'
                    result2=$?
                    if [ $result1 -eq 0 ] && [ $result2 -eq 0 ]; then
                        printf "\nCertificate and private key have been successfully exported to:\n${green}"
                        ls -1 ${FILENAME}*
                        printdelay 5 "${rst}\n"
                    else
                        printdelay 5 "\n${red}ERROR: Unable to extract certificate and key${rst}\n"
                    fi
                else
                    printdelay 5 "\n${red}ERROR: Unable to extract certificate from store${rst}\n"
                fi
                [ -f pck12.tmp ] && rm -rf pck12.tmp
                break;;
            k|K|6) FILENAME="${ALIASNAME}"
                printf "\nProvide export file name (press Enter to use: ${green}${FILENAME}.txt${rst}) :"
                read
                [ -n "$REPLY" ] && FILENAME="$REPLY"
                [ -f pck12.tmp ] && rm -rf pck12.tmp
                keytool -importkeystore -srckeystore "$2" -destkeystore pck12.tmp -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$3" -deststoretype pkcs12 2>/dev/null
                if [ $? -eq 0 ]; then
                    openssl pkcs12 -in pck12.tmp -passin "pass:$3" -out ${FILENAME}.txt -nodes
                    result1=$?
                    if [ $result1 -eq 0 ]; then
                        if [ "${4:0:7}" == "Private" ]; then
                            sed -rn "/BEGIN PRIVATE KEY/,/END PRIVATE KEY/{s/^/      /;p};0,/END CERTIFICATE/{/BEGIN CERTIFICATE/,/END CERTIFICATE/{s/^/      /;p}}" ${FILENAME}.txt > ${FILENAME}.yaml
                            sed -i "/BEGIN PRIVATE KEY/i\ \ \ \ key: |-" ${FILENAME}.yaml
                            sed -i "/BEGIN CERTIFICATE/i\ \ \ \ certificate: |-" ${FILENAME}.yaml
                            printf "\nCertificate and private key have been successfully exported in yaml to:\n${green}"
                        else
                            sed -rn "0,/END CERTIFICATE/{/BEGIN CERTIFICATE/,/END CERTIFICATE/{s/^/      /;p}}" ${FILENAME}.txt > ${FILENAME}.yaml
                            sed -i "/BEGIN CERTIFICATE/i\ \ \ \ certificate: |-" ${FILENAME}.yaml
                            printf "\nCertificate have been successfully exported in yaml to:\n${green}"
                        fi
                        ls -1 ${FILENAME}.yaml
                        printdelay 5 "${rst}\n"
                    else
                        printdelay 5 "\n${red}ERROR: Unable to extract certificate or key${rst}\n"
                    fi
                else
                    printdelay 5 "\n${red}ERROR: Unable to extract certificate from store${rst}\n"
                fi
                [ -f pck12.tmp ] && rm -rf pck12.tmp
                [ -f ${FILENAME}.txt ] && rm -rf ${FILENAME}.txt
                break;;
            q|Q|0) break;;
        esac
    done
}

# print certificate details (grep for: Alias, Creation date, Owner, Issuer, Serial No, Valid date, DNS subjects)
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
    printf "\nDetails for certificate [${green}${localAlias}${rst}]:\n"
    keytool -list -v -alias "$localAlias" -keystore "$2" -storepass "$3" 2>/dev/null| sed -n '/Alias name:/p;/Creation date:/p;/Entry type:/p;/Owner:/p;/Issuer:/p;/Serial number:/p;/Valid from:/p;/DNSName:/p;/serverAuth/p;/clientAuth/p'
    printf "\nPress any key"
    read -rsn1
}

# $1 certificate alias $2 - source store $3 source storepass $4 dest store $5 dest store pass
copy_cert() {
    printf "\nPress ${red}y${rst}/${red}Y${rst} to copy [${green}$1${rst}] from ${green}$2${rst} to ${green}$4${rst}: "
    read -N1
    if [ "$REPLY" == y -o "$REPLY" == Y ]; then
        printf "\n${blue}Copying certificate [$1]${rst}\n"
        keytool -importkeystore -srckeystore "$2" -destkeystore "$4" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$5"
        if [ $? -ne 0 ]; then
            printdelay 5 "${red}Error copying $1 from $2${rst}\n"
            return
        fi
    else
        printdelay 5 "\n${red}Cancelled.${rst}\n"
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
        Rtype[${counter}]=${Ltype[${LENTRY}]}
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
        Ltype[${counter}]=${Rtype[${RENTRY}]}
    fi
    [ $compareFlag -eq 1 ] && compare_certs
    printdelay 2 "Certificate ${blue}$1${rst} succesfully copied from ${blue}$2${rst} to ${blue}$4${rst}\n"
}

import_cert() {
    printf "\nPlease choose import source (or empty string to cancel): \n"

    while true; do
        printf "\n1. ${green}W${rst}eb-site\n2. ${green}P${rst}EM file\n3. ${green}C${rst}ER file\n4. ${red}Q${rst}uit\n\n: "
        read -rsN1
        case "$REPLY" in
            w|W|1) import_from_www
                         break;;
            p|P|2) import_from_pem
                         break;;
            c|C|3) import_from_pem # .cer and .pem are the same technically
                         break;;
            q|Q|4) break;;
        esac
    done
}

import_from_pem() {
    while true; do
      printf "\nPlease enter file name (or empty string to cancel): "
      read PEMFILE
      if [ -z "$PEMFILE" ]; then
        printdelay 3 "\n${red}Cancelled.${rst}"
        return
      elif [ -f "$PEMFILE" ]; then
        break
      else
        printdelay 1 "\n${red}file ${green}$PEMFILE${red} not found, please try again${rst}"
      fi
    done
    PEMINFO=$(openssl x509 -in "$PEMFILE" -text|grep -P "(Issuer:.* \KCN = .*|Not Before:|Not After :|Subject:)")
    PEMISSUER=$(echo "$PEMINFO"|grep -Po "Issuer:(.* )CN = \K.*")
    PEMFROM=$(echo "$PEMINFO"|grep -Po "Not Before: \K.*")
    PEMTO=$(echo "$PEMINFO"|grep -Po "Not After : \K.*")
    PEMSUBJECT=$(echo "$PEMINFO"|grep -Po "Subject: .* CN = \K.*")
    printf "\nFound certificate:\n"
    printf "CN        : ${green}${PEMSUBJECT}${rst}\n"
    printf "Valid From: ${green}${PEMFROM}${rst}\n"
    printf "Valid to  : ${green}${PEMTO}${rst}\n"
    printf "Issuer    : ${green}${PEMISSUER}${rst}\n"
    printf "\nPlease enter alias (or empty string to use the following ${green}${PEMSUBJECT}${rst}) :"
    read ALIAS
    if [ -z "$ALIAS" ]; then
      ALIAS="$PEMSUBJECT"
    fi
    if [ "$TAB" == "L" ]; then
        storefile=$LFILE
        storepass=$LSTOREPASS
    else
        storefile=$RFILE
        storepass=$RSTOREPASS
    fi
    keytool -import -file "$PEMFILE" -keystore "$storefile" -storepass "$storepass" -noprompt -alias "$ALIAS"
    if [ $? -ne 0 ]; then
         printdelay 5 "${red}Can't add certificate to keystore${rst}\n"
         return
    fi
    printdelay 2 "${blue}Certificate $ALIAS was imported to $storefile${rst}\n"
    if [ "$TAB" == "L" ]; then
        init_certs "$LFILE" "$LSTOREPASS" "L"
    else
        init_certs "$RFILE" "$RSTOREPASS" "R"
    fi
}

# import certificate from web-site
import_from_www() {
    printf "\nPlease enter URL without https - [${green}site${rst}] or [${green}site:port${rst}] (or empty string to cancel): "
    read URL
    if [ -n "$URL" ]; then
        SITE=$(printf "$URL"|cut -d: -f1)
        printf "$URL"|grep :>/dev/null
        if [ $? -eq 0 ]; then
            PORT=$(printf "$URL"|cut -d: -f2)
        else
            PORT="443"
        fi
        printf "\n${blue}Getting certificate from [$SITE:$PORT]${rst}\n"
        openssl s_client -showcerts -connect "$SITE:$PORT" </dev/null 2>/dev/null|openssl x509 -outform PEM >temp.pem
        if [ $? -ne 0 ]; then
            printdelay 5 "${red}Unable to download certificate from $SITE:$PORT${rst}\n"
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
            printdelay 5 "${red}Can't add certificate to keystore${rst}\n"
            rm temp.pem
            return
        fi
        printdelay 2 "${blue}Certificate $SITE was imported to $storefile${rst}\n"
        if [ "$TAB" == "L" ]; then
            init_certs "$LFILE" "$LSTOREPASS" "L"
        else
            init_certs "$RFILE" "$RSTOREPASS" "R"
        fi
    else
        printdelay 5 "\n${red}Cancelled.${rst}"
    fi
}

# $1 source alias, $2 store file $3 store pass
rename_cert() {
    printf "\nProvide new name for ${blue}$1${rst}: "
    read newAlias
    if [ -z "$newAlias" ]; then
        printdelay 5 "\n${red}Cancelled.${rst}"
        return
    fi
    printf "\nPress ${red}y${rst}/${red}Y${rst} to rename ${green}$1${rst} from ${green}$2${rst} to ${green}${newAlias}${rst}: "
    read -N1
    if [ "$REPLY" == y -o "$REPLY" == Y ]; then
        printf "\n${blue}Renaming certificate [$1]${rst}\n"
        keytool -importkeystore -srckeystore "$2" -destkeystore "tmp.jks" -srcalias "$1" -destalias "$newAlias" -srcstorepass "$3" -deststorepass "$3"
        if [ $? -ne 0 ]; then
            printdelay 5 "${red}Error renaming certificate $1 from $2${rst}"
            return
        fi
        keytool -importkeystore -srckeystore "tmp.jks" -destkeystore "$2" -srcalias "$newAlias" -destalias "$newAlias" -srcstorepass "$3" -deststorepass "$3"
        if [ $? -ne 0 ]; then
            printdelay 5 "${red}Error renaming certificate $1 from $2${rst}"
            return
        fi
        keytool -delete -alias "$1" -keystore "$2" -storepass "$3"
        if [ $? -ne 0 ]; then
            printdelay 5 "${red}Error renaming certificate $1 from $2${rst}"
            return
        fi
    else
        printdelay 5 "\n${red}Cancelled.${rst}"
        return
    fi
    rm tmp.jks
    if [ "$TAB" == "L" ]; then
        LcertName[$LENTRY]="$newAlias"
    else
        RcertName[$RENTRY]="$newAlias"
    fi
    printdelay 2 "Certificate ${blue}$1${rst} succesfully renamed to ${blue}${newAlias}${rst}"
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

clean_compare() {
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
    compareFlag=0
}

# Parsing arguments
if [ -n "$1" -a "$1" == "--update" ]; then
    printf "${green}Checking for new version of jks manager${rst}\n"
    printf "Current version: ${blue}${CUR_VERSION}${rst}\n"
    NEW_VERSION="$(curl -k -s https://raw.githubusercontent.com/sfkulyk/jks-manager/master/jks_mgr.sh|grep -oP '^# Version \K.*')"
    if [ "$CUR_VERSION" == "$NEW_VERSION" ]; then
        printf "${blue}No new updates${rst}\n"
        exit 0
    fi
    cp $0 $0.bak
    curl -k -s https://raw.githubusercontent.com/sfkulyk/jks-manager/master/jks_mgr.sh>$0
    if [ $? -ne 0 ]; then
        mv $0.bak $0
        printf "${red}Version update failed, revert back${rst}\n"
        exit 1
    fi
    printf "${green}Successfully updated to version ${blue}${NEW_VERSION}${rst}\n"
    exit 0
fi

if [ -n "$1" -a "$1" == "--version" ]; then
  printf "Current version: ${blue}${CUR_VERSION}${rst}\n"
  exit 0
fi

if [ -n "$1" -a "$1" != "--help" ]; then
    LFILE="$1"
    printf "Provide password for ${green}$LFILE${rst}(press ENTER to use default ${green}${default_store_pwd}${rst} ): "
    read
    [ -z "$REPLY" ] && LSTOREPASS="$default_store_pwd" || LSTOREPASS="$REPLY"
else
    help_function
    exit 0
fi

# if provided second argument - switch to dual-panel mode
if [ -n "$2" ]; then
    RFILE="$2"
    printf "Provide password for ${green}$RFILE${rst}(press ENTER to use default ${green}${default_store_pwd}${rst} ): "
    read
    [ -z "$REPLY" ] && RSTOREPASS="$default_store_pwd" || RSTOREPASS="$REPLY"
fi

# load left keystore
init_certs "$LFILE" "$LSTOREPASS" "L"

# load right keystore if provided
if [ -n "$RFILE" ]; then
    init_certs "$RFILE" "$RSTOREPASS" "R"
fi
clear

# main loop
while true; do
    printf '[H'
    print_certs

    HOTKEYS="\n"
    HOTKEYS="$HOTKEYS ${blue}F1:Help"
    HOTKEYS="$HOTKEYS ${blue}F3:Info"
    [ -n "$RFILE" ] && HOTKEYS="$HOTKEYS ${green}F5:Copy"
    HOTKEYS="$HOTKEYS ${green}F6:Ren"
    HOTKEYS="$HOTKEYS ${red}F8:Del"
    HOTKEYS="$HOTKEYS ${green}Export"
    HOTKEYS="$HOTKEYS ${green}iMport"
    [ "${SHOW_TYPE}" == "Y" ] && tmptxt="${uline}${blue}Type${nline}" || tmptxt="${blue}Type"
    HOTKEYS="$HOTKEYS ${tmptxt}"
    [ $compareFlag -eq 1 ] && tmptxt="${uline}${green}comPare${nline}" || tmptxt="${green}comPare"
    [ -n "$RFILE" ] && HOTKEYS="$HOTKEYS ${tmptxt}"
    [ "${SHOW_SERIAL}" == "Y" ] && tmptxt="${uline}${blue}Serial${nline}" || tmptxt="${blue}Serial"
    [ -z "$RFILE" ] && HOTKEYS="$HOTKEYS ${tmptxt}"
    HOTKEYS="$HOTKEYS ${blue}sOrt${rst}"
    HOTKEYS="$HOTKEYS ${red}F10:Quit${rst} "
    printf "$HOTKEYS"

    # Special keypress could take variable amount of characters
    keypress=""
    read -rsN1 keytap
    while [ -n "$keytap" ]; do
        keypress="${keypress}${keytap}"
        read -sN1 -t 0.01 keytap
    done
    printf '[1K' # clear line from escaped chars

    case "$keypress" in
        $UP_KEY)
            if [ $TAB == "L" ]; then
                if [ $LFileEmpty!="1" ]; then
                    LENTRY=$(( $LENTRY-1 )); [ $LENTRY -lt 1 ] && LENTRY=1
                    if [ $POSITION -gt $LENTRY ]; then
                        POSITION=$(($POSITION-1))
                        [ $POSITION -le 1 ] && POSITION=1
                        clear
                    fi
                fi
            else
                if [ $RFileEmpty!="1" ]; then
                    RENTRY=$(( $RENTRY-1 )); [ $RENTRY -lt 1 ] && RENTRY=1
                    if [[ $POSITION -gt $RENTRY ]]; then
                        POSITION=$(($POSITION-1))
                        [ $POSITION -le 1 ] && POSITION=1
                        clear
                    fi
                fi
            fi;;
        $DOWN_KEY)
            if [ $TAB == 'L' ]; then
                if [ $LFileEmpty!="1" ]; then
                    LENTRY=$(( $LENTRY+1 ))
                    [ $LENTRY -gt $LcertMax ] && LENTRY=$LcertMax
                    if [[ $(($POSITION+$pageHeight)) -lt $LENTRY ]]; then
                        POSITION=$(($POSITION+1))
                        [ $POSITION -gt $LcertMax ] && POSITION=$LcertMax
                        clear
                    fi
                fi
            else
                if [ $LFileEmpty!="1" ]; then
                    RENTRY=$(( $RENTRY+1 ))
                    [ $RENTRY -gt $RcertMax ] && RENTRY=$RcertMax
                    if [[ $(($POSITION+$pageHeight)) -lt $RENTRY ]]; then
                        POSITION=$(( $POSITION + 1))
                        [ $POSITION -gt $RcertMax ] && POSITION=$RcertMax
                        clear
                    fi
                fi
            fi;;
        $LEFT_KEY)
            switch_tab L;;
        $RIGHT_KEY)
            switch_tab R;;
        p|P)
            [ $compareFlag -eq 0 ] && compare_certs || clean_compare
            clear;;
        e|E)
            if [ $TAB == "L" ]; then
                export_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS" "${Ltype[$LENTRY]}"
            else
                export_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS" "${Rtype[$RENTRY]}"
            fi
            clear;;
        h|H|$F1_KEY )
            inline_help
            clear;;
        i|I|$F3_KEY)
            if [ ${TAB} == "L" ]; then
                print_details "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}"
            else
                print_details "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}"
            fi
            clear;;
        c|C|$F5_KEY)
            [ -z "$RFILE" ] && continue
            if [ $TAB == "L" ]; then
                copy_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS" "$RFILE" "$RSTOREPASS"
            else
                copy_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS" "$LFILE" "$LSTOREPASS"
            fi
            clear;;
        r|R|$F6_KEY)
            if [ $TAB == "L" ]; then
                rename_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS"
            else
                rename_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS"
            fi
            clear;;
        d|D|$F8_KEY|$DEL_KEY)
            if [ $TAB == "L" ]; then
                delete_cert "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}"
            else
                delete_cert "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}"
            fi
            clear;;
        q|Q|$F10_KEY)
            printf "\n${green}Good bye${rst}\n"; exit 0;;
        o|O)
            sort_certs; clear;;
        s|S)
            [ -n "$RFILE" ] && continue
            [ -n "$SHOW_SERIAL" ] && SHOW_SERIAL="" || SHOW_SERIAL="Y"
            clear;;
        t|T)
            [ -n "$SHOW_TYPE" ] && SHOW_TYPE="" || SHOW_TYPE="Y"
            clear;;
        $TAB_KEY)
            [ "$TAB" == "L" ] && switch_tab R || switch_tab L;;
        m|M)
            import_cert
            clear;;
        *)  clear;;
    esac
done
