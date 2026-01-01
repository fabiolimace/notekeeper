#!/bin/sh

#
# Saves HTML in `html` folder.
#
# Usage:
#
#     notekeeper-save-html.sh FILE
#

. "`dirname "$0"`/notekeeper-common.sh";

file="${1}"
require_file "${file}";

main() {
    local file="${1}"
    local html=`make_html "${file}"`
    mkdir -p "`dirname "${html}"`"
    "$PROGRAM_DIR/notekeeper-html.awk" "${file}" > "${html}"
}

main "${file}";

