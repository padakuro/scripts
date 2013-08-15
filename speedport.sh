#/usr/bin/env sh
#
# script to extract some data from a Speedport router by scraping the web interface.
#
# license: WTFPL <http://www.wtfpl.net/>
# author: Pascal Kuendig <padakuro@gmail.com>
#
# tested with
#   Speedport W 723V Typ B
#   runtime_code_version="1.28.000";
#   runtime_code_date="23.05.2013, 15:48 Uhr";
#   boot_code_version="v1.04.02";
#   cm_version="CM20_V2031_0208.h";
# 
# usage: ./speedport.sh <ACTION>
# where <ACTION>
#   ip = output IP information semi-colon seperated
#   syslog = extract the system log
#
# scriptable usage: SPEEDPORT_PASSWORD=YOUR_PASSWORD ./speedport.sh <ACTION>
#

ACTION=$1
PASSWORD=$SPEEDPORT_PASSWORD
if [ "$PASSWORD" = "" ]
then
    read -s -p "Password: " PASSWORD
fi

CURL=$(which curl)
COOKIE_JAR=speedportCookieJar

request() {
    $CURL -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.95 Safari/537.36" \
        -H "Origin: https://speedport.ip" \
        --silent \
        --referer https://speedport.ip/ \
        --cookie $COOKIE_JAR --cookie-jar $COOKIE_JAR \
        $@
}

login() {
    RESULT=$(request \
        --data "login_pwd=1" \
        --data "pws=$PASSWORD" \
        --location \
        https://speedport.ip/cgi-bin/login.cgi)
        
    if [ "$?" != "0" ]
    then
        echo "Login failed."
        exit 1
    fi
}

logout() {
    RESULT=$(request --location https://speedport.ip/cgi-bin/logoutall.cgi)
    
    # clear cookiejar
    rm $COOKIE_JAR
}

extract_key() {
    # grep for given key $1, fetch value field, remove "; at end of line, remove first quote, trim newlines
    grep "$1=" | cut -f2 -d "=" | tr -d "\";" | tr -d "\"" | tr -d "\n"
}

login

DATE=$(date --iso-8601=seconds)

case "$ACTION"
in
    "ip")
        RESULT=$(request https://speedport.ip/hcti_statoview.stm)

        WAN_IP4=$(echo "$RESULT" | extract_key "wan_ip")
        WAN_GATEWAY4=$(echo "$RESULT" | extract_key "wan_gateway")
        DNS4_1=$(echo "$RESULT" | extract_key "primary_dns")
        DNS4_2=$(echo "$RESULT" | extract_key "secondary_dns")

        WAN_IP6=$(echo "$RESULT" | extract_key "IPv6_Address")
        WAN_GATEWAY6=$(echo "$RESULT" | extract_key "wan_v6gateway")
        DNS6_1=$(echo "$RESULT" | extract_key "Primary_DNSv6")
        DNS6_2=$(echo "$RESULT" | extract_key "Secondary_DNSv6")
        IP6_PREFIX=$(echo "$RESULT" | extract_key "Prefix")

        echo "$DATE;$WAN_IP4;$WAN_GATEWAY4;$DNS4_1;$DNS4_2;$WAN_IP6;$WAN_GATEWAY6;$DNS6_1;$DNS6_2;$IP6_PREFIX"
    ;;
    "syslog")
        RESULT=$(request https://speedport.ip/cgi-bin/log)
        # grep the actual log messages (yeah, they are seperated through a <br> and a newline) and skip the first line which usually is just a useless info message and the last admin login date/time
        # after that, replace all <br>s and decode the html entities
        LOG=$(echo "$RESULT" | grep "<br>" | tail -n +2 | sed "s/<br>//" | recode HTML_4.0)
        echo "$LOG"
    ;;
    *)
        echo "Unknown action: $ACTION"
    ;;
esac

logout