#!/bin/sh

#
# Saves metadata and links in `meta` folder.
#
# Usage:
#
#     notekeeper-save.sh FILE
#

. "`dirname "$0"`/notekeeper-common.sh";

list_tags() {
    local note="${1}"
    "$PROGRAM_DIR/awk/notekeeper-tags.awk" "${note}";
}

http_status() {
    local href="$1"
    timeout 1s wget --server-response --spider --quiet "${href}" 2>&1 | awk 'NR==1 { print $2 }'
}

file_diff() {
    local note="${1}"
    require_file "${note}";
    notekeeper_load_hist "${note}" | diff -u /dev/stdin "${note}";
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

normalize_href() {

    local href=`path_remove_slashes "${1}"`
    
    local norm_href=""
    local norm_href_option_1="${href}"
    local norm_href_option_2=`path_remove_dots "${href}"`
    
    # use option 2, without dots, if both HREFs ponit to same file
    if [ -f "${norm_href_option_1}" ] && [ -f "${norm_href_option_2}" ]; then
        # check if both options of HREF point to the same file, i.e. the same inode on the file system
        if [ "`stat -c %d:%i "${norm_href_option_1}"`" = "`stat -c %d:%i "${norm_href_option_2}"`" ]; then
            norm_href="${norm_href_option_2}";
        else
            norm_href="${norm_href_option_1}";
        fi;
    else
        norm_href="${norm_href_option_1}";
    fi;
    
    echo "$norm_href";
}

note_changed() {

    local note="${1}"
    local hash=`file_hash "${note}"`
    local uuid=`note_uuid "${note}"`;
    local meta=`make_meta "${note}"`;
    
    local result=1;
    
    if [ -f "${meta}" ];
    then
        local prev=`grep -E "^hash=" "${meta}" | head -n 1 | sed "s/^hash=//";`
    
        if [ "${hash}" = "${prev}" ];
        then
            result=0;
        fi;
    fi;
    
    echo ${result};
}

notekeeper_save_meta() {
    # Saves metadata in `meta` file.

    local note="${1}"
    require_file "${note}"
    
    local uuid=`note_uuid "${note}"`;
    local meta=`make_meta "${note}"`;
    
    local path # Path relative to base directory
    local name # File name without extension
    local hash # File hash
    local crdt # Create date
    local updt # Update date
    local tags # Comma separated values
    
    local uuid="`note_uuid "${note}"`"
    local path="${note}"
    local name="`basename -s."${NOTE_SUFF}" "${note}"`"
    local hash="`file_hash "${note}"`"
    local crdt="`now`"
    local updt="`now`"
    local tags="`list_tags "${note}"`"
    
    if [ -f "${meta}" ];
    then
        crdt=`grep -E "^crdt=" "${meta}" | head -n 1 | sed "s/^crdt=//"`;
    fi;
    
    cat > "${meta}" <<EOF
uuid=${uuid}
path=${path}
name=${name}
hash=${hash}
crdt=${crdt}
updt=${updt}
tags=${tags}
EOF

}

notekeeper_save_link() {
    # Saves links in `link` file.

    local note="${1}"
    require_file "${note}";
    
    local uuid=`note_uuid "${note}"`;
    local link=`make_link "${note}"`;
    
    local orig # UUIDv8 of the origin note
    local dest # UUIDv8 of the destination note
    local href # Path relative to the origin note (as is) or URL
    local path # Path relative to the base directory (normalized)
    local type # Link type: Internal (I), External (E), Fragment (F)
    local brok # Broken link: unknown (0), broken (1)
    
    local temp=`make_temp`
    
    "$PROGRAM_DIR/awk/notekeeper-link.awk" "${note}" | while read -r line; do
        
        href="${line}";
        orig="${uuid}";
        
        if match "${href}" "https?:\/\/";
        then
            local status="`http_status "${href}"`"
            if [ "${status}" = "200" ]; then
                brok="0";
            else
                brok="1";
            fi;
            dest="";
            path="";
            type="E";
        elif match "${href}" "^#"; then
            brok="0"; # TODO: check if the fragment is exists in the current note
            dest="";
            path="";
            type="F";
        else
            local norm_href=`normalize_href "${href}"`
            if [ -f "$norm_href" ]; then
                brok="0";
                dest="`note_uuid "${path}"`";
            else
                brok="1";
                dest="";
            fi;
            path="$norm_href";
            type="I";
        fi;
        
        printf "${orig}\t${dest}\t${href}\t${path}\t${type}\t${brok}\n" >> "${temp}";
        
    done;
    
    sort "${temp}" | uniq > "${link}";
    
    rm -f "${temp}";
}

notekeeper_save_hist() {
    # Saves history in `hist` file.
    # 
    # History file structure:
    # 
    #     1. History file info '##'.
    #     2. Start of diff '#@'.
    #     3. End of diff '#%'.
    # 

    local note="${1}"
    require_file "${note}";
    
    local uuid=`note_uuid "${note}"`;
    local hist=`make_hist "${note}"`;
    
    local path="${note}"
    local updt="`file_updt "${note}"`"
    local hash="`file_hash "${note}"`"
    
    if [ ! -f "${hist}" ]; then
        echo "$HIST_NOTE_INFO uuid=${uuid}" >> "${hist}"
        echo "$HIST_NOTE_INFO path=${path}" >> "${hist}"
    fi;
    
    cat >> "${hist}" <<EOF
${HIST_DIFF_START} ${updt}${HT}${hash}
`file_diff "${note}"`
${HIST_DIFF_END}
EOF

}

notekeeper_load_hist() {
    # Load a note version from note history.
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

    local note="${1}"
    local date="${2}"
    local hash="${2}"
    
    require_file "${note}";
    
    local uuid=`note_uuid "${note}"`;
    local hist=`make_hist "${note}"`;
    
    require_file "${hist}" "No history for file '${note}'."
    
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

notekeeper_save() {

    # find only .md files
    local find_regex=".*.\(md\)$";
    
    # ignore the .notekeeper folder
    local ignore_regex="\\.\(notekeeper\)";

    cd "$WORKING_DIR";
    find . -type f -regex "${find_regex}" | grep -v "${ignore_regex}" | while read -r line; do
    
        note=`echo $line | sed 's,^\./,,'`; # remove leading "./"
        changed=`note_changed "${note}"`;
        
        if [ ${changed} -eq 1 ]; then
             make_dir "`make_meta "${note}"`" # TODO
             notekeeper_save_meta "${note}";
             notekeeper_save_link "${note}";
             notekeeper_save_hist "${note}";
        fi;
    done;
}

notekeeper_save;


