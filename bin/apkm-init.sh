#!/bin/sh

#
# Initializes the Note Keeper in the current directory.
#
# Usage:
#
#     # Backup!
#     notekeeper-init.sh
#
# How to undo initialization:
#
#     # Be careful and backup!
#     rm -rf COLLECTION/.notekeeper
#
# Where COLLECTION is the directory where this init script was executed.
#

. "`dirname "$0"`/notekeeper-common.sh";

notekeeper_init() {
    
    echo "----------------------"
    echo "Init directory"
    echo "----------------------"
    echo "mkdir -p \"$WORKING_DIR/.notekeeper\""
    
    mkdir -p "$WORKING_DIR/.notekeeper"
    mkdir -p "$WORKING_DIR/.notekeeper/html"
    mkdir -p "$WORKING_DIR/.notekeeper/data"
    
cat > "$WORKING_DIR/.notekeeper/conf.txt" <<EOF
busybox.httpd.port=127.0.0.1:9000
EOF

}

if [ ! -d "$WORKING_DIR" ];
then
    echo "Base directory not found."
    exit 1;
fi;

if [ -d "$WORKING_DIR/.notekeeper" ];
then
    echo "Note Keeper already initialized in this directory."
    exit 1;
fi;

main() {
    notekeeper_init;
}

main;

