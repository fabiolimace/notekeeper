#!/usr/bin/awk -f

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

function at(tag) {
    return peek() == tag ? 1 : 0;
}

function peek() {
    return stk[idx];
}

function peek_attr() {
    return stk_attr[idx];
}

function push(tag, attr) {

    ++id;
    ++idx;

    stk[idx] = tag;
    stk_attr[idx] = attr;
    
    open_tag(id);
    
    # close <br> and <hr>
    if (at("br") || at("hr")) {
        pop();
    }
    
    return id;
}

function pop() {
    if (empty()) {
        return "";
    }
    
    close_tag();
    return unpush();
}

function unpush(    tag) {
    tag = peek();
    if (!empty()) {
        delete stk_attr[idx];
        delete stk[idx--];
    }
    return tag;
}

function write() {

    if (at("pre") || at("code")) {
        buf = escape(buf);
    } else {
        # the order matters
        buf = diamonds(buf);
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

function append(str, sep) {

    if (at("pre") || at("code")) {
        if (sep == "") sep = "\n";
    } else {
        if (sep == "") sep = " ";
        # append 2-spaces line break
        if (str ~ /^[^ ]+[ ][ ]+$/) {
            str = rtrim(str) "<br>";
        }
        str = trim(str);
    }

    if (buf == "") {
        buf = str;
    } else {
        buf=buf sep str;
    }
}

function open_tag(id) {

    write();
    
    tag = peek();
    attr = peek_attr();
    
    if (at("br") || at("hr")) {
        printf "<%s>\n", tag;
        return;
    }
    
    if (at("pre") || at("code")) {
        open_pre(id, peek_value("title"));
        return;
    }
      
#    if (at("h1") || at("h2") || at("h3")) {
#        if (!attr) {
#            attr = "id='" id "'";
#        } else {
#            attr = "id='" id "' " attr;
#        }
#    }
    
    if (!attr) {
        printf "<%s>\n", tag;
    } else {
        printf "<%s %s>\n", tag, attr;
    }
}

function close_tag() {

    write();
    
    if (at("br") || at("hr")) {
        # do nothing.
        # already closed.
        return;
    }
    
    if (at("pre") || at("code")) {
        close_pre();
        return;
    }
    
    printf "</%s>\n", peek();
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

function open_pre(id, title) {
    printf "<pre>";
    printf "<div class='pre-head'>";
    printf "<span>%s</span>", title;
    printf "%s", buttons(id);
    printf "</div>";
    printf "<div class='pre-body' id='%s'>", id;
    return;
}

function close_pre() {
    printf "</div>";
    printf "</pre>";
    return;
}

function buttons(id,    style, clipboard, wordwrap) {
    collapse = "<button onclick='collapse(" id ")' title='Toggle collapse' class='pre-button'>↕</button>";
    clipboard = "<button onclick='wordwrap(" id ")' title='Toggle word-wrap' class='pre-button'>⏎</button>";
    wordwrap = "<button onclick='clipboard(" id ")' title='Copy to clipboard' class='pre-button'>📋</button>";
    return clipboard collapse wordwrap;
}

# TODO: change order: tag, attr, text (<tag attr>text</tag>)
function make(tag, text, attr) {
        
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

function snippet(buf) {
    buf = apply_style(buf, "``", 2, "code");
    buf = apply_style(buf, "`", 1, "code");
    return buf;
}

function formula(buf) {
    buf = apply_style(buf, "$$", 2, "code");
    buf = apply_style(buf, "$", 1, "code");
    return buf;
}

function underscore(buf) {
    buf = apply_style(buf, "__", 2, "strong");
    buf = apply_style(buf, "_", 1, "em");
    return buf;
}

function asterisk(buf) {
    buf = apply_style(buf, "**", 2, "strong");
    buf = apply_style(buf, "*", 1, "em");
    return buf;
}

function deleted(buf) {
    return apply_style(buf, "~~", 2, "del");
}

function inserted(buf) {
    return apply_style(buf, "++", 2, "ins");
}

function highlighted(buf) {
    return apply_style(buf, "==", 2, "mark");
}

function superscript(buf) {
    return apply_style(buf, "^", 1, "sup");
}

function subscript(buf) {
    return apply_style(buf, "~", 1, "sub");
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

function apply_style(buf, mark, len, tag,    out, found, rstart, rlength) {
    
    out = "";
    
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
        out = out make(tag, found);
        
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

function make_link(text, href, title) {
    if (title) {
        return make("a", text, "href='" href "' title='" title "'");
    } else {
        return make("a", text, "href='" href "'");
    }
}

function make_image(text, href, title)  {
    if (title) {
        return make("img", "", "alt='" text "' src='" href "' title='" title "'");
    } else {
        return make("img", "", "alt='" text "' src='" href "'");
    }
}

function make_footnote(footnote) {
    return make("a", "<sup>[" footnote "]<sup>", "href='#foot-" footnote "'");
}

function make_reflink(text, ref) {
    return make("a", text, "href='#link-" ref "'");
}

# <ftp...>
# <http...>
# <https...>
# <email@...>
function diamonds(buf,    start, end, href, out) {

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
function footnotes(buf, regex,    start, end, out, footnote) {

    out = "";
    start = index(buf, "[^");
    end = index(buf, "]");

    while (0 < start && start < end) {
    
        out = out prefix(buf, start);
        
        footnote = extract(buf, start, end, 2, 2);
        out = out make_footnote(footnote);
        
        buf = suffix(buf, start, end);
        start = index(buf, "[^");
        end = index(buf, "]");
    }
    
    out = out buf;
    
    return out;
}

function min(x, y) {
    return (x <= y) ? x : y;
}

function max(x, y) {
    return (x >= y) ? x : y;
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
    print "        line-height: 1.8;";
    print "        font-family: sans-serif;";
    print "        color: var(--black);";
    print "    }";
    print "    p {";
    print "        font-size: 1rem;";
    print "        margin-bottom: 1.3rem;";
    print "    }";
    print "    a, a:visited { color: var(--light-blue); }";
    print "    a:hover, a:focus, a:active { color: var(--dark-blue); }";
    print "    h1 { font-size: 2.0rem; }";
    print "    h2 { font-size: 1.5rem; }";
    print "    h3 { font-size: 1.2rem; }";
    print "    h4 { font-size: 1.2rem; }";
    print "    h5 { font-size: 0.8rem; }";
    print "    h6 { font-size: 0.8rem; }";
    print "    h1, h2 {";
    print "        padding-bottom: 0.5rem;";
    print "        border-bottom: 2px solid var(--gray);";
    print "    }";
    print "    h1, h2, h3, h4, h5, h6 {";
    print "        line-height: 1.4;";
    print "        font-style: normal;";
    print "        font-weight: bold;";
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
    print "    pre {";
    print "        overflow-x:auto;";
    print "        line-height: 1.5;";
    print "        border-radius: .4rem;";
    print "        font-family: monospace;";
    print "        background-color: var(--gray);";
    print "        border: 1px solid var(--dark-gray);";
    print "    }";
    print "    div.pre-head {";
    print "        height: 1.5rem;";
    print "        padding: 1rem;";
    print "        font-weight: bold;";
    print "        padding-top: 0.5rem;";
    print "        padding-bottom: 0.5rem;";
    print "        border-bottom: 1px solid var(--dark-gray);";
    print "    }";
    print "    div.pre-body {";
    print "        padding: 1rem;";
    print "    }";
    print "    button.pre-button {";
    print "        font-size: 100%; float: right;";
    print "    }";
    print "    code {";
    print "        padding: 0.3rem;";
    print "        border-radius: .2rem;";
    print "        font-family: monospace;";
    print "        background-color: var(--gray);";
    print "    }";
    print "    mark {";
    print "        padding: 0.3rem;";
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
    print "    function clipboard(id) {";
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
            
            print make("li", title " <a href='" href "' id='link-" ref "'>&#x1F517;</a>");
            
        }
        print "</ol>";
    }
    
    if (footnote_count > 0) {
        print "<h6>FOOTNOTES</h6>";
        print "<ol>";
        for (i = 1; i <= footnote_count; i++) {
        
            ref = footnote_ref[i];
            text = footnote_text[i];
            
            print make("li", text " <a href='#foot-" ref "' id='link-" ref "'>&#x1F517;</a>");
            
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

function ltrim(s) { sub(/^[ \t]+/, "", s); return s; }
function rtrim(s) { sub(/[ \t]+$/, "", s); return s; }
function trim(s) { return rtrim(ltrim(s)); }

function slug(str) {
    gsub(/[^a-zA-Z0-9]/, "-", str);
    gsub(/-+/, "-", str);
    return tolower(str);
}

#===========================================
# TABULATIONS
#===========================================

{
    gsub("\t", "    ", $0); # replace tabas with 4 spaces
}

#===========================================
# BLANK LINES
#===========================================

# Blank line flag states:
#  0: not signaling blank line
# -1: preparing to signal blank line
#  1: signaling blank line

blank == 1 {
    blank = 0;
}

blank == -1 {
    blank = 1;
}

/^[ ]*$/ {
    if (!at("code")) {
        blank = -1;
        pop_p();
        pop_blockquote();
        next;
    }
}

#===========================================
# BLOCKQUOTE
#===========================================

function pop_blockquote() {

    if (!at("blockquote")) return;

    lv = level_blockquote();
    cp = count_prefix($0, blockquote_prefix);
    
    n = lv - cp;
    while (n-- > 0) {
        if (at("blockquote")) pop();
    }
}

$0 !~ blockquote_prefix {
    pop_blockquote();
}

$0 ~ blockquote_prefix {

    lv = level_blockquote();
    cp = count_prefix($0, blockquote_prefix);
    
    $0 = remove_prefix($0, blockquote_prefix);
    
    if (cp > lv) {
        n = cp - lv;
        while (n-- > 0) {
            pop_p();
            push("blockquote");
        }
    } else {
        n = lv - cp;
        while (n-- > 0) {
            pop();
        }
    }
    
    if ($0 ~ /^$/) {
        pop_until("blockquote");
    }
}

#===========================================
# LIST ITENS
#===========================================

# TODO: add more POSIX compatibility as MAWK doesn't support regex quantifiers {x,y}
# See: https://unix.stackexchange.com/questions/506119/how-to-specify-regex-quantifiers-with-mawk

function pop_p() {
    if (!ready()) pop();
}

function pop_list () {

    if (!at("li")) return;

    lv = level_list();
    cp = count_indent($0);
    
    n = lv - cp;
    while (n-- > 0) {
        if (stk[idx-1] == "li") pop();
        if (at("li")) pop();
        if (at("ol") || at("ul")) pop();
    }
}

function remove_list_indent (line) {

    n = level_list();
    while (n > 0) {
        sub(/^[ ][ ][ ][ ]/, "", line);
        n--;
    }
    
    return line;
}

$0 !~ ul_prefix && $0 !~ ol_prefix {

    temp = remove_list_indent($0);
    
    if (blank > 0) {
        pop_list();
    }
    
    $0 = temp;
}

function list_start(line) {
    sub("^[ ]+", "", line);
    match(line, "^[0-9]+");
    return substr(line, RSTART, RLENGTH);
}

function push_li(tag, start) {

    if (tag == "ol") {
        if (start == "") {
            if (!at("ul") && !at("ol")) push(tag);
        } else {
            if (!at("ul") && !at("ol")) push(tag, "start='" start "'");
        }
    } else {
        if (!at("ul") && !at("ol")) push(tag);
    }
    
    push("li");
}

function parse_list_item(tag, pref, start) {
    
    lv = level_list();
    cp = count_indent($0) + 1;
    
    $0 = remove_prefix($0, pref);

    if (cp == lv) {
    
        pop_p();
        if (at("li")) pop();
        push_li(tag);
        append($0);
        
    } else if (cp > lv) {
        
        # add levels
        n = (cp - 1) - lv;
        while (n-- > 0) {
            push_li(tag);
        }
        
        push_li(tag, start);
        append($0);
        
    } else if (cp < lv) {
    
        # del levels
        n = lv - cp;
        while (n-- > 0) {
            pop_p();
            if (at("li")) pop();
            if (at("ol") || at("ul")) pop();
        }
        
        if (at("li")) pop();
        push_li(tag);
        append($0);
    }
}

$0 ~ ul_prefix {
    parse_list_item("ul", ul_prefix);
    next;
}

$0 ~ ol_prefix {

    # the user specifies
    # the starting number
    start = list_start($0);

    parse_list_item("ol", ol_prefix, start);
    next;
}

#===========================================
# CODE BLOCKS
#===========================================

/^```/ {

    if (!at("code")) {
    
        sub(/^`+/, "");
        title = $0;
        
        push("code", "title='" title "'");
        next;
    }
    
    pop();
    next;
}

at("code") {
    append($0);
    next;
}

/^[ ][ ][ ][ ]/ {

    if (!at("pre")) {
        push("pre");
    }

    sub("^[ ][ ][ ][ ]", "", $0);
    append($0);
    next;
}

#===========================================
# HEADING
#===========================================

# undo last push
function undo(    tmp) {
    tmp = buf;
    buf = "";
    unpush();
    return tmp;
}

/^===+/ && at("p") {

    # <h1>
    $0 = undo();
    push("h1");
    append($0);
    pop_p();
    next;
}

/^---+/ && at("p") {

    # <h2>
    $0 = undo();
    push("h2");
    append($0);
    pop_p();
    next;
}

/^[\x23]+[ ]+/ {
    
    # count hashes
    match($0, "\x23+")
    n = RLENGTH > 6 ? 6 : RLENGTH
    
    # remove leading hashes
    $0 = substr($0, n + 1);

    pop_p();
    push("h" n);
    append($0);
    next;
}

#===========================================
# HORIZONTAL RULER
#===========================================

/^[*_-][*_-][*_-]+[ ]*$/ {
    pop_p();
    push("hr");
    next;
}

#===========================================
# DEFINITION LIST
#===========================================

# TODO: make definition list multi-level like <li>

/^:/ {

    dd = substr($0, 2);
    
    if (at("p")) {
        dt = undo();
        push("dl");
        push("dt");
        append(dt);
        pop_p();
        push("dd");
        append(dd);
        next;
    }
    if (at("dd")) {
        pop_p();
        push("dd");
        append(dd);
        next;
    }
}

#===========================================
# TABLE
#===========================================

function set_table_aligns(line,    arr, regex, found, l, r, n) {

    delete table_aligns;
    regex = "(:--[-]+:|:--[-]+|--[-]+:)";

    delete arr; # starts from 2
    n = split(line, arr, /\|/);
    for(i = 2; i < n; i++) {
    
        if (match(arr[i], regex) > 0) {
        
            found = substr(arr[i], RSTART, RLENGTH);
            
            l = substr(found, 1, 1);
            r = substr(found, RLENGTH, 1);
            
            if (l == ":" && r == ":") {
                table_aligns[i] = "center";
            } else if (l == ":" && r == "-") {
                table_aligns[i] = "left";
            } else if (l == "-" && r == ":") {
                table_aligns[i] = "right";
            } else {
                table_aligns[i] = "l:" l " r: " r;
            }
        }
    }
}

/^[ ]*\|.*\|[ ]*/ {
    
    if (!at("table")) {
    
        push("table");
        push("tr");
        
        delete arr; # starts from 2
        n = split($0, arr, /\|/);
        for(i = 2; i < n; i++) {
            push("th");
            append(arr[i]);
            pop();
        }
        pop();
        next;
    }
    
    if (at("table")) {
    
        if ($0 ~ /^[ ]*\|[ ]*([:]?--[-]+[:]?)[ ]*\|[ ]*/) {
            set_table_aligns($0);
            next;
        }
    
        push("tr");
        
        delete arr; # starts from 2
        n = split($0, arr, /\|/);
        for(i = 2; i < n; i++) {
        
            if (table_aligns[i] != "") {
                push("td", "style='text-align:" table_aligns[i] ";'");
            } else {
                push("td");
            }
            append(arr[i]);
            pop();
            
        }
        pop();
        next;
    }
}

#===========================================
# FOOTNOTE
#===========================================

function push_footnote(ref, text) {
    footnote_count++
    footnote_ref[footnote_count] = ref;
    footnote_text[footnote_count] = styles(text);
}

/^[ ]*\[\^[^]]+\][:]/ {

    # [^id]: note
    if (match($0, /\[\^[^]]+\][:]/) > 0) {
        
        ref = substr($0, RSTART + 2, RLENGTH - 4);
        text = substr($0, RSTART + RLENGTH);
        
        push_footnote(ref, text);
    }
    next;
}

#===========================================
# (REFERENCE STYLE) LINK
#===========================================

# TODO: implement all styles: https://gist.github.com/emedinaa/28ed71b450243aba48accd634679f805

function push_link(ref, href, title, text) {
    link_count++;
    link_ref[link_count] = ref;
    link_href[link_count] = href;
    link_title[link_count] = title;
    link_text[link_count] = text;
}

/^[ ]*\[[^]]+\][:]/ {

    # [ref]: href
    # [ref]: href "title"
    # [ref]: href 'title'
    # [ref]: href (title)
    # [ref]: <href> "title"
    # [ref]: <href> 'title'
    # [ref]: <href> (title)
    if (match($0, /\[[^]]+\][:]/) > 0) {
        
        ref = substr($0, RSTART + 1, RLENGTH - 3);
        href = substr($0, RSTART + RLENGTH);
        
        if (match(href, "[ ](\"[^\"]*\"|'[^']*'|\\([^\\)]*\\))") > 0) {
            title = substr(href, RSTART + 2, RLENGTH - 3);
            href = substr(href, 1, RSTART - 1)
            
            # remove '<' '>'.
            if (match(href, "<[^>]+>") > 0) {
                href = substr(href, RSTART + 1, RLENGTH - 2);
            }
        }
        
        # remove leading spaces
        sub("^[ ]*", "", href);
        
        push_link(ref, href, title, title);
    }
    next;
}

#===========================================
# PARAGRAPH
#===========================================

# TODO: transform "<li>text" in "<li><p>text", undoing the previous <li>

/^.+$/ {
    if (ready()) {
        if (at("li")) {
            if (blank == 1) {
                push("p");
            }
        } else {
            push("p");
        }
    }
    
    append($0);
    next;
}

#===========================================
# THE END
#===========================================

END {

    pop_p();
    pop_list();
    pop_blockquote();
    
    print_footer();
}

