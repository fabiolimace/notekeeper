#!/bin/sh

#
# Load a file version from file history.
#
# Usage:
#
#     notekeeper-save-load.sh FILE [DATE|HASH]
#
# Returns the first version that matches DATE or HASH, otherwise returns the latest version.
#
# Search by date or hash:
# 
#    - Use leading chars of a specific hash, e.g: "eeb180fd0436c2edcd05d2" or "ee".
#    - Use a date string that `date` command can parse, e.g: '2006-08-14 02:34:56'.
#    - Use ">" to search for the first date after a given date, e.g: ">2024-06-24".
#    - Use "<" to search for the last date before a given date, e.g: "<2024-06-24".
# 
# History file structure:
#
#     1. History file info '##'.
#     2. Start of diff '#@'.
#     3. End of diff '#&'.
# 

. "`dirname "$0"`/notekeeper-common.sh";

file="${1}"
date="${2}"
hash="${2}" # yes, 2 again

require_file "${file}";

busybox_patch() {

    local temp_file="${1}"
    local temp_diff="${2}"

    # Workaround for busybox: remove the empty old file before calling the applet "patch".
    # Summary of the only issue I found: https://github.com/bazelbuild/rules_go/issues/2042
    # 1.  "can't open 'BUILD.bazel': File exists"
    # 2.  "I suspect patch on Alpine is following POSIX semantics and requires the -E flag."
    # 3.  "-E  --remove-empty-files Remove output files that are empty after patching."
    # 4.  Busybox don't have the option '-E', which is a GNU extension, i.e. not POSIX.
    if [ ! -s "${temp_file}" ]; then
        rm "${temp_file}"
    fi;
    
    patch -u "${temp_file}" "${temp_diff}" > /dev/null;
    
    touch "${temp_file}" # undo the workaround
}

gnu_patch() {

    local temp_file="${1}"
    local temp_diff="${2}"
    
    patch -u "${temp_file}" "${temp_diff}" > /dev/null;
}

apply_patch() {

    local temp_file="${1}"
    local temp_diff="${2}"
    local temp_hash="${3}"
    
    if symlinked_busybox "patch"; then
        busybox_patch "${temp_file}" "${temp_diff}";
    else
        gnu_patch "${temp_file}" "${temp_diff}";
    fi;
    
    if [ -n "${temp_hash}" ]; then
        if [ "`file_hash "${temp_file}"`" != "${temp_hash}" ]; then
            echo "Error while loading history: intermediate hashes don't match." > /dev/stderr;
            rm -f "${temp_file}" "${temp_diff}";
            exit 1;
        fi;
    fi;
}

main() {

    local file="${1}"
    local date="${2}"
    local hash="${3}"
    
    local uuid=`note_uuid "${file}"`;
    local hist=`make_hist "${file}"`;
    
    require_file "${hist}" "No history for file '${file}'."
    
    local temp_date="";
    local temp_hash="";
    local temp_diff="`make_temp`"
    local temp_file="`make_temp`"
    
    cat "${hist}" | while IFS= read -r line; do
    
        if match "${line}" "^${HIST_NOTE_INFO}"; then
            # ignore
            continue;
        elif match "${line}" "^${HIST_DIFF_START}"; then
        
            cat /dev/null > "${temp_diff}";
            
            temp_date="`echo "${line}" \
                | sed -E "s/^$HIST_DIFF_START *//" \
                | awk 'BEGIN { FS="'"${HT}"'" } {print $1}'`";
            temp_hash="`echo "${line}" \
                | sed -E "s/^$HIST_DIFF_START *//" \
                | awk 'BEGIN { FS="'"${HT}"'" } {print $2}'`";
                
            continue;
        elif match "${line}" "^${HIST_DIFF_END}"; then
        
            if test -n "${date}" && match "${date}" "^<"; then
                if [ `unix_secs "${temp_date}"` -ge `unix_secs "${date#\<}"` ]; then
                    break;
                fi;
            fi;
            
            apply_patch "${temp_file}" "${temp_diff}" "${temp_hash}";
            
            if test -n "${date}" && match "${date}" "^>"; then
                if [ `unix_secs "${temp_date}"` -gt `unix_secs "${date#\>}"` ]]; then
                    break;
                fi;
            fi;
            
            if test -n "${date}" && match "${temp_date}" "^${date}"; then
                break;
            fi;
            
            if test -n "${hash}" && match "${temp_hash}" "^${hash}"; then
                break;
            fi;
            
            continue;
        fi;

        echo "${line}" >> "${temp_diff}";
    
    done;
    
    cat "${temp_file}" && rm -f "${temp_file}" "${temp_diff}";
}

main "${file}" "${date}" "${hash}"

