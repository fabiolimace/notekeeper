#!/bin/sh

#
# Saves metadata, history and links in `COLLECTION/.notekeeper/data` folder.
#
# Usage:
#
#     notekeeper-save.sh
#

PROGRAM_DIR=`dirname "$0"` # The place where the bash and awk scripts are
WORKING_DIR=`pwd -P` # The place where the collection notes are

DATA_DIR="$WORKING_DIR/.notekeeper/data";

CR="`printf "\r"`" # POSIX <carriage-return>
LF="`printf "\n"`" # POSIX <newline>
HT="`printf "\t"`" # POSIX <tab>

NOTE_SUFF=".md"

HIST_NOTE_INFO="##"
HIST_DIFF_START="#@"
HIST_DIFF_END="#%"

NUMB_REGEX="^-?[0-9]+$";
HASH_REGEX="^[a-f0-9]{40}$";
DATE_REGEX="^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"
UUID_REGEX="^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$";

check_dependency_exists() {
    local dep=${1};
    if [ -z "$(which $dep)" ];
    then
        echo "Dependency not installed: '$dep'" 1>&2
        exit 1;
    fi;
}

validate_program_deps() {
    check_dependency_exists awk;
}

validate_program_path() {

    if [ ! -f "$PROGRAM_DIR/notekeeper-init.sh" ];
    then
        echo "Not the Note Keeper program directory: '$PROGRAM_DIR'" 1>&2
        exit 1;
    fi;
    
    while read -r line; do
        if [ ! -e "$line" ];
        then
            echo "File or directory not found: '$line'" 1>&2
            exit 1;
        fi;
    done <<EOF
$PROGRAM_DIR/awk/notekeeper-link.awk
$PROGRAM_DIR/awk/notekeeper-tags.awk
EOF

}

check_file_exists() {
    local file=${1};
    if [ ! -e "$file" ];
    then
        echo "File or directory not found: '$file'" 1>&2
        exit 1;
    fi;
}

validate_working_path() {

    if [ ! -d "$WORKING_DIR/.notekeeper" ];
    then
        echo "Not a Note Keeper collection directory: '$WORKING_DIR'" 1>&2
        exit 1;
    fi;
    
    while read -r line; do
        check_file_exists "$line";
    done <<EOF
$DATA_DIR
EOF

    if [ "$PWD" != "$WORKING_DIR" ];
    then
        echo "Out of the Note Keeper collection directory: '$PWD' != '$WORKING_DIR'" 1>&2
        exit 1;
    fi;
}

now() {
    date_time;
}

unix_secs() {
    local input=${1};
    date -d "${input}" +%s;
}

date_time() {
    local input=${1};
    if [ -n "${input}" ];
    then
        if match "${input}" ${DATE_REGEX}; then
            date -d "${input}" +"%F %T";
        elif match "${input}" ${NUMB_REGEX}; then
            date -d @"${input}" +"%F %T";
        else
            echo "1970-01-01 00:00:00"; # epoch
        fi;
    else
        date +"%F %T";
    fi;
}

file_updt() {
    local file="${1}"
    date_time $(stat -c %Y "${file}");
}

file_hash() {
    local file="${1}"
    sha1sum "${file}" | head -c 40
}

rand_uuid() {
    cat /proc/sys/kernel/random/uuid
}

note_uuid() {
    local note="${1}"
    local hash=`echo -n "${note}" | sha256sum`;
    echo "${hash}" | awk '{ print substr($0,1,8) "-" substr($0,9,4) "-8" substr($0,14,3) "-8" substr($0,18,3) "-" substr($0,21,12) }'
}

make_meta() {
    local note="${1}"
    data_path "${note}" "meta" "data"
}

make_hist() {
    local note="${1}"
    data_path "${note}" "hist" "diff"
}

make_link() {
    local note="${1}"
    data_path "${note}" "link" "tsv"
}

data_path() {
    local note="${1}";
    local name="${2}";
    local suff="${3}";
    local uuid=`note_uuid "${note}"`;
    make_path "${DATA_DIR}/${uuid:0:2}/${uuid}" "${name}" "${suff}"
}

make_path() {
    local base="${1}"
    local name="${2}"
    local suff="${3}"
    path_remove_dots "${base}/${name}.${suff}"
}

make_dir() {
    local file="${1}"
    local base=`dirname "${file}"`
    [ -d "${base}" ] || mkdir -p "${base}"
}

# Remove all "./" and "../" from paths,
# except "../" in the start of the path.
# The folder before "../" is also deleted.
# ./a/b/./c/file.txt -> ./a/b/c/file.txt
# ../a/b/../c/file.txt -> ../a/c/file.txt
path_remove_dots() {
    local file="${1}"
    echo "$file" \
    | awk '{ sub(/^\.\//, "") ; print }' \
    | awk '{ while ($0 ~ /\/\.\//) { sub(/\/\.\//, "/") }; print }' \
    | awk '{ while ($0 ~ /\/[^\/]+\/\.\.\//) { sub(/\/[^\/]+\/\.\.\//, "/") }; print }';
}

# Remove double slashes "//" from paths,
# The leading slash "/" is also deleted.
# a//b/c/d/file.txt -> a/b/c/d/file.txt
# /a/b/c/d/file.txt -> a/b/c/d/file.txt
path_remove_slashes() {
    local file="${1}"
    echo "$file" \
    | awk '{ sub(/^\//, "") ; print }' \
    | awk '{ gsub(/\/\/+/, "/") ; print }';
}

make_temp() {
    # prefere the tmpfs device
    if [ -d "/dev/shm" ]; then
        mktemp -p /dev/shm;
    else
        mktemp;
    fi;
}

require_file() {
    local file="${1}";
    local mesg="${2}";
    if [ ! -f "${file}" ]; then
        test -n "${mesg}" \
            && (echo "${mesg}" 1>&2) \
            || (echo "File not found: '${file}'" 1>&2);
        exit 1;
    fi;
}

symlinked_busybox() {
    program=`which "${1}"` && (stat -c "%N" "${program}" | grep -q busybox)
}

match() {
    local text="${1}";
    local rexp="${2}";
    echo "${text}" | grep -E -q "${rexp}";
}

notekeeper_validate() {

    if [ -n "$validate" ] && [ "$validate" -eq 0 ]; then
        return;
    fi;
    
    validate_program_deps;
    validate_program_path;
    validate_working_path;
}

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
    
    local hash # File hash
    local crdt # Create date
    local updt # Update date
    local tags # Comma separated values
    
    local uuid="`note_uuid "${note}"`"
    local hash="`file_hash "${note}"`"
    local crdt="`now`"
    local updt="`now`"
    local tags="`list_tags "${note}"`"
    
    make_dir "${meta}";
    
    if [ -f "${meta}" ];
    then
        crdt=`grep -E "^crdt=" "${meta}" | head -n 1 | sed "s/^crdt=//"`;
    fi;
    
    cat > "${meta}" <<EOF
uuid=${uuid}
note=${note}
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
    local norm # Path relative to the base directory (normalized)
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
            norm="";
            type="E";
        elif match "${href}" "^#"; then
            brok="0"; # TODO: check if the fragment is exists in the current note
            dest="";
            norm="";
            type="F";
        else
            norm=`normalize_href "${href}"`
            if [ -f "$norm" ]; then
                brok="0";
                dest="`note_uuid "${norm}"`";
            else
                brok="1";
                dest="";
            fi;
            type="I";
        fi;
        
        printf "${orig}\t${dest}\t${href}\t${norm}\t${type}\t${brok}\n" >> "${temp}";
        
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
    
    local updt="`file_updt "${note}"`"
    local hash="`file_hash "${note}"`"
    
    if [ ! -f "${hist}" ]; then
        echo "$HIST_NOTE_INFO uuid=${uuid}" >> "${hist}"
        echo "$HIST_NOTE_INFO note=${note}" >> "${hist}"
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

    cd "${WORKING_DIR}";
    find . -type f -name "*${NOTE_SUFF}" -not -path "${WORKING_DIR}/.notekeeper" | while read -r line; do
    
        note=`echo $line | sed 's,^\./,,'`; # remove leading "./"
        changed=`note_changed "${note}"`;
        
        if [ ${changed} -eq 1 ]; then
             notekeeper_save_meta "${note}";
             notekeeper_save_link "${note}";
             notekeeper_save_hist "${note}";
        fi;
    done;
}

main() {
    notekeeper_validate;
    notekeeper_save;
}

main;


