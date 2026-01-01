#!/usr/bin/awk -f

#
# Lists all tags found in a markdown file.
#
# Tags must be in Twitter format: letters, numbers and underscore.
#
# Usage:
#
#     awk -f notekeeper-tags.awk FILE
#     busybox awk -f notekeeper-tags.awk FILE
#
# It works with gawk and Busybox.
#
# Busybox don't support diacritics. Avoid them.
#

BEGIN {
    list="";
    regex="(^|[ ])(#[[:alpha:]][[:alnum:]]+)";
}

# https://unix.stackexchange.com/q/379385/
function find_all(str, regex, matches,    n) {
    
    n = 0;
    delete matches;
    
    while (match(str, regex) > 0) {
        matches[++n] = substr(str, RSTART, RLENGTH);
        if (str == "") break;
        str = substr(str, RSTART + (RLENGTH ? RLENGTH : 1));
    }
    
    return n;
}

function word(    tag) {
    sub(/^[ ]?\x23/, "", tag)
    return tolower(tag);
}

$0 !~ "^#" && $0 ~ regex {

    n = find_all($0, regex, tags);
    
    for (i = 1; i <= n; i++) {
        if (!list) {
            list=word(tags[i])
        } else {
            list=list "," word(tags[i])
        }
    }
}

END {
    print list;
}

