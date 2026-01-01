#!/usr/bin/awk -f

# Note:
#   * Files encoded using MAC-UTF-8 must be normalized to UTF-8.

function token_type(token)
{
    return toascii(tolower(token));
}

function token_format(token)
{
    if (token ~ /^[[:alpha:]]+([\x27’-]?[[:alpha:]])*$/) {
        return "W"; # Word format: all-letter token with optional hyphens
    } else if (token ~ /^[+-]?([[:digit:]][h°%/:,.+-]?)+$/) {
        return "N"; # Number format: all-letter token with some optional puncts
    } else if (token ~ /^[[:punct:]]+$/) {
        return "P"; # Punct format: all-punct token
    } else {
        return "NA"; # None of the above
    }
    
    # NOTE:
    # This function returns NA to words that contain "accented" characters encoded
    # with MAC-UTF-8. You must normilize the input files to regular UTF-8 encoding.
}

function token_case(token)
{
    token = toascii(token);

    if (token ~ /^[[:upper:]][[:lower:]]*([\x27’-]([[:alpha:]][[:lower:]]*))*$/) {
        return "S"; # Start case: "Word", "Compound-word"
    } else if (token ~ /^[[:lower:]]+([\x27’-]([[:lower:]]+))*$/) {
        return "L"; # Lower case: "word", "compound-word"
    } else if (token ~ /^[[:upper:]]+([\x27’-]([[:upper:]]+))*$/) {
        return "U"; # Upper case: "WORD", "COMPOUND-WORD"
    } else if (token ~ /^[[:alpha:]][[:lower:]]*([[:upper:]][[:lower:]]+)+$/) {
        return "C"; # Camel case: "compoundWord", "CompoundWord"
    } else if (token ~ /^[[:alpha:]]+([\x27’-]([[:alpha:]]+))*$/) {
        return "M"; # Mixed case: "wOrD", "cOmPoUnD-wOrD"
    } else {
        return "NA"; # None of the above
    }

    # NOTE:
    # UPPERCASE words with a single character, for example "É", are treated as start case words by this function.
    # The author considers it a very convenient behavior that helps to identify proper nouns and the beginning of
    # sentences, although he admits that it may not be intuitive. The order of the `if`s is important to preserve
    # this behavior.
}

function token_mask(token)
{
    if (token ~ /^[+-]?[0-9]+$/) {
        return "I"; # Integer mask
    } else if (token ~ /^[+-]?[0-9][0-9]?[0-9]?([,.]?[0-9][0-9][0-9])*([,.][0-9]+)?$/) {
        return "R"; # Real number
    } else if (token ~ /^[0-9]([0-9]|[0-9][0-9][0-9])[/.-][0-9][0-9]?[/.-][0-9]([0-9]|[0-9][0-9][0-9])$/) {
        return "D"; # Date mask
    } else if (token ~ /^([0-9][0-9]?[:h][0-9][0-9]|[0-9][0-9]?[h])$/) {
        return "T"; # Time mask
    } else if (token ~ /^[+-]?[0-9]+[/][0-9]+$/) {
        return "F"; # Fraction mask
    } else if (token ~ /^[+-]?[0-9]+([,.][0-9]+)?%$/) {
        return "P"; # Percent mask
    } else if (token ~ /^[+-]?[0-9]+([,.][0-9]+)?°$/) {
        return "G"; # Degrees mask
    } else {
        return "NA"; # None of the above
    }
}

function insert_token(token)
{
    idx++;
    tokens[idx]=token;
    counters[token]++;

    if (!types[token]) types[token] = token_type(token);
    if (!formats[token]) formats[token] = token_format(token);
    if (!cases[token]) cases[token] = token_case(token);
    if (!masks[token]) masks[token] = token_mask(token);

    if (!indexes[token]) indexes[token] = idx;
    else indexes[token] = indexes[token] "," idx;
}

function toascii(string) {

    # Unicode Latin-1 Supplement
    gsub(/[ÀÁÂÃÄÅ]/,"A", string);
    gsub(/[ÈÉÊË]/,"E", string);
    gsub(/[ÌÍÎÏ]/,"I", string);
    gsub(/[ÒÓÔÕÖ]/,"O", string);
    gsub(/[ÙÚÛÜ]/,"U", string);
    gsub(/Ý/,"Y", string);
    gsub(/Ç/,"C", string);
    gsub(/Ñ/,"N", string);
    gsub(/Ð/,"D", string);
    gsub(/Ø/,"OE", string);
    gsub(/Þ/,"TH", string);
    gsub(/Æ/,"AE", string);
    gsub(/[àáâãäåª]/,"a", string);
    gsub(/[èéêë]/,"e", string);
    gsub(/[ìíîï]/,"i", string);
    gsub(/[òóôõöº°]/,"o", string);
    gsub(/[ùúûü]/,"u", string);
    gsub(/[ýÿ]/,"y", string);
    gsub(/ç/,"c", string);
    gsub(/ñ/,"n", string);
    gsub(/ð/,"d", string);
    gsub(/ø/,"oe", string);
    gsub(/þ/,"th", string);
    gsub(/ae/,"ae", string);
    gsub(/ß/,"ss", string);

    # Unicode Punctuation
    gsub(/–/,"-", string);
    gsub(/—/,"--", string);
    gsub(/…/,"...", string);
    gsub(/[‘’]/,"\x27", string);
    gsub(/[“”«»]/,"\x22", string);

    # Remove MAC-UTF-8 combining diacritical marks (only those used in Latin-1)
    gsub(/[\xCC\x80\xCC\x81\xCC\x82\xCC\x83\xCC\x88\xCC\x8A\xCC\xA7]/,"", string);

    # Replace non-ASCII with SUB (0x1A)
    gsub(/[^\x00-\x7E]/,"\x1A", string);

    return string;
}

function get_stopwords_regex(    file, regex, line) {

    if (!option_value("stopwords")) {
        return /^$/;
    }

    file=pwd "/../lib/lang/" lang "/stopwords.txt"
   
    regex=""
    while((getline line < file) > 0) {

        # skip line started with #
        if (line ~ /^[[:space:]]*$/ || line ~ /^#/) continue;

        regex=regex "|" line;
    }

    # remove leading pipe
    regex=substr(regex,2);

    return "^(" regex ")$"
}

# separates tokens by spaces
function separate_tokens() {
    $0=" " $0 " ";
    gsub(/\xA0/, " ");
    gsub(/[]()—{}[]/, " & ");
    gsub(/[.,;:!?…][[:space:][:punct:]]/, " &");
    gsub(/[[:space:][:punct:]][\x22\x27“”‘’«»]/, "& ");
    gsub(/[\x22\x27“”‘’«»][[:space:][:punct:]]/, " &");
}

# 123 456 789,01 -> 123456789,01
function join_numbers(    number) {
    while (match($0, /[[:space:][:punct:]][0-9]+[[:space:]][0-9][0-9][0-9][[:space:][:punct:]]/)) {
        number = substr($0, RSTART + 1, RLENGTH - 2);
        sub(/[[:space:]]/, "", number);
        $0 = substr($0, 0, RSTART) number substr($0, RSTART + RLENGTH - 1);
    }
}

function generate_records(    token, count, ratio, sum, sep, r, f, flength, key, val)
{
    # start of operational checks #
    sum=0
    for (token in counters) {
        sum += counters[token];
    }    
    if (sum != length(tokens)) {
        print "Wrong sum of counts" > "/dev/stderr";
        exit 1;
    }
    # end of operational checks #
 
    r=0
    for (token in counters) {

    	r++;
        sep = ""
        flength = fields[0];
        count = counters[token];
        ratio = count / length(tokens);

        for (f = 1; f <= flength; f++) {
                key = fields[f,"key"];
                val = fields[f,"value"];
                if (val == 0) continue;
                if (key == "token")  {
                    records[r,"token"] = token;
                } else if (key == "type")  {
                    records[r,"type"] = types[token];
                } else if (key == "count")  {
                    records[r,"count"] = count;
                } else if (key == "ratio")  {
                    records[r,"ratio"] = ratio;
                } else if (key == "format")  {
                    records[r,"format"] = formats[token];
                } else if (key == "case")  {
                    records[r,"case"] = cases[token];
                } else if (key == "mask")  {
                    records[r,"mask"] = masks[token];
                } else if (key == "length")  {
                    records[r,"length"] = length(token);
                } else if (key == "indexes")  {
                    records[r,"indexes"] = indexes[token];
                } else {
                    continue;
                }
            sep="\t"
        }
    }
    
    # array length
    records[0] = r;
}

function print_records(    sep, r, f, rlength, flength)
{
    flength = fields[0];
    rlength = records[0];
    
    if (length(records)) {
        sep = ""
        for (f = 1; f <= flength; f++) {
            if (fields[f,"value"] == 0) continue;
            printf "%s%s", sep, toupper(fields[f,"key"]) > output;
            sep = "\t"
        }
        printf "\n" > output;
        for (r = 1; r <= rlength; r++) {
            sep = ""
            for (f = 1; f <= flength; f++) {
                if (fields[f,"value"] == 0) continue;
    	    	printf "%s%s", sep, records[r,fields[f,"key"]] > output;
    		    sep = "\t"
    	    }
            printf "\n" > output;
        }
    }
}

function basename(file) {
    sub("^.*/", "", file)
    return file
}

function basedir(file) {
    sub("/[^/]+$", "", file)
    return file
}

function parse_confs(    file, line, string)
{
    file=pwd "/../abw.conf"
   
    string=""
    while((getline line < file) > 0) {

        # skip comments 
        gsub(/#.*$/,"", line);

        # skip invalid lines
        if (line !~ /^[[:space:]]*[[:alnum:]]+[[:space:]]*=[[:space:]]*[[:alnum:]]+[[:space:]]*$/) continue;
        if (!string) string = line;
        else string=string "," line;
    }

    fields[0] = 0; # declare array
    parse_fields(FIELDS, fields);
    if (length(fields) == 0) {
        parse_fields(string, fields);
    }

    options[0] = 0; # declare array
    parse_options(OPTIONS, options);
    if (length(options) == 0) {
        parse_options(string, options);
   }
}

function parse_fields(string, fields,    default_string)
{
    gsub(":","=",string);
    default_string="token,type,count,ratio,format,case,mask,length,indexes";
    if (!string) string = default_string;
    parse_key_values(string, fields, default_string);
}

function parse_options(string, options,    default_string)
{
    gsub(":","=",string);
    default_string="ascii=0,lower=0,upper=0,stopwords=1,lang=none,eol=1,asc=none,desc=none";
    if (!string) string = default_string;
    parse_key_values(string, options, default_string); 
}

# Option formats: 'key' or 'key:value'
# If the format is 'key', name is 'key' and value is '1'
# If the format is 'key:value', name is 'key' and value is 'value'
function parse_key_values(string, keyvalues,     default_string, items, i, key, value, splitter)
{
    split(string, items, ",");
    for (i in items)
    {
        gsub(/=.*$/, "", items[i]);
        if (default_string !~ "\\<" items[i] "\\>") {
            gsub("\\<" items[i] "\\>(=[^,]*)?", "", string);
        }
    }

    gsub(",+", ",", string);
    gsub("^,|,$", "", string);

    split(string, items, ",");
    for (i in items)
    {
        if (items[i] !~ "=" ) {
            key = items[i];
            value = 1;
        } else {
            splitter = index(items[i], "=");
            key = substr(items[i], 0, splitter - 1);
            value = substr(items[i], splitter + 1);
        }
        keyvalues[i,"key"] = key;
        keyvalues[i,"value"] = value;
    }
    
    # save the array length
    keyvalues[0] = length(items);
}

function get_sort_order(    sort_order, o, olength, key)
{
    olength = options[0];
    for (o = 1; o <= olength; o++) {
        key = options[o,"key"];
        if (key == "asc") {
            if (options[o,"value"] == "token") sort_order = "@ind_str_asc";
            if (options[o,"value"] == "count") sort_order = "@val_num_asc";
        } else if (key == "desc") {
            if (options[o,"value"] == "token") sort_order = "@ind_str_desc";
            if (options[o,"value"] == "count") sort_order = "@val_num_desc";
        } else {
            continue;
        }
    }
    return sort_order;
}

function remove_stopwords(    i)
{
    for (i = 1; i <= NF; i++) {
        if (tolower($i) ~ tolower(stopwords_regex)) $i = "";
    }
}

function transform_line(    o, olength, key)
{
    olength = options[0];
    for (o = 1; o <= olength; o++) {
        key = options[o,"key"];
        if (key == "ascii") {
            if (options[o,"value"] == 1) $0 = toascii($0);
        } else if (key == "lower") {
            if (options[o,"value"] == 1) $0 = tolower($0);
        } else if (key == "upper") {
            if (options[o,"value"] == 1) $0 = toupper($0);
        } else if (key == "stopwords") {
            if (options[o,"value"] == 0) remove_stopwords();
        } else {
            continue;
        }
    }
}

function option_value(key,    o, olength) {
    olength = options[0];
    for (o = 1; o <= olength; o++) {
        if (options[o,"key"] == key) return options[o,"value"];
    }
    return 0;
}

BEGIN {

    pwd = PWD;
    parse_confs();

    eol = option_value("eol");
    lang = option_value("lang");

    sort_order = get_sort_order();
    stopwords_regex = get_stopwords_regex();
}

function endfile() {
    output=WRITETO;
    filedir=basedir(FILENAME)
    filename=basename(FILENAME)
    sub(/:filedir/, filedir, output);
    sub(/:filename/, filename, output);
 
    generate_records();
    print_records();

    idx = 0;
    delete tokens;
    delete types;
    delete counters;
    delete formats;
    delete cases;
    delete masks;
    delete indexes;
    delete records;
}

FNR == 1 && (NR > 1) {
    endfile();
}

NF {

    join_numbers();
    transform_line();
    separate_tokens();

    for (i = 1; i <= NF; i++) {
        insert_token($i);
    }

    if (eol) insert_token("<eol>");
}

END {
    endfile();
}
