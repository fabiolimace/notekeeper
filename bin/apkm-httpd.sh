#!/bin/sh

#
# Runs the Busybox httpd server.
#
# Usage:
#
#     notekeeper-http-server.sh
#
# Configuration:
#
#     # file .notekeeper/conf.txt
#     busybox.httpd.port=127.0.0.1:9000
#

. "`dirname "$0"`/notekeeper-common.sh";

property_port="busybox.httpd.port"
property_port_default="127.0.0.1:9000"

busybox_httpd_port() {
    local port=`grep -E "^${property_port}" "${WORKING_DIR}/.notekeeper/notekeeper.conf" | sed "s/${property_port}=//"`;
    if [ -n "${port}" ]; then
        echo "${port}";
    else
        echo "${property_port_default}";
    fi;
}

busybox_httpd_stop() {
    local pid=`ps aux | grep 'busybox httpd' | grep -v "grep" | awk '{ print $2 }'`
    if [ -n "$pid" ] && [ "$pid" -gt 1024 ]; then
        kill -9 $pid;
    fi;
}

busybox_httpd_start() {
    local port=`busybox_httpd_port`;
#    busybox httpd -p "$port" -h "$PROGRAM_DIR/../www/"
    busybox httpd -p "$port" -h "$WORKING_DIR/.notekeeper/html/"
    echo Listening: "http://$port"
}

main() {
    busybox_httpd_stop;
    busybox_httpd_start;
}

main;

# https://datatracker.ietf.org/doc/html/rfc3875
# https://www.vivaolinux.com.br/artigo/Introducao-a-CGI-com-a-RFC-3875
# https://gist.github.com/stokito/a9a2732ffc7982978a16e40e8d063c8f
# https://github.com/Mikepicker/cgiblog
# https://medium.com/@Mikepicker/no-framework-blog-for-fun-and-profit-using-bash-cgi-cbb99cf5366b
