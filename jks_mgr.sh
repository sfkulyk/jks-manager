#!/bin/ksh
#
# Java keystore bash manager
# Update:
# cp jks_mgr.sh jks_mgr.sh.old && curl -k https://raw.githubusercontent.com/sfkulyk/jks-manager/master/jks_mgr.sh > jks_mgr.sh
#
# Author: Sergii Kulyk aka Saboteur
# Version 1.6
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
# * Add colors for certificate expiration (yellow for <60 days, red for <20 days)
# * Add show serial feature to single-panel mode
# * Add export to PEM file
# * Autoupdater. Also added url to the file for manual update
# * Debug feature

# If you change default password, don't forget to clear it before sharing your file outside
default_store_pwd="changeit"

# highlight certificate with expiration date less then x days
WARNING_DAYS=60
CRITICAL_DAYS=20

# Init arrays and other variables
typeset -A LcertName LcertSerial LcertValid LcertDays Lflags
typeset -i LcertMax=0 LENTRY=1
typeset -A RcertName RcertSerial RcertValid RcertDays Rflags
typeset -i RcertMax=0 RENTRY=1
escape_char=$(printf "\u1b") # for keypress navigation
TAB="L"         # LEFT panel is default (for single mode)
POSITION=1      # Screen position
pageHeight=10   # active menu height
aliasWidth=12   # default alias width for dual mode
compareFlag=0
SHOW_SERIAL=""  # OFF by default. Only for single-panel mode
DEBUG=""        # If not empty, shows keytool/openssl cmds and wait for confirm

# colors
red=$(tput bold;tput setaf 1)
redb=$(tput bold;tput setab 6;tput setaf 1)
green=$(tput bold;tput setaf 2)
blue=$(tput bold;tput setaf 6)
blueb=$(tput bold;tput setab 6)
yellow=$(tput bold;tput setaf 3)
yellowb=$(tput bold;tput setab 6;tput setaf 3)
rst=$(tput sgr0)

help_function() {
    printf " ${blue}Keystore manager\n"
    printf " ${green}(C) Sergii Kulyk aka Saboteur${rst}\n"
    printf " ${blue}Requirements:${rst}\n"
    printf "   sed, grep and keytool from jdk should be available in PATH\n"
    printf " ${blue}Features:${rst}\n"
    printf "   Browse certificates in keystores supported by keytool (JKS, PKCS12)\n"
    printf "   In case of providing two stores, two-panel mode will be enabled.\n"
    printf "   Available commands:\n"
    printf "     View details, Rename, Delete, Export to JKS, PKCS12, CER formats,\n"
    printf "     Import (directly from web-site)\n"
    printf "     in two-panel mode also available: Copy, Compare (by cert serial ID)\n"
    printf " ${blue}Usage:${rst}\n"
    printf "   jks_mgr.sh <store> [<store2>]\n"
}

# wait for x seconds or continue on pressing enter
# $1 seconds, $2 text
delay() {
    printf "$2"
    read -N1 -t $1
}

debug() {
    printf "Press any key to execute the following command:\n${green}$1${rst}\n"
    read -N1
}

# automatically adjust windows height if it is less then 22
adjust_height() {
    localHeight=$(( $(tput lines)-7 )) # 7 lines for header and footer
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
    localWidth=$(( ( $(tput cols) - 25 ) / 2 - 1 )) # 25 cols for valid date, divider and spaces
    if [ $localWidth -ne $aliasWidth ]; then
        aliasWidth=$localWidth
        [ $aliasWidth -lt 1 ] && aliasWidth=12
        clear
    fi
}

# $1: cert alias, $2: store file, $3: store pass
delete_cert() {
    printf "\nPress ${red}y${rst}/${red}Y${rst} to delete [${green}$1${rst}] from ${green}$2${rst}: "
    read -N1
    if [ "$REPLY" == y -o "$REPLY" == Y ]; then
        printf "\n${red}Removing certificate [$1]${rst}\n"
        [ -n "$DEBUG" ] && debug "keytool -delete -alias \"$1\" -keystore \"$2\" -storepass \"$3\""
        keytool -delete -alias "$1" -keystore "$2" -storepass "$3"
        if [ $? -ne 0 ]; then
            delay 5 "${red}Error deleting $1 from $2${rst}"
            return
        fi
    else
        delay 5 "\n${red}Cancelled.${rst}"
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
    [ compareFlag -eq 1 ] && compare_certs
    delay 2 "Certificate ${blue}$1${rst} succesfully removed from ${blue}$2${rst}"
}

# Read certificate information from keystore
# $1 - store file, $2 - store pass, $3 - tab (L or R)
init_certs() {
    [ -n "$3" ] && localTAB=$3 || localTAB=L
    printf "Opening ${green}$1${rst} ... as ${localTAB}\n"
    typeset -i cnt=1

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

# Main print panels procedure.
# I believe this procedure can be optimized to print only changed things to improve overall performance...
print_certs() {
    typeset -i cnt=$POSITION
    typeset -i commonMax=${LcertMax}

    adjust_height

    if [ -n "$RFILE" ]; then
        [ "${RcertMax}" -gt "${LcertMax}" ] && commonMax=${RcertMax}
        printf " store: ${blue}%-${aliasWidth}s${rst}     | store: ${blue}%-${aliasWidth}s${rst}\n" "$LFILE" "$RFILE"
        printf " %-10s %-${aliasWidth}s | %-10s %-${aliasWidth}s\n" "Valid to" "Alias" "Valid to" "Alias"
    else
        printf " store: ${blue}%s${rst}\n" "$LFILE"
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

            if [ "${LcertDays[$cnt]}" -lt $CRITICAL_DAYS ]; then
                lvcolor="${lcolor}${red}"
            elif [ "${LcertDays[$cnt]}" -lt $WARNING_DAYS ]; then
                lvcolor="${lcolor}${yellow}"
            else
                lvcolor="${lcolor}"
            fi
            if [ "${RcertDays[$cnt]}" -lt $CRITICAL_DAYS ]; then
                rvcolor="${rcolor}${red}"
            elif [ "${RcertDays[$cnt]}" -lt $WARNING_DAYS ]; then
                rvcolor="${rcolor}${yellow}"
            else
                rvcolor="${rcolor}"
            fi

            printf "%1s${lvcolor}%10s${rst}${lcolor} %-${aliasWidth}s${rst} |%1s${rvcolor}%10s${rst}${rcolor} %-${aliasWidth}s${rst}\n" "${Lflags[$cnt]}" "${LcertValid[$cnt]}" "${LcertName[$cnt]:0:$aliasWidth}" "${Rflags[$cnt]}" "${RcertValid[$cnt]}" "${RcertName[$cnt]:0:$aliasWidth}"
        else
            [ $cnt -eq $LENTRY ] && lcolor="${blueb}" || lcolor=""
            if [ "${LcertDays[$cnt]}" -lt 20 ]; then
                lvcolor="${lcolor}${red}"
            elif [ "${LcertDays[$cnt]}" -lt 60 ]; then
                lvcolor="${lcolor}${yellow}"
            else
                lvcolor="${lcolor}"
            fi
            if [ -n "$SHOW_SERIAL" ]; then
                printf " ${lvcolor}%10s${rst}${lcolor} %-39s %s${rst}\n" "${LcertValid[$cnt]}" ${LcertSerial[$cnt]} "${LcertName[$cnt]}"
            else
                localWidth=$(( $(tput cols) - 13 ))
                printf " ${lvcolor}%10s${rst}${lcolor} %-${aliasWidth}s${rst}\n" "${LcertValid[$cnt]}" "${LcertName[$cnt]:0:$localWidth}"
            fi
        fi
        cnt+=1
    done
}

# $1 Alias $2 store $3 store pass
export_cert() {
    ALIASNAME=$(printf "$1"|tr -d '[]()#*?\\/'|tr " " "_")
    while true; do
        printf "\n1. ${green}J${rst}KS\n2. ${green}P${rst}KCS12\n3. ${green}c${rst}rt\n4. P${green}E${rst}M\n5. ${red}Q${rst}uit\n\nChoose export format for certificate: ${green}$1${rst} from ${green}$2${rst}: "
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
                         [ -n "$DEBUG" ] && debug "keytool -importkeystore -srckeystore \"$2\" -destkeystore \"${FILENAME}\" -srcalias \"$1\" -destalias \"$1\" -srcstorepass \"$3\" -deststorepass \"$DESTPASS\" -deststoretype jks"
                         keytool -importkeystore -srckeystore "$2" -destkeystore "${FILENAME}" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$DESTPASS" -deststoretype jks
                         if [ $? -eq 0 ]; then
                             delay 2 "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}\n"
                         else
                             delay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}\n"
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
                         [ -n "$DEBUG" ] && debug "keytool -importkeystore -srckeystore \"$2\" -destkeystore \"${FILENAME}\" -srcalias \"$1\" -destalias \"$1\" -srcstorepass \"$3\" -deststorepass \"$DESTPASS\" -deststoretype pkcs12"
                         keytool -importkeystore -srckeystore "$2" -destkeystore "${FILENAME}" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$DESTPASS" -deststoretype pkcs12
                         if [ $? -eq 0 ]; then
                             delay 2 "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}\n"
                         else
                             delay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}\n"
                         fi
                         break;;
            c|C|3) FILENAME="${ALIASNAME}.cer"
                         printf "\nProvide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
                         read
                         [ -n "$DEBUG" ] && debug "keytool -exportcert -v -alias \"$1\" -keystore \"$2\" -storepass \"$3\" -rfc -file \"${FILENAME}\""
                         keytool -exportcert -v -alias "$1" -keystore "$2" -storepass "$3" -rfc -file "${FILENAME}"
                         if [ $? -eq 0 ]; then
                             delay 2 "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}\n"
                         else
                             delay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}\n"
                         fi
                         break;;
            e|E|4) FILENAME="${ALIASNAME}.pem"
                         printf "\nProvide export file name (press ENTER to use: ${green}${FILENAME}${rst}) :"
                         read
                         [ -f pck12.tmp ] && rm -rf pck12.tmp
                         [ -n "$DEBUG" ] && debug "keytool -importkeystore -srckeystore \"$2\" -destkeystore pck12.tmp -srcalias \"$1\" -destalias \"$1\" -srcstorepass \"$3\" -deststorepass \"$3\" -deststoretype pkcs12"
                         keytool -importkeystore -srckeystore "$2" -destkeystore pck12.tmp -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$3" -deststoretype pkcs12
                         if [ $? -eq 0 ]; then
                             [ -n "$DEBUG" ] && debug "openssl pkcs12 -in pck12.tmp -passin \"pass:$3\" -out \"$FILENAME\""
                             openssl pkcs12 -in pck12.tmp -passin "pass:$3" -out "$FILENAME"
                             if [ $? -eq 0 ]; then
                                 delay 2 "Certificate ${blue}$1${rst} is succesfully exported to ${blue}${FILENAME}${rst}\n"
                             else
                                 delay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}\n"
                             fi
                         else
                             delay 5 "${red}Error with exporting $1 to ${FILENAME}${rst}\n"
                         fi
                         [ -f pck12.tmp ] && rm -rf pck12.tmp
                         break;;
            q|Q|5) break;;
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
    keytool -list -v -alias "$localAlias" -keystore "$2" -storepass "$3" 2>/dev/null| sed -n '/Alias:/p;/Creation date:/p;/Entry type:/p;/Owner:/p;/Issuer:/p;/Serial number:/p;/Valid from:/p;/DNSName:/p'
    printf "\nPress any key"
    read -rsn1
}

# $1 certificate alias $2 - source store $3 source storepass $4 dest store $5 dest store pass
copy_cert() {
    printf "\nPress ${red}y${rst}/${red}Y${rst} to copy [${green}$1${rst}] from ${green}$2${rst} to ${green}$4${rst}: "
    read -N1
    if [ "$REPLY" == y -o "$REPLY" == Y ]; then
        printf "\n${blue}Copying certificate [$1]${rst}\n"
        [ -n "$DEBUG" ] && debug "keytool -importkeystore -srckeystore \"$2\" -destkeystore \"$4\" -srcalias \"$1\" -destalias \"$1\" -srcstorepass \"$3\" -deststorepass \"$5\""
        keytool -importkeystore -srckeystore "$2" -destkeystore "$4" -srcalias "$1" -destalias "$1" -srcstorepass "$3" -deststorepass "$5"
        if [ $? -ne 0 ]; then
            delay 5 "${red}Error copying $1 from $2${rst}\n"
            return
        fi
    else
        delay 5 "\n${red}Cancelled.${rst}\n"
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
    delay 2 "Certificate ${blue}$1${rst} succesfully copied from ${blue}$2${rst} to ${blue}$4${rst}\n"
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
        [ -n "$DEBUG" ] && debug "openssl s_client -showcerts -connect \"$SITE:$PORT\" </dev/null 2>/dev/null|openssl x509 -outform PEM >temp.pem"
        openssl s_client -showcerts -connect "$SITE:$PORT" </dev/null 2>/dev/null|openssl x509 -outform PEM >temp.pem
        if [ $? -ne 0 ]; then
            delay 5 "${red}Unable to download certificate from $SITE:$PORT${rst}\n"
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
        [ -n "$DEBUG" ] && debug "keytool -import -file temp.pem -keystore \"$storefile\" -storepass \"$storepass\" -noprompt -alias \"$SITE\""
        keytool -import -file temp.pem -keystore "$storefile" -storepass "$storepass" -noprompt -alias "$SITE"
        if [ $? -ne 0 ]; then
            delay 5 "${red}Can't add certificate to keystore${rst}\n"
            rm temp.pem
            return
        fi
        delay 2 "${blue}Certificate $SITE was imported to $storefile${rst}\n"
        if [ "$TAB" == "L" ]; then
            init_certs "$LFILE" "$LSTOREPASS" "L"
        else
            init_certs "$RFILE" "$RSTOREPASS" "R"
        fi
        [ compareFlag -eq 1 ] && compare_certs
    else
        delay 5 "\n${red}Cancelled.${rst}"
    fi
}

# $1 source alias, $2 store file $3 store pass
rename_cert() {
    printf "\nProvide new name for ${blue}$1${rst}: "
    read newAlias
    if [ -z "$newAlias" ]; then
        delay 5 "\n${red}Cancelled.${rst}"
        return
    fi
    printf "\nPress ${red}y${rst}/${red}Y${rst} to rename ${green}$1${rst} from ${green}$2${rst} to ${green}${newAlias}${rst}: "
    read -N1
    if [ "$REPLY" == y -o "$REPLY" == Y ]; then
        printf "\n${blue}Renaming certificate [$1]${rst}\n"
        [ -n "$DEBUG" ] && debug "keytool -importkeystore -srckeystore \"$2\" -destkeystore \"tmp.jks\" -srcalias \"$1\" -destalias \"$newAlias\" -srcstorepass \"$3\" -deststorepass \"$3\""
        keytool -importkeystore -srckeystore "$2" -destkeystore "tmp.jks" -srcalias "$1" -destalias "$newAlias" -srcstorepass "$3" -deststorepass "$3"
        if [ $? -ne 0 ]; then
            delay 5 "${red}Error renaming certificate $1 from $2${rst}"
            return
        fi
        [ -n "$DEBUG" ] && debug "keytool -importkeystore -srckeystore \"tmp.jks\" -destkeystore \"$2\" -srcalias \"$newAlias\" -destalias \"$newAlias\" -srcstorepass \"$3\" -deststorepass \"$3\""
        keytool -importkeystore -srckeystore "tmp.jks" -destkeystore "$2" -srcalias "$newAlias" -destalias "$newAlias" -srcstorepass "$3" -deststorepass "$3"
        if [ $? -ne 0 ]; then
            delay 5 "${red}Error renaming certificate $1 from $2${rst}"
            return
        fi
        [ -n "$DEBUG" ] && debug "keytool -delete -alias \"$1\" -keystore \"$2\" -storepass \"$3\""
        keytool -delete -alias "$1" -keystore "$2" -storepass "$3"
        if [ $? -ne 0 ]; then
            delay 5 "${red}Error renaming certificate $1 from $2${rst}"
            return
        fi
    else
        delay 5 "\n${red}Cancelled.${rst}"
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
    CUR_VERSION="$(grep -P '^# Version \K.*' $0)"
    printf "Updating version of jks manager\n"
    printf "Current version: ${CUR_VERSION}\n"
    cp $0 $0.bak
    curl -k https://raw.githubusercontent.com/sfkulyk/jks-manager/master/jks_mgr.sh>$0
    if [ $? -ne 0 ]; then
        mv $0.bak $0
        printf "Version update failed, revert back\n"
        exit 1
    fi
    NEW_VERSION="$(grep -P '^# Version \K.*' $0)"
    if [ "$CUR_VERSION" == "$NEW_VERSION" ]; then
        printf "No new updates\n"
        rm $0.bak
    else
      printf "Successfully updated to version ${NEW_VERSION}\n"
    fi
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
    tput home
    print_certs
    
    if [ -n "$RFILE" ]; then
        printf "\n F3:${green}I${rst}nfo F5:${green}C${rst}opy F6:${green}R${rst}ename F8:${red}D${rst}elete c${green}O${rst}mpare ${green}E${rst}xport i${green}M${rst}port F10:${red}Q${rst}uit "
    else
        printf "\n F3:${green}I${rst}nfo F6:${green}R${rst}ename F8:${red}D${rst}elete ${green}E${rst}xport i${green}M${rst}port ${green}S${rst}erial F10:${red}Q${rst}uit "
    fi

    # Special keypress could take up to 4 characters
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
        q|Q|'[21~')	# q/Q/F10
            printf "\n${green}Good bye${rst}\n"; exit 0;;
        '[A')		# Up arrow
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
        '[B')		# Down arrow
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
        '[D')		# Left arrow
            switch_tab L;;
        '[C')		# Right arrow
            switch_tab R;;
        o|O)
            [ compareFlag -eq 0 ] && compare_certs || clean_compare
            clear;;
        e|E)
            if [ $TAB == "L" ]; then
                export_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS"
            else
                export_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS"
            fi
            clear;;
        c|C|'[15~')	# c/C/F5
            [ -z "$RFILE" ] && continue
            if [ $TAB == "L" ]; then
                copy_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS" "$RFILE" "$RSTOREPASS"
            else
                copy_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS" "$LFILE" "$LSTOREPASS"
            fi
            clear;;
        d|D|'[19~')	# d/D/F8
            if [ $TAB == "L" ]; then
                delete_cert "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}"
            else
                delete_cert "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}"
            fi
            clear;;
        i|I|'[13~'|OR)	# i/I/F3 ( ^[OR - F3 in tectia )
            if [ ${TAB} == "L" ]; then
                print_details "${LcertName[$LENTRY]}" "${LFILE}" "${LSTOREPASS}"
            else
                print_details "${RcertName[$RENTRY]}" "${RFILE}" "${RSTOREPASS}"
            fi
            clear;;
        r|R|'[17~')	# r/R/F6
            if [ $TAB == "L" ]; then
                rename_cert "${LcertName[$LENTRY]}" "$LFILE" "$LSTOREPASS"
            else
                rename_cert "${RcertName[$RENTRY]}" "$RFILE" "$RSTOREPASS"
            fi
            clear;;
        s|S)
            [ -n "$RFILE" ] && continue
            [ -n "$SHOW_SERIAL" ] && SHOW_SERIAL="" || SHOW_SERIAL="Y"
            clear;;
        $'\t')          # tab
            [ "$TAB" == "L" ] && switch_tab R || switch_tab L;;
        m|M)
            import_from_www
            clear;;
        *)  clear;;
    esac
done
