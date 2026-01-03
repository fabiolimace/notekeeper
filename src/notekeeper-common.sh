#!/bin/sh

#
# Common variables and functions for Note Keeper.
#
# Usage:
# 
#    . "`dirname "$0"`/notekeeper-common.sh";
#

PROGRAM_DIR=`dirname "$0"` # The place where the bash and awk scripts are
WORKING_DIR=`pwd -P` # The place where the collection notes are

DATA_DIR="$WORKING_DIR/.notekeeper/data";

CR="`printf "\r"`" # POSIX <carriage-return>
LF="`printf "\n"`" # POSIX <newline>
HT="`printf "\t"`" # POSIX <tab>

NOTE_SUFF="md"

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
$PROGRAM_DIR/notekeeper-save.sh
$PROGRAM_DIR/notekeeper-save-link.sh
$PROGRAM_DIR/notekeeper-save-meta.sh
$PROGRAM_DIR/notekeeper-save-hist.sh
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
    local byte=`echo "${uuid}" | cut -c1,2`
    make_path "${DATA_DIR}/${byte}/${uuid}" "${name}" "${suff}"
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

validate() {

    if [ -n "$validate" ] && [ "$validate" -eq 0 ]; then
        return;
    fi;
    
    validate_program_deps;
    validate_program_path;
    if match "$0" "notekeeper-init.sh"; then
        :
    else
        validate_working_path;
    fi;
}

main() {
    validate;
}

main;

# See [POSIX Definitions](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html):
# 3.40 Basename
# 3.129 Directory
# 3.130 Directory Entry (or Link)
# 3.136 Dot
# 3.137 Dot-Dot
# 3.164 File
# 3.170 Filename
# 3.171 Filename String
# 3.193 Home Directory
# 3.235 Name
# 3.268 Parent Directory
# 3.271 Pathname
# 3.272 Pathname Component
# 3.273 Path Prefix
# 3.281 Portable Filename
# 3.282 Portable Filename Character Set
# 3.324 Relative Pathname
# 3.330 Root Directory
# 3.447 Working Directory (or Current Working Directory)

