#!/bin/sh

#
# Runs the Markdown tests.
#

validate="0"

. "`dirname "$0"`/notekeeper-common.sh";

numb=0
file=/dev/shm/test.md
html=/dev/shm/test.html
tmpl=/dev/shm/tmpl.html

generate_template() {
    cat /dev/null > "${tmpl}"
    echo "---" |"$PROGRAM_DIR/awk/notekeeper-html.awk" > "${tmpl}"
}

exit_error() {
    echo ""
    echo "ERROR: Test ${1} failed!";
    exit 1;
}

run_test() {

    local numb="${1}"
    local file="${2}"
    local html="${3}"
    
    generate_template;
    
    sed -E '/<hr>/,$d' "${tmpl}" >> "${html}.temp"
    cat "${html}" >> "${html}.temp"
    sed -E '1,/<hr>/d' "${tmpl}" >> "${html}.temp"
    mv "${html}.temp" "${html}"
    
    "$PROGRAM_DIR/awk/notekeeper-html.awk" -vTEST=1 -- "${file}" \
        | diff -u - "${html}" \
        || exit_error ${numb};
}

run() {
    numb=`expr $numb + 1`
    run_test $numb "${file}" "${html}";
}

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cat <<EOF > /dev/shm/test.md
This is a template.
EOF

cat <<EOF > /dev/shm/test.html
<p>
This is a template.
</p>
EOF

run;

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cat <<EOF > /dev/shm/test.md
A First Level Header
====================

A Second Level Header
---------------------

Now is the time for all good men to come to
the aid of their country. This is just a
regular paragraph.

The quick brown fox jumped over the lazy
dog's back.

### Header 3
> This is a blockquote.
> 
> This is the second paragraph in the blockquote.
>
> ## This is an H2 in a blockquote
EOF

cat <<EOF > /dev/shm/test.html
<h1>
A First Level Header
</h1>
<h2>
A Second Level Header
</h2>
<p>
Now is the time for all good men to come to the aid of their country. This is just a regular paragraph.
</p>
<p>
The quick brown fox jumped over the lazy dog's back.
</p>
<h3>
Header 3
</h3>
<blockquote>
<p>
This is a blockquote.
</p>
<p>
This is the second paragraph in the blockquote.
</p>
<h2>
This is an H2 in a blockquote
</h2>
</blockquote>
EOF

#run;

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cat <<EOF > /dev/shm/test.md
I really like using Markdown.

I think I'll use it to format all of my documents from now on.

EOF

cat <<EOF > /dev/shm/test.html
<p>
I really like using Markdown.
</p>
<p>
I think I'll use it to format all of my documents from now on.
</p>
EOF

run;

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# https://daringfireball.net/projects/markdown/syntax
cat <<EOF > /dev/shm/test.md
This is an H1
=============

This is an H2
-------------

# This is an H1

## This is an H2

###### This is an H6

# This is an H1 #

## This is an H2 ##

### This is an H3 ######
EOF

cat <<EOF > /dev/shm/test.html
<h1>
This is an H1
</h1>
<h2>
This is an H2
</h2>
<h1>
This is an H1
</h1>
<h2>
This is an H2
</h2>
<h6>
This is an H6
</h6>
<h1>
This is an H1
</h1>
<h2>
This is an H2
</h2>
<h3>
This is an H3
</h3>
EOF

#run;

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# https://daringfireball.net/projects/markdown/syntax
cat <<EOF > /dev/shm/test.md
This is a normal paragraph:

    This is a code block.
Here is an example of AppleScript:

    tell application "Foo"
        beep
    end tell
EOF

cat <<EOF > /dev/shm/test.html
<p>
This is a normal paragraph:
</p>
<pre><code>
This is a code block.
</code></pre>
<p>
Here is an example of AppleScript:
</p>
<pre><code>
tell application "Foo"
    beep
end tell
</code></pre>
EOF

run;

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# https://daringfireball.net/projects/markdown/syntax
cat <<EOF > /dev/shm/test.md
This is a normal paragraph:
\`\`\`
This is a code block.
\`\`\`
Here is an example of AppleScript:
\`\`\`
tell application "Foo"
    beep
end tell
\`\`\`
EOF

cat <<EOF > /dev/shm/test.html
<p>
This is a normal paragraph:
</p>
<pre><code>
This is a code block.
</code></pre>
<p>
Here is an example of AppleScript:
</p>
<pre><code>
tell application "Foo"
    beep
end tell
</code></pre>
EOF

run;

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



