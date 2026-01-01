#!/bin/sh
#
# Wrapper for the real Note Keeper main program
#
# See: http://mywiki.wooledge.org/BashFAQ/028
#

if [ -e "~/.notekeeper.conf" ];
then
    . "~/.notekeeper.conf";
elif [ -e "/etc/notekeeper.conf" ];
then
    . "/etc/notekeeper.conf";
fi;

exec "$NOTEKEEPER_HOME/bin/notekeeper" || {
    echo 1>&2 'Could not execute "$NOTEKEEPER_HOME/bin/notekeeper".\n'
    exit 1
}

