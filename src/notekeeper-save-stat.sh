#!/bin/sh

#
# Saves a STAT file in in `data` folder.
#
# Usage:
#
#     apwm-save-stat.sh FILE
#

. "`dirname "$0"`/notekeeper-common.sh";

file="${1}"
require_file "${file}";

main() {
    local file="${1}"
    local uuid=`path_uuid "${file}"`;
    local stat=`make_stat "${file}"`;
    LC_ALL=C "$PROGRAM_DIR/awk/notekeeper-stat.awk" -v WRITETO=/dev/stdout "${file}" > "${stat}"
}

main "${file}";

