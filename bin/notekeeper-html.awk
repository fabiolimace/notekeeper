#!/usr/bin/awk -f













#
#
# NOTE:
#
# This file is been refactored. Only a few thing work.
# The original code is safe in `apt-html.original.awk`.
#
#
#

















#
# Converts markdown to HTML
#
# See:
# 
# * https://spec.commonmark.org
# * https://markdown-it.github.io
# * https://www.javatpoint.com/markdown
# * https://www.markdownguide.org/cheat-sheet
# * https://www.markdownguide.org/extended-syntax
# * https://pandoc.org/MANUAL.html#pandocs-markdown
# * https://www.dotcms.com/docs/latest/markdown-syntax
# * https://www.codecademy.com/resources/docs/markdown
# * https://daringfireball.net/projects/markdown/syntax
# * https://www.ecovida.org.br/docs/manual_site/markdown
# * https://quarto.org/docs/authoring/markdown-basics.html
# * https://docs.github.com/en/get-started/writing-on-github
# * https://fuchsia.dev/fuchsia-src/contribute/docs/markdown
# * https://www.ibm.com/docs/en/SSYKAV?topic=train-how-do-use-markdown
# * https://www.knowledgehut.com/blog/web-development/what-is-markdown
# * https://www.ionos.com/digitalguide/websites/web-development/markdown/
# * https://learn.microsoft.com/en-us/contribute/content/markdown-reference
# * https://developer.mozilla.org/en-US/docs/MDN/Writing_guidelines/Howto/Markdown_in_MDN
# * https://confluence.atlassian.com/bitbucketserver/markdown-syntax-guide-776639995.html
# * https://learn.microsoft.com/en-us/azure/devops/project/wiki/markdown-guidance?view=azure-devops
# * https://medium.com/analytics-vidhya/the-ultimate-markdown-guide-for-jupyter-notebook-d5e5abf728fd

function ready() {
    return at("root") || at("blockquote") || at("li");
}

function empty() {
    return idx == 0
}

function peek() {
    return stk[idx];
}

function peek_attr() {
    return stk_attr[idx];
}

function peek_spaces() {
    return stk_spaces[idx];
}

function peek_value(key,    found) {
    attr = " " peek_attr();
    if (match(attr, "[ ]" key "='[^']*'") > 0) {
        found = substr(attr, RSTART, RLENGTH);
        match(found, "='[^']*'");
        return substr(found, RSTART + 2, RLENGTH - 3);
    }
    return "";
}

function identifier() {
    return ++id;
}

function at(tag) {
    return peek() == tag ? 1 : 0;
}

function any(tags,   i, n, arr) {
    n = split(tags, arr, ",");
    for (i = 1; i <= n; i++) {
        if (at(arr[i])) {
            return 1;
        }
    }
    return "";
}

function pop_at(tag) {
    if (at(tag)) {
        return pop();
    }
    return "";
}

function pop_any(tags) {
    if (any(tags)) {
        return pop();
    }
    return "";
}

function container() {
    return any("ol,ul,li");
}

function pop() {

    if (empty()) {
        return "";
    }
    
    if (container()) {
        print_buf();
        close_tag();
    } else {
        print_tag();
    }
    
    return unpush();
}

function spaces() {
    match($0, /^[ ]*[^ ]/);
    # the number of spaces before non-space
    return (RLENGTH > 0) ? RLENGTH - 1 : RLENGTH;
}

function push(tag, attr) {

    pop_list(tag);

    ++idx;
    stk[idx] = tag;
    stk_attr[idx] = attr;
    stk_spaces[idx] = spaces();
    
    if (container()) {
        print_buf();
        open_tag();
    }
}

function pop_list(tag) {
    if (any("ol,ul") && tag != "li") {
        pop();
    }
}

function unpush(    tag) {

    tag = peek();
    if (!empty()) {
        delete stk_spaces[idx];
        delete stk_attr[idx];
        delete stk[idx];
        idx--;
    }
    
    return tag;
}

function print_tag() {
    open_tag();
    print_buf();
    close_tag();
}

function open_tag() {
    
    if (at("br") || at("hr")) {
        printf "<%s>\n", peek();
        return;
    }
    
    if (at("pre") || at("code")) {
        open_pre(peek_value("title"));
        return;
    }
    
    if (!peek_attr()) {
        printf "<%s>\n", peek();
    } else {
        printf "<%s %s>\n", peek(), peek_attr();
    }
}

function close_tag() {
    
    if (at("br") || at("hr")) {
        return; # empty element
    }
    
    if (at("pre") || at("code")) {
        close_pre();
        return;
    }
    
    printf "</%s>\n", peek();
}

function buffer(str,    sep) {
    
    if (at("pre") || at("code")) {
        sep = "\n";
    } else {
        sep = " ";
        # 2-spaces line break
        if (str ~ /[ ][ ]+$/) {
            str = rtrim(str) make_tag("br");
        }
        str = trim(str);
    }

    if (buf == "") {
        buf = str;
    } else {
        buf=buf sep str;
    }
}

function print_buf() {

    if (at("pre") || at("code")) {
        buf = escape(buf);
    } else {
        # the order matters
        buf = angles(buf);
        buf = footnotes(buf);
        buf = images(buf);
        buf = links(buf);
        buf = reflinks(buf);
        buf = styles(buf);
    }

    if (buf != "") {
        print buf;
    }
    buf = "";
}

function coalesce(str, alternative) {
    return (str) ? str : alternative;
}

function open_pre(title,    id) {

    id = identifier();
    title = coalesce(title, "&gt;_");

    if (TEST) {
        printf "<pre><code>\n";
    } else {
        printf "<div class='codeblock'>";
        printf "<div class='codeblock-head'>";
        printf "<span class='codeblock-title'>%s</span>", title;
        printf "<span class='codeblock-buttons'>%s</span>", buttons(id);
        printf "</div>";
        printf "<pre class='codeblock-body' id='%s'>", id;
        printf "<code class='codeblock-code'>";
    }
}

function close_pre() {
    if (TEST) {
        printf "</code></pre>\n";
    } else {
        printf "</code></pre>\n";
        printf "</div>\n";
    }
}

function buttons(id,    style, copy, collapse, wordwrap) {

    copy_icon = "&#x1F4CB;";
    collapse_icon = "&#x2195;";
    wordwrap_icon = "&#x21B5;";

    copy = "<button onclick='copy(" id ")' title='Copy'>" copy_icon "</button>";
    collapse = "<button onclick='collapse(" id ")' title='Collapse'>" collapse_icon "</button>";
    wordwrap = "<button onclick='wordwrap(" id ")' title='Word wrap'>" wordwrap_icon "</button>";
    
    # must return in reverse order
    return copy collapse wordwrap;
}

function styles(buf) {

    buf = snippet(buf);
    buf = formula(buf);
    buf = asterisk(buf);
    buf = underscore(buf);
    buf = deleted(buf);
    buf = inserted(buf);
    buf = highlighted(buf);
    buf = superscript(buf);
    buf = subscript(buf);
    
    return buf;
}

function snippet(buf) {
    buf = apply_style(buf, "``", "code");
    buf = apply_style(buf, "`", "code");
    return buf;
}

function formula(buf) {
    buf = apply_style(buf, "$$", "code");
    buf = apply_style(buf, "$", "code");
    return buf;
}

function underscore(buf) {
    buf = apply_style(buf, "__", "strong");
    buf = apply_style(buf, "_", "em");
    return buf;
}

function asterisk(buf) {
    buf = apply_style(buf, "**", "strong");
    buf = apply_style(buf, "*", "em");
    return buf;
}

function deleted(buf) {
    return apply_style(buf, "~~", "del");
}

function inserted(buf) {
    return apply_style(buf, "++", "ins");
}

function highlighted(buf) {
    return apply_style(buf, "==", "mark");
}

function superscript(buf) {
    return apply_style(buf, "^", "sup");
}

function subscript(buf) {
    return apply_style(buf, "~", "sub");
}

function apply_style(buf, mark, tag,    out, found, rstart, rlength) {
    
    out = "";
    len = length(mark);
    
    position = index(buf, mark);
    
    while (position > 0) {
        
        rstart = position + len;
        rlength = index(substr(buf, rstart), mark) - 1;
        
        if (rlength <= 0) break;
        
        found = substr(buf, rstart, rlength);
        
        if (tag == "code") {
            found = escape(found);
        }
        
        out = out substr(buf, 1, rstart -1 - len);
        out = out make_tag(tag, found);
        
        buf = substr(buf, rstart + rlength + len);
        position = index(buf, mark);
    }
    
    out = out buf;
    
    return out;
}

function escape(str) {
    # html special characters
    gsub(/[&]/, "\\&amp;", str);
    gsub(/[<]/, "\\&lt;", str);
    gsub(/[>]/, "\\&gt;", str);
    # markdown special characters
    gsub(/[$]/, "\\&#36;", str);
    gsub(/[*]/, "\\&#42;", str);
    gsub(/[+]/, "\\&#43;", str);
    gsub(/[-]/, "\\&#45;", str);
    gsub(/[=]/, "\\&#61;", str);
    gsub(/[\^]/, "\\&#94;", str);
    gsub(/[_]/, "\\&#95;", str);
    gsub(/[`]/, "\\&#96;", str);
    gsub(/[~]/, "\\&#126;", str);
    return str;
}


function prefix(str, start, x) {
    x = (x) ? x : 1;
    return substr(str, 1, start - x);
}

function suffix(str, start, end, x) {
    x = (x) ? x : 1;
    return substr(str, start + (end - start) + x);
}

function extract(str, start, end, x, y) {
    x = (x) ? x : 1;
    y = (y) ? y : 1;
    return substr(str, start + x, (end - start) - y);
}

# TODO: change order: tag, attr, text (<tag attr>text</tag>)
function make_tag(tag, text, attr) {
        
        if (text) {
            if (attr) {
                return "<" tag " " attr ">" text "</" tag ">";
            } else {
                return "<" tag ">" text "</" tag ">";
            }
        } else {
            if (attr) {
                return "<" tag " " attr "/>";
            } else {
                return "<" tag "/>";
            }
        }
}

# TODO: change order: href, title, text (<a href title>text</a>)
function make_link(text, href, title) {
    if (title) {
        return make_tag("a", text, "href='" href "' title='" title "'");
    } else {
        return make_tag("a", text, "href='" href "'");
    }
}

# TODO: change order and names: href, title, alt (<a href title alt/>)
function make_image(text, href, title)  {
    if (title) {
        return make_tag("img", "", "alt='" text "' src='" href "' title='" title "'");
    } else {
        return make_tag("img", "", "alt='" text "' src='" href "'");
    }
}

function make_footnote(ref) {
    return make_tag("a", "<sup>[" ref "]<sup>", "href='#foot-" ref "'");
}

# TODO: change order: ref, text (<a href="ref">text</a>)
function make_reflink(text, ref) {
    return make_tag("a", text, "href='#link-" ref "'");
}

# <ftp...>
# <http...>
# <https...>
# <email@...>
function angles(buf,    start, end, href, out) {

    out = "";
    start = index(buf, "<");
    end = index(buf, ">");

    while (0 < start && start < end) {
    
        href = extract(buf, start, end);
        
        if (index(href, "http") == 1 || index(href, "ftp") == 1) {
            push_link(id++, href);
            out = out prefix(buf, start);
            out = out make_link(href, href);
        } else if (index(href, "@") > 1) {
            push_link(id++, "mailto:" href);
            out = out prefix(buf, start);
            out = out make_link(href, "mailto:" href);
        } else {
            # do nothing; just give back
            out = out prefix(buf, end + 1);
        }
        
        buf = suffix(buf, start, end);
        start = index(buf, "<");
        end = index(buf, ">");
    }
    
    out = out buf;
    
    return out;
}

# [text](href)
# [text](href "title")
function links(buf, regex,    start, end, mid, t1, t2, temp, text, href, title, out) {

    out = "";
    start = index(buf, "[");
    mid = index(buf, "](");
    end = index(buf, ")");

    while (0 < start && start < mid && mid < end) {
    
        out = out prefix(buf, start);
        
        text = extract(buf, start, mid);
        href = extract(buf, mid, end, 2, 2);

        t1 = index(href, "\"");
        t2 = index(substr(href, t1 + 1), "\"") + t1;
        
        if (0 < t1 && t1 < t2) {
            temp = href;
            href = trim(prefix(temp, t1));
            title = trim(extract(temp, t1, t2));
        }
        
        out = out make_link(text, href, title);
        push_link(id++, href, title, text);
        
        buf = suffix(buf, start, end);
        start = index(buf, "[");
        mid = index(buf, "](");
        end = index(buf, ")");
    }
    
    out = out buf;
    
    return out;
}

# ![alt](src)
# ![alt](src "title")
function images(buf, regex,    start, end, mid, t1, t2, temp, text, href, title, out) {

    out = "";
    start = index(buf, "![");
    mid = index(buf, "](");
    end = index(buf, ")");

    while (0 < start && start < mid && mid < end) {
    
        out = out prefix(buf, start);
        
        text = extract(buf, start, mid, 2, 2);
        href = extract(buf, mid, end, 2, 2);

        t1 = index(href, "\"");
        t2 = index(substr(href, t1 + 1), "\"") + t1;
        
        if (0 < t1 && t1 < t2) {
            temp = href;
            href = trim(prefix(temp, t1));
            title = trim(extract(temp, t1, t2));
        }
        
        out = out make_image(text, href, title);
        
        buf = suffix(buf, start, end);
        start = index(buf, "![");
        mid = index(buf, "](");
        end = index(buf, ")");
    }
    
    out = out buf;
    
    return out;
}

# [^footnote]
function footnotes(buf, regex,    start, end, ref, out) {

    out = "";
    start = index(buf, "[^");
    end = index(buf, "]");

    while (0 < start && start < end) {
    
        out = out prefix(buf, start);
        
        ref = extract(buf, start, end, 2, 2);
        out = out make_footnote(ref);
        
        buf = suffix(buf, start, end);
        start = index(buf, "[^");
        end = index(buf, "]");
    }
    
    out = out buf;
    
    return out;
}

# [text][ref]
# [text] [ref]
function reflinks(buf,    start, end, mid1, mid2, out, text, ref) {
    
    out = "";
    start = index(buf, "[");
    mid1 = index(buf, "]");
        
    while (0 < start && start < mid1) {

        mid2 = index(substr(buf, mid1 + 1), "[") + mid1;
        end = index(substr(buf, mid2 + 1), "]") + mid2;
        
        if (mid1 < mid2 && mid2 < end) {
            if (mid2 - mid1 <= 2) {
                text = extract(buf, start, mid1);
                ref = extract(buf, mid2, end, 1, 1);
                out = out prefix(buf, start);
                out = out make_reflink(text, ref);
            } else {
                out = out prefix(buf, end + 1);
            }
        }
        
        buf = suffix(buf, start, end);
        start = index(buf, "[");
        mid1 = index(buf, "]");
    }
    
    out = out buf;
    
    return out;
}

function print_header() {

    print "<!DOCTYPE html>";
    print "<html>";
    print "<head>";
    print "<title></title>";
    
    print "<style>";
    print "    :root {";
    print "        --gray: #efefef;";
    print "        --black: #444;";
    print "        --dark-gray: #aaaaaa;";
    print "        --light-gray: #fafafa;";
    print "        --dark-blue: #0000ff;";
    print "        --light-blue: #0969da;";
    print "        --light-yellow: #fafaaa;";
    print "    }";
    print "    html {";
    print "        font-size: 16px;";
    print "        max-width: 100%;";
    print "    }";
    print "    body {";
    print "        padding: 1rem;";
    print "        margin: 0 auto;";
    print "        max-width: 50rem;";
    print "        line-height: 1.5rem;";
    print "        font-family: sans-serif;";
    print "        color: var(--black);";
    print "    }";
    print "    p {";
    print "        font-size: 1rem;";
    print "        margin-bottom: 1.3rem;";
    print "    }";
    print "    a, a:visited { color: var(--light-blue); }";
    print "    a:hover, a:focus, a:active { color: var(--dark-blue); }";
    print "    h1 { font-size: 1.7rem; }";
    print "    h2 { font-size: 1.4rem; }";
    print "    h3 { font-size: 1.1rem; }";
    print "    h4 { font-size: 1.1rem; }";
    print "    h5 { font-size: 0.8rem; }";
    print "    h6 { font-size: 0.8rem; }";
    print "    h1, h2 {";
    print "        padding-bottom: 0.5rem;";
    print "        border-bottom: 2px solid var(--gray);";
    print "    }";
    print "    h1, h2, h3, h4, h5, h6 {";
    print "        font-weight: bold;";
    print "        font-style: normal;";
    print "        margin: 1.4rem 0 .5rem;";
    print "    }";
    print "    h3, h5 {";
    print "        font-weight: bold;";
    print "        font-style: normal;";
    print "    }";
    print "    h4, h6 {";
    print "        font-weight: normal;";
    print "        font-style: italic;";
    print "    }";
    print "    div.codeblock {";
    print "        border-radius: .4rem;";
    print "        background-color: var(--gray);";
    print "        border: 1px solid var(--dark-gray);";
    print "    }";
    print "    div.codeblock-head {";
    print "        margin: 0rem 0rem;";
    print "        padding: 0rem 0rem;";
    print "        border-bottom: 1px solid var(--dark-gray);";
    print "    }";
    print "    span.codeblock-title {";
    print "        font-weight: bold;";
    print "        margin: 0rem 0rem;";
    print "        padding: 0rem 1rem;";
    print "    }";
    print "    span.codeblock-buttons {";
    print "        float: right;";
    print "        font-weight: bold;";
    print "        margin: 0rem 0rem;";
    print "        padding: 0rem 1rem;";
    print "    }";
    print "    pre.codeblock-body {";
    print "        overflow-x:auto;";
    print "        margin: 0rem 0rem;";
    print "        padding: 1rem 1rem;";
    print "        line-height: 1.0rem;";
    print "    }";
    print "    code.codeblock-code {";
    print "        font-size: 0.8rem;";
    print "        margin: 0rem 0rem;";
    print "        padding: 0rem 0rem;";
    print "        font-family: monospace;";
    print "    }";
    print "    code {";
    print "        border-radius: .2rem;";
    print "        padding: 0.1rem 0.3rem;";
    print "        font-family: monospace;";
    print "        background-color: var(--gray);";
    print "    }";
    print "    mark {";
    print "        padding: 0.1rem 0.3rem;";
    print "        border-radius: .2rem;";
    print "        background-color: var(--light-yellow);";
    print "    }";
    print "    blockquote {";
    print "        margin: 1.5rem;";
    print "        padding: 1rem;";
    print "        border-radius: .4rem;";
    print "        background-color: var(--light-gray);";
    print "        border: 1px solid var(--dark-gray);";
    print "        border-left: 12px solid var(--dark-gray);";
    print "    }";
    print "    dt { font-weight: bold; }";
    print "    hr { border: 1px solid var(--dark-gray); }";
    print "    img { height: auto; max-width: 100%; }";
    print "    table { border-collapse: collapse; margin-bottom: 1.3rem; }";
    print "    th { padding: .7rem; border-bottom: 1px solid var(--black);}";
    print "    td { padding: .7rem; border-bottom: 1px solid var(--gray);}";
    print "</style>";
    
    print "<script>";
    print "    function copy(id) {";
    print "        var element = document.getElementById(id);";
    print "        navigator.clipboard.writeText(element.textContent);";
    print "    }";
    print "    function wordwrap(id) {";
    print "        var element = document.getElementById(id);";
    print "        if (element.style.whiteSpace != 'pre-wrap') {";
    print "            element.style.whiteSpace = 'pre-wrap';";
    print "        } else {";
    print "            element.style.whiteSpace = 'pre';";
    print "        }";
    print "    }";
    print "    function collapse(id) {";
    print "        var element = document.getElementById(id);";
    print "        if (element.style.display != 'none') {";
    print "            element.style.display = 'none';";
    print "        } else {";
    print "            element.style.display = 'block';";
    print "        }";
    print "    }";
    print "</script>"

    print "</head>";
    print "<body>";
}

function print_footer (    i, ref, href, title, text) {
    
    print "<footer>";
    
    if (link_count > 0 || footnote_count > 0) {
        print "<hr>";
    }
    
    if (link_count > 0) {
        print "<h6>LINKS</h6>";
        print "<ol>";
        for (i = 1; i <= link_count; i++) {
        
            ref = link_ref[i];
            href = link_href[i];
            title = link_title[i];
            
            if (title == "") {
                title = href;
            }
            
            print make_tag("li", title " <a href='" href "' id='link-" ref "'>&#x1F517;</a>");
            
        }
        print "</ol>";
    }
    
    if (footnote_count > 0) {
        print "<h6>FOOTNOTES</h6>";
        print "<ol>";
        for (i = 1; i <= footnote_count; i++) {
        
            ref = footnote_ref[i];
            text = footnote_text[i];
            
            print make_tag("li", text " <a href='#foot-" ref "' id='link-" ref "'>&#x1F517;</a>");
            
        }
        print "</ol>";
    }
    
    print "</footer>";
    
    print "</body>";
    print "</html>";
}

BEGIN {

    buf=""

    idx=0
    stk[0]="root";
    stk_attr[0]="";
    stk_spaces[0]=0;

    blockquote_prefix = "^[ ]*>[ ]?";
    ul_prefix = "^([ ][ ][ ][ ])*([ ]|[ ][ ]|[ ][ ][ ])?[*+-][ ]";
    ol_prefix = "^([ ][ ][ ][ ])*([ ]|[ ][ ]|[ ][ ][ ])?[0-9]+\\.[ ]";
    
    blank = -1; # prepare to signal blank line
    
    print_header();
}

function pop_until(tag) {
    while (!empty() && !at(tag)) {
        pop();
    }
}

function level_blockquote(   i, n) {
    n = 0;
    for (i = idx; i > 0; i--) {
        if (stk[i] == "blockquote") {
            n++;
        }
    }
    return n;
}

function level_list(   i, n) {
    n = 0;
    for (i = idx; i > 0; i--) {
        if (stk[i] == "ul" || stk[i] == "ol") {
            n++;
        }
        if (stk[i] == "blockquote") break;
    }
    return n;
}

function count_indent(line) {
    return count_prefix(line, "^[ ][ ][ ][ ]");
}

function count_prefix(line, pref,    n) {
    n=0
    while (sub(pref, "", line)) {
        n++;
    }
    return n;
}

function remove_indent(line) {
    return remove_prefix(line, "^[ ][ ][ ][ ]");
}

function remove_prefix(line, pref) {

    # remove leading quote marks
    while (line ~ pref) {
        sub(pref, "", line);
    };
    
    return line;
}

function min(x, y) {
    return (x <= y) ? x : y;
}

function max(x, y) {
    return (x >= y) ? x : y;
}

function ltrim(s) { sub(/^[ \t]+/, "", s); return s; }
function rtrim(s) { sub(/[ \t]+$/, "", s); return s; }
function trim(s) { return rtrim(ltrim(s)); }

function slug(str) {
    gsub(/[^a-zA-Z0-9]/, "-", str);
    gsub(/-+/, "-", str);
    return tolower(str);
}

function push_link(ref, href, title, text) {
    link_count++;
    link_ref[link_count] = ref;
    link_href[link_count] = href;
    link_title[link_count] = title;
    link_text[link_count] = text;
}

# undo last push
function undo(    tmp) {
    tmp = buf;
    buf = "";
    unpush();
    return tmp;
}

#===========================================
# TABULATION
#===========================================

/^\t/ {
    s = " ";
    # replace only 1st tab
    sub(/^\t/, s s s s, $0);
}

#===========================================
# BLOCKQUOTES
#===========================================

function unblockquote() {
    sub(/^[ ]*>[ ]*/, "", $0);
}

# one level
/^[ ]*>[ ]*/ {

    if (at("blockquote")) {
        unblockquote();
        buffer($0);
        next;
    }

    if (at("root")) {
        push("blockquote");
        unblockquote();
        buffer($0);
        next;
    }
    
    if (!at("root")) {
        pop();
        push("blockquote");
        unblockquote();
        buffer($0);
        next;
    }
}

#===========================================
# LISTS
#===========================================

/^([ ]*[*+-][ ]+|[ ]*[0-9]+[.][ ]+).+$/ {
    
    str = $0; # copy register
    # detect the type of list
    if (str ~ /^[ ]*[*+-][ ]+/) {
        ulol = "ul";
        sub(/^[ ]*[*+-][ ]+/, "", str);
    } else {
        ulol = "ol";
        sub(/^[ ]*[0-9]+[.][ ]+/, "", str);
    }
    
    # compare spaces
    a = peek_spaces();
    b = spaces();
    
    if (b > a) {
        if (at("li")) {
            push(ulol);
            push("li");
            buffer(str);
            next;
        }
    }
    
    if (b < a) {
        if (at("li")) {
            pop();
            pop();
            pop();
            push("li");
            buffer(str);
            next;
        }
    }

    if (at("li")) {
        pop();
        push("li");
        buffer(str);
        next;
    }
    
    if (at("root")) {
        push(ulol);
        push("li");
        buffer(str);
        next;
    }
    
    if (!at("root")) {
        pop();
        push(ulol);
        push("li");
        buffer(str);
        next;
    }
}

#===========================================
# CODE BLOCKS
#===========================================

function unindent() {
    sub(/^[ ][ ][ ][ ]/, "", $0);
}

/^```/ {
    
    if (at("code")) {
        pop();
        next;
    }

    if (at("root")) {
        sub(/^`+/, "");
        push("code", "title='" $1 "'");
        next;
    }

    if (!at("root")) {
        pop();
        sub(/^`+/, "");
        push("code", "title='" $1 "'");
        next;
    }
}

at("code") {
    buffer($0);
    next;
}

/^[ ][ ][ ][ ]/ {

    if (at("pre")) {
        unindent();
        buffer($0);
        next;
    }

    if (at("root")) {
        push("pre");
        unindent();
        buffer($0);
        next;
    }
    
    if (!at("root")) {
        pop();
        push("pre");
        unindent();
        buffer($0);
        next;
    }
}

#===========================================
# HEADING
#===========================================

/^[\x23]+[ ]+/ {

    # count header level
    match($0, /^[\x23]+/);
    # remove all leading hashes
    sub(/^[\x23]+[ ]*/, "", $0);
    # remove all trailing hashes
    sub(/[ ]*[\x23]+$/, "", $0);

    if (at("root")) {
        push("h" min(RLENGTH, 6));
        buffer($0);
        next;
    }
    
    if (!at("root")) {
        pop();
        push("h" min(RLENGTH, 6));
        buffer($0);
        next;
    }
}

/^=+[ ]*$/ && at("p") {
    unpush();
    push("h1");
    pop();
    next;
}

/^-+[ ]*$/ && at("p") {
    unpush();
    push("h2");
    pop();
    next;
}

#===========================================
# HORIZONTAL RULER
#===========================================

# TODO: fix <hr> between <ul|ol> and <li>

/^[*_-][*_-][*_-]+[ ]*$/ {
    
    if (at("root")) {
        push("hr");
        pop();
        next;
    }

    if (!at("root")) {
        pop();
        push("hr");
        pop();
        next;
    }
}


#===========================================
# BLANK
#===========================================

/^[ ]*$/ {
    
    blank_flag = 1;
    
    if (at("pre")) {
        buffer("");
        next;
    }

    if (at("li")) {
        next;
    }
    
    if (at("root")) {
        next;
    }

    if (!at("root")) {
        pop();
        next;
    }
}

#===========================================
# PARAGRAPH
#===========================================

/^.+$/ {

    if (at("p")) {
        buffer($0);
        next;    
    }
    
    if (any("h1,h2,h3,h4,h5,h6")) {
        buffer($0);
        next;
    }
    
    if (at("root")) {
        push("p");
        buffer($0);
        next;
    }
    
    if (!at("root")) {
        pop();
        push("p");
        buffer($0);
        next;
    }
}

{
    blank_flag = 0;
}

#===========================================
# THE END
#===========================================

END {

    pop_at("p");
    pop_at("li");
    pop_any("pre,code");
    pop_any("h1,h2,h3,h4,h5,h6");
    
    # compatible end of file,
    # e.g., `diff`, `ed` etc.
    printf "\n";
}

