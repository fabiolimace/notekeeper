#!/usr/bin/awk -f

#
# Lists all links found in a markdown file.
#
# Usage:
#
#     awk -f notekeeper-links.awk FILE
#     busybox awk -f notekeeper-links.awk FILE
#
# It works with gawk and busybox.
#

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

function find_all_links(str, links,    i, n, matches) {

    i = 0;
    delete links;
    
    n = find_all($0, "\\[[^]]+\\]\\([^)]*\\)", matches);
    
    for (i = 1; i <= n; i++) {
        match(matches[i], "\\([^)]*\\)");
        links[i] = substr(matches[i], RSTART + 1, RLENGTH - 2);
        sub(/[ ].*$/, "", links[i]); # remove label after space
    }
    
    return n;
}

# [Github](https://github.com)
/\[[^]]+\]\([^)]*\)/ {
    
    n = find_all_links($0, links);

    for (i = 1; i <= n; i++) {
        printf "%s\n", links[i];
    }
}

#
# TODO:
#
# *   <https://github.com>
# *   <user@github.com>
# *   [Github](https://github.com "optional title attribute")
# *   [Github]: https://github.com
# *   [Github]: https://github.com "optional title attribute"
#
# https://www.markdownguide.org/basic-syntax/
#

