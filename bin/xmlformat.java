///usr/bin/env jbang "$0" "$@" ; exit $?
//DEPS commons-cli:commons-cli:1.4

//  xmlformat - configurable XML file formatter/pretty-printer

//  Copyright (c) 2004, 2005 Kitebird, LLC.  All rights reserved.
//  Some portions are based on the REX shallow XML parser, which
//  is Copyright (c) 1998, Robert D. Cameron. These include the
//  regular expression parsing variables and the shallow_parse()
//  method.
//  This software is licensed as described in the file LICENSE,
//  which you should have received as part of this distribution.

//  Syntax: xmlformat [config-file] xml-file

//  Default config file is $ENV{XMLFORMAT_CONF} or ./xmlformat.conf, in that
//  order.

//  Paul DuBois
//  paul@kitebird.com
//  2003-12-14

//  The input document first is parsed into a list of strings.  Each string
//  represents one of the following:
//  - text node
//  - processing instruction (the XML declaration is treated as a PI)
//  - comment
//  - CDATA section
//  - DOCTYPE declaration
//  - element tag (either <abc>, </abc>, or <abc/>), *including attributes*

//  Entities are left untouched. They appear in their original form as part
//  of the text node in which they occur.

//  The list of strings then is converted to a hierarchical structure.
//  The document top level is represented by a reference to a list.
//  Each list element is a reference to a node -- a hash that has "type"
//  and "content" key/value pairs. The "type" key indicates the node
//  type and has one of the following values:

//  "text"    - text node
//  "pi"      - processing instruction node
//  "comment" - comment node
//  "CDATA"   - CDATA section node
//  "DOCTYPE" - DOCTYPE node
//  "elt"     - element node

//  (For purposes of this program, it's really only necessary to have "text",
//  "elt", and "other".  The types other than "text" and "elt" currently are
//  all treated the same way.)

//  For all but element nodes, the "content" value is the text of the node.

//  For element nodes, the "content" hash is a reference to a list of
//  nodes for the element's children. In addition, an element node has
//  three additional key/value pairs:
//  - The "name" value is the tag name within the opening tag, minus angle
//    brackets or attributes.
//  - The "open_tag" value is the full opening tag, which may also be the
//    closing tag.
//  - The "close_tag" value depends on the opening tag.  If the open tag is
//    "<abc>", the close tag is "</abc>". If the open tag is "<abc/>", the
//    close tag is the empty string.

//  If the tree structure is converted back into a string with
//  tree_stringify(), the result can be compared to the input file
//  as a regression test. The string should be identical to the original
//  input document.

import gnu.getopt.Getopt;
import gnu.getopt.LongOpt;
import org.apache.commons.cli.*;

import static java.lang.System.*;

import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.function.Function;
import java.util.regex.*;
import java.util.stream.Collectors;

public class xmlformat {
    static String PROG_NAME = "xmlformat";
    static String PROG_VERSION = "1.04";
    static String PROG_LANG = "java";

    // ----------------------------------------------------------------------

    static void warn(String... args){
        System.err.println(args);
    }

    static void die(String... args){
        System.err.println(args);
        System.exit(1);
    }

    // ----------------------------------------------------------------------

    // Module variables - these do not vary per class invocation

    // Regular expressions for parsing document components. Based on REX.

    // Compared to Perl version, these variable names use more Ruby-like
    // lettercase. (Ruby likes to interpret variables that begin with
    // uppercase as constants.)

    // spe = shallow parsing expression
    // se = scanning expression
    // ce = completion expression
    // rsb = right square brackets
    // qm = question mark

    String _text_se = "[^<]+";
    String _until_hyphen = "[^-]*-";
    String _until_2_hyphens = ""+_until_hyphen+"(?:[^-]"+_until_hyphen+")*-";
    String _comment_ce = ""+_until_2_hyphens+">?";
    String _until_rsbs = "[^\\]]*\\](?:[^\\]]+\\])*\\]+";
    String _cdata_ce = ""+_until_rsbs+"(?:[^\\]>]"+_until_rsbs+")*>";
    String _s = "[ \\n\\t\\r]+";
    String _name_strt = "[A-Za-z_:]|[^\\x00-\\x7F]";
    String _name_char = "[A-Za-z0-9_:.-]|[^\\x00-\\x7F]";
    String _name = "(?:"+_name_strt+")(?:"+_name_char+")*";
    String _quote_se = "\"[^\"]*\"|'[^']*'";
    String _dt_ident_se = ""+_s+""+_name+"(?:"+_s+"(?:"+_name+"|"+_quote_se+"))*";
    String _markup_decl_ce = "(?:[^\\]\"'><]+|"+_quote_se+")*>";
    String _s1 = "[\\n\\r\\t ]";
    String _until_qms = "[^?]*\\?+";
    String _pi_tail = "\\?>|"+_s1+""+_until_qms+"(?:[^>?]"+_until_qms+")*>";
    String _dt_item_se =
        "<(?:!(?:--"+_until_2_hyphens+">|[^-]"+_markup_decl_ce+")|\\?"+_name+"(?:"+_pi_tail+"))|%"+_name+";|"+_s+"";
    String _doctype_ce =
        ""+_dt_ident_se+"(?:"+_s+")?(?:\\[(?:"+_dt_item_se+")*\\](?:"+_s+")?)?>?";
    String _decl_ce =
        "--(?:"+_comment_ce+")?|\\[CDATA\\[(?:"+_cdata_ce+")?|DOCTYPE(?:"+_doctype_ce+")?";
    String _pi_ce = ""+_name+"(?:"+_pi_tail+")?";
    String _end_tag_ce = ""+_name+"(?:"+_s+")?>?";
    String _att_val_se = "\"[^<\"]*\"|'[^<']*'";
    String _elem_tag_se =
        ""+_name+"(?:"+_s+""+_name+"(?:"+_s+")?=(?:"+_s+")?(?:"+_att_val_se+"))*(?:"+_s+")?/?>?";
    String _markup_spe =
        "<(?:!(?:"+_decl_ce+")?|\\?(?:"+_pi_ce+")?|/(?:"+_end_tag_ce+")?|(?:"+_elem_tag_se+")?)";
    Pattern xml_spe = Pattern.compile(_text_se+"|"+_markup_spe);

    String _sentence_end = "[.?]\"?";

    // ----------------------------------------------------------------------

// Allowable formatting options and their possible values:
// - The keys of this hash are the allowable option names
// - The value for each key is list of allowable option values
// - If the value is nil, the option value must be numeric
// If any new formatting option is added to this program, it
// must be specified here, *and* a default value for it should
// be listed in the *DOCUMENT and *DEFAULT pseudo-element
// option hashes.

    static Map<OptionSetting,Object[]> _opt_list = Map.of(
        OptionSetting.format        , new String[]{ "block", "inline", "verbatim" },
        OptionSetting.normalize     , new String[]{ "yes", "no" },
        OptionSetting.subindent     , null,
        OptionSetting.wrap_length   , null,
        OptionSetting.wrap_type     , new String[]{ "length", "sentence", "none" },
        OptionSetting.entry_break   , null,
        OptionSetting.exit_break    , null,
        OptionSetting.element_break , null
    );

    static Map<String, Options> elt_opts = new HashMap<>();

    void initialize(){
        // Formatting options for each element.

        // The formatting options for the *DOCUMENT and *DEFAULT pseudo-elements can
        // be overridden in the configuration file, but the options must also be
        // built in to make sure they exist if not specified in the configuration
        // file.  Each of the structures must have a value for every option.
    
        // Options for top-level document children.
        // - Do not change entry-break: 0 ensures no extra newlines before
        //   first element of output.
        // - Do not change exit-break: 1 ensures a newline after final element
        //   of output document.
        // - It's probably best not to change any of the others, except perhaps
        //   if you want to increase the element-break.
    
        elt_opts.put("*DOCUMENT", new Options(
            "block",
            false,
            0,
            WRAP_TYPE.sentence,
            0,
            0, //do not change
            1, //do not change
            1
        ));

        // Default options. These are used for any elements in the document
        // that are not specified explicitly in the configuration file.
      
        elt_opts.put("*DEFAULT", new Options(
            "block",
            false,
            1,
            WRAP_TYPE.sentence,
            0,
            1, //do not change
            1, //do not change
            1
        ));

        // Run the *DOCUMENT and *DEFAULT options through the option-checker
        // to verify that the built-in values are legal.
      
        int _err_count = 0;
        String _err_msg = "";

        for (Map.Entry<String,Options> entry: elt_opts.entrySet()){
            // Check each option for element

            //TODO


        }

        // Make sure that the every option is represented in the
        // *DOCUMENT and *DEFAULT structures.

        for (Map.Entry<String,Options> entry: elt_opts.entrySet()){
            // Check each option for element

            //TODO


        }

        if ( _err_count > 0 )
            die("Cannot continue; internal default formatting options must be fixed\n");
    }

    // Initialize the variables that are used per-document

    static Set<String> unconf_elts;
    static List<String> tokens;
    static List<Integer> line_num;
    static Deque<String> tree;
    static String out_doc;
    static List<String> pending;
    static Deque<String> block_name_stack;
    static Deque<Options> block_opts_stack;
    static Deque<String> block_break_type_stack;

    static void init_doc_vars(){
  // Elements that are used in the document but not named explicitly
  // in the configuration file.

        unconf_elts = new HashSet<>();

  // List of tokens for current document.

        tokens = new ArrayList<>();

  // List of line numbers for each token

        line_num = new ArrayList<>();

  // Document node tree (constructed from the token list).

        tree = new ArrayDeque<>();

  // Variables for formatting operations:
  // out_doc = resulting output document (constructed from document tree)
  // pending = array of pending tokens being held until flushed

        out_doc = "";
        pending = new ArrayList<>();

  // Inline elements within block elements are processed using the
  // text normalization (and possible line-wrapping) values of their
  // enclosing block. Blocks and inlines may be nested, so we maintain
  // a stack that allows the normalize/wrap-length values of the current
  // block to be determined.

        block_name_stack = new ArrayDeque<>();  // for debugging
        block_opts_stack = new ArrayDeque<>();

  // A similar stack for maintaining each block's current break type.

        block_break_type_stack = new ArrayDeque<>();

    }

    // Accessors for token list and resulting output document

//    sub tokens
//    {
//        my $self = shift;
//
//        return $self->{tokens};
//    }
//
//    sub out_doc
//    {
//        my $self = shift;
//
//        return $self->{out_doc};
//    }

    // Methods for adding strings to output document or
    // to the pending output array

    void add_to_doc(String str)
    {
        out_doc = out_doc.concat(str);
    }

    void add_to_pending(String str)
    {
        pending.add(str);
    }


    // Block stack mainenance methods

    // Push options onto or pop options off from the stack.  When doing
    // this, also push or pop an element onto the break-level stack.

    void begin_block(String name, Options opts)
    {
        block_name_stack.push(name);
        block_opts_stack.push(opts);
        block_break_type_stack.push("entry-break");
    }

    void end_block()
    {
        block_name_stack.pop();
        block_opts_stack.pop();
        block_break_type_stack.pop();
    }

    // Return the current block's normalization status or wrap length

    boolean block_normalize()
    {
        var opts = block_opts_stack.peek();
        return (boolean) opts.get(OptionSetting.normalize);
    }

    int block_wrap_length()
    {
        var opts = block_opts_stack.peek();
        return (int) opts.get(OptionSetting.wrap_length);
    }

    WRAP_TYPE block_wrap_type()
    {
        var opts = block_opts_stack.peek();
        return (WRAP_TYPE) opts.get(OptionSetting.wrap_type);
    }



    // Set the current block's break type, or return the number of newlines
    // for the block's break type

    void set_block_break_type(String type)
    {
        block_break_type_stack.push(type);
    }

    int block_break_value()
    {
        var opts = block_opts_stack.peek();
        var type = block_break_type_stack.peek();
        switch (type) {
            case "entry-break":
                return (int) opts.get(OptionSetting.entry_break);
            case "element-break":
                return (int) opts.get(OptionSetting.element_break);
            case "exit-break":
                return (int) opts.get(OptionSetting.exit_break);
        }
        return 0;
    }
// ----------------------------------------------------------------------

        // Read configuration information.  For each element, construct a hash
// containing a hash key and value for each option name and value.
// After reading the file, fill in missing option values for
            // incomplete option structures using the *DEFAULT options.

    void read_config(String conf_file) throws IOException {
        String[] elt_names = null;
        boolean in_continuation = false;
        String saved_line = "";

        final List<String> lines = Files.readAllLines(Path.of(conf_file));
        for (String line : lines) {
            // line.chomp!
            if (line.matches("^\\s*($|#)")) // skip blank lines, comments
                continue;
            ;
            if (in_continuation) {
                line = saved_line + " " + line;
                saved_line = "";
                in_continuation = false;
            }
            if (!line.matches("^\\s")) {
                // Line doesn't begin with whitespace, so it lists element names.
                // Names are separated by whitespace or commas, possibly followed
                // by a continuation character or comment.
                if (line.matches("\\\\$")) {
                    in_continuation = true;
                    saved_line = line.replaceAll("\\\\$", "");  // remove continuation character
                    continue;
                }
                line = line.replaceAll("\\s*#.*$", "");           // remove any trailing comment
                elt_names = line.split("[\\s,]+");
                // make sure each name has an entry in the elt_opts structure
                for (String elt_name : elt_names)
                    elt_opts.putIfAbsent(elt_name, new Options());
                ; // TODO: Options values?
            } else {
                // Line begins with whitespace, so it contains an option
                // to apply to the current element list, possibly followed by
                // a comment.First check that there is a current list.
                // Then parse the option name / value.

                if (elt_names == null) {
                    die(conf_file + ":" + line + ": Option setting found before any " +
                            "elements were named.\n");
                }

                line = line.replaceAll("\\s *#.*$", "");    // remove any trailing comment
                Pattern opt_setting_pattern = Pattern.compile("^\\s*(\\S+)(?:\\s+|\\s*=\\s*)(\\S+)$");
                Matcher matcher = opt_setting_pattern.matcher(line);
                var opt_name = matcher.group(1);
                var opt_val = matcher.group(2);
                if (opt_val == null)
                    die(conf_file + ":" + line + ": Malformed line");

                // Check option.If illegal, die with message.Otherwise,
                // add option to each element in current element list
                final OptionSetting optionSetting = OptionSetting.valueOf(opt_name);
                var opt_val_obj = check_option(optionSetting, opt_val);
                for (String elt_name : elt_names) {
                    elt_opts.get(elt_name).put(optionSetting, opt_val_obj);
                }
            }

            // For any element that has missing option values, fill in the values
            // using the options for the *DEFAULT pseudo-element.  This speeds up
            // element option lookups later.  It also makes it unnecessary to test
            // each option to see if it's defined: All element option structures
            // will have every option defined.

            var def_opts = elt_opts.get("*DEFAULT");

            for (String elt_name : elt_opts.keySet()) {
                if (elt_name == "*DEFAULT")
                    continue;
                for (OptionSetting optionSetting : def_opts.keySet()) {
                    if (elt_opts.get(elt_name).containsKey(optionSetting)) {
                        continue; // already set
                    }
                    elt_opts.get(elt_name).put(optionSetting, def_opts.get(optionSetting));
                }
            }
        }
    }


  // Check option name to make sure it's legal. Check the value to make sure
            // that it's legal for the name.  Return a two-element array:
            // (value, nil) if the option name and value are legal.
  // (nil, message) if an error was found; message contains error message.
            // For legal values, the returned value should be assigned to the option,
            // because it may get type-converted here.

    Object check_option(OptionSetting optionSetting, String opt_val) {

        // - Check option name to make sure it's a legal option
        var opt_val_parsed = optionSetting.checkOptionSetting(opt_val);

        // - Then check the value.  If there is a list of values
        //   the value must be one of them.
        var allowable_val = _opt_list.get(optionSetting);
        if (allowable_val!=null) {
            if (!Arrays.asList(allowable_val).contains(opt_val_parsed)) {
                die("Unknown '" + optionSetting.name() + "' value: " + opt_val);
            }
        }
        return optionSetting.checkOptionSetting(opt_val);
    }



    // Return hash of option values for a given element.  If no options are found:
    // - Add the element name to the list of unconfigured options.
    // - Assign the default options to the element.  (This way the test for the
    //   option fails only once.)

    Options get_opts(String elt_name) {
        Options opts = elt_opts.get(elt_name);
        if (opts==null) {
            unconf_elts.add(elt_name);
            opts = elt_opts.get("*DEFAULT");
            elt_opts.put(elt_name, opts);
        }
        return opts;
    }

  // Display contents of configuration options to be used to process document.
  // For each element named in the elt_opts structure, display its format
  // type, and those options that apply to the type.

    void display_config() {
        for (String elt_name : new TreeSet<>(elt_opts.keySet())) {
            out.println(elt_name);
            var elt_opt = elt_opts.get(elt_name);
            for (var setting : elt_opt.entrySet()) {
                var opt_name = setting.getKey().name();
                var opt_value = setting.getValue().toString();
                out.println("  " + opt_name + " = " + opt_value);
            }
        }
    }

  // Display the list of elements that are used in the document but not
  // configured in the configuration file.

  // Then re-unconfigure the elements so that they won't be considered
  // as configured for the next document, if there is one.

    void display_unconfigured_elements() {
            if (unconf_elts.isEmpty())
                out.println("The document contains no unconfigured elements.");
            else {
                out.println("The following document elements were assigned no formatting options:");
                out.println(unconf_elts.stream().collect(Collectors.joining(" "))); //TODO: Line wrap
            }

            unconf_elts.forEach(elt_opts::remove);
        }

  // ----------------------------------------------------------------------

    // Main document processing routine.
    // - Argument is a string representing an input document
    // - Return value is the reformatted document, or nil. An nil return
    //   signifies either that an error occurred, or that some option was
    //   given that suppresses document output. In either case, don't write
    //   any output for the document.  Any error messages will already have
    //   been printed when this returns.

    String process_doc(String doc, boolean verbose, boolean check_parser,
                            boolean canonize_only, boolean show_unconf_elts,
                       int indent) {
        init_doc_vars();

        // Perform lexical parse to split document into list of tokens
        if (verbose) warn("Parsing document...\n");
        shallow_parse(doc);

        if (check_parser) {
            if (verbose) warn("Checking parser...\n");
            // concatentation of tokens should be identical to original document
            if (doc.equals(tokens.stream().collect(Collectors.joining("")))) {
                out.println("Parser is okay");
            } else {
                out.println("PARSER ERROR: document token concatenation differs from document");
            }
            return null;
        }

        // Assign input line number to each token
        assign_line_numbers();

        // Look for and report any error tokens returned by parser
        if (verbose) warn("Checking document for errors...\n");
        if (report_errors() > 0) {
            warn("Cannot continue processing document.\n");
            return null;
        }

        // Convert the token list to a tree structure
        if (verbose) warn("Convert document tokens to tree...\n");
        if (tokens_to_tree() > 0) {
            warn("Cannot continue processing document.\n");
            return null;
        }

        // Check: Stringify the tree to convert it back to a single string,
        // then compare to original document string (should be identical)
        // (This is an integrity check on the validity of the to-tree and stringify
        // operations; if one or both do not work properly, a mismatch should occur.)
        //    var str = tree_stringify();
        //    out.println(str);
        //    if (!doc.equals(str)) warn ("ERROR: mismatch between document and resulting string\n");

        // Canonize tree to remove extraneous whitespace
        if (verbose) warn("Canonizing document tree...\n");
        tree_canonize(indent);

        if (canonize_only) {
            out.println(tree_stringify());
            return null;
        }

        // One side-effect of canonizing the tree is that the formatting
        // options are looked up for each element in the document.  That
        // causes the list of elements that have no explicit configuration
        // to be built.  Display the list and return if user requested it.

        if (show_unconf_elts) {
            display_unconfigured_elements();
            return null;
        }

        // Format the tree to produce formatted XML as a single string
        if (verbose) warn("Formatting document tree...\n");
        tree_format();

        // If the document is not empty, add a newline and emit a warning if
        // reformatting failed to add a trailing newline.  This shouldn't
        // happen if the *DOCUMENT options are set up with exit-break = 1,
        // which is the reason for the warning rather than just silently
        // adding the newline.

        var str = out_doc;
        if (!str.isEmpty() && !str.matches("\\n\\z")) {
            warn("LOGIC ERROR: trailing newline had to be added\n");
            str = str.concat("\n");
        }

        return str;
    }

  // ----------------------------------------------------------------------

  // Parse XML document into array of tokens and store array

    void shallow_parse(String xml_document) {
        tokens = xml_spe.matcher(xml_document)
                .results().map(mr->mr.group())
                .collect(Collectors.toList());
    }
    
  // ----------------------------------------------------------------------

  // Extract a tag name from a tag and return it. This uses a subset
  // of the document-parsing pattern elements.

  // Dies if the tag cannot be found, because this is supposed to be
  // called only with a legal tag.

    String extract_tag_name(String tag){
        final Matcher match = Pattern.compile("\\A<\\/?(" + _name + ")").matcher(tag);
        if (match.matches()) return match.group(1);
        die("Cannot find tag name in tag: " +tag);
        return null;
    }

  // ----------------------------------------------------------------------

  // Assign an input line number to each token.  The number indicates
  // the line number on which the token begins.

    void assign_line_numbers() {
        var _line_num = 1;
        line_num = new ArrayList<>();
        for(var  token: tokens) {
            line_num.add(_line_num);
            _line_num += token.lines().count();
        };
    }

  // ----------------------------------------------------------------------

    // Check token list for errors and report any that are found. Error
    // tokens are those that begin with "<" but do not end with ">".

    // Returns the error count.

    // Does not modify the original token list.

    int report_errors(){
        var err_count = 0;

        for(var i=0; i<tokens.size(); i++){
            var token = tokens.get(i);
            if (token.matches("\\A<") && !token.matches(">\\Z")) {
                warn("Malformed token at line /"+line_num.get(i)+", token "+(i+1)+": "+token+"\n");
                err_count += 1;
            }
        }

        if (err_count > 0)
            warn ("Number of errors found: "+err_count+"\n");

        return err_count;
     }
    
  // ----------------------------------------------------------------------

  // Helper routine to print tag stack for tokens_to_tree

    void print_tag_stack(String label, Collection<String> stack) {
        if (stack.size() < 1) {
            warn ("  "+label+": none\n");
        } else {
            warn ("  "+label+":\n");
            var i=0;
            for(var tag:stack)
                warn ("  "+(i++)+": "+tag+"\n");
        }
    }
    
    // Convert the list of XML document tokens to a tree representation.
    // The implementation uses a loop and a stack rather than recursion.

    // Does not modify the original token list.

    // Returns an error count.

    int tokens_to_tree(){

        var tag_stack = new ArrayDeque<String>();        // stack for element tags
        ArrayDeque<Deque<node>> children_stack = new ArrayDeque<>();   // stack for lists of children
        Deque<node> children = new ArrayDeque<node>();         // current list of children
        var err_count = 0;

        // Note: the text token pattern test assumes that all text tokens
        // are non-empty. This should be true, because REX doesn't create
        // empty tokens.

        for (var i=0; i<tokens.size(); i++) {
            var token = tokens.get(i);
            var _line_num = line_num.get(i);
            TriFunction<Integer, Integer, String, String> tok_err =
                    (line_num, token_num, _token) -> String.format("Error near line %s, token %i (%s)", line_num, token_num, _token);

            if (token.matches("\\A[^<]")) {                    // text
                children.add(new text_node(token));
            } else if (token.matches("\\A<!--")) {             // comment
                children.add(new comment_node(token));
            } else if (token.matches("\\A<\\?")) {             // processing instruction
                children.add(new pi_node(token));
            } else if (token.matches("\\A<!DOCTYPE")) {        // DOCTYPE
                children.add(new doctype_node(token));
            } else if (token.matches("\\A<!\\[")) {            // CDATA
                children.add(new cdata_node(token));
            } else if (token.matches("\\A<\\/")) {             // element close tag
                if (tag_stack.isEmpty()) {
                    warn(tok_err.apply(_line_num, i, token) + ": Close tag w/o preceding open tag; malformed document?\n");
                    err_count += 1;
                    continue;
                }
                if (children_stack.isEmpty()) {
                    warn(tok_err.apply(_line_num, i, token) + ": Empty children stack; malformed document?\n");
                    err_count += 1;
                    continue;
                }
                var tag = tag_stack.pop();
                var open_tag_name = extract_tag_name(tag);
                var close_tag_name = extract_tag_name(token);
                if (!open_tag_name.equals(close_tag_name)) {
                    warn(tok_err.apply(_line_num, i, token) + ": Tag mismatch; malformed document?\n");
                    warn("  open tag: " + tag + "\n");
                    warn("  close tag: " + token + "\n");
                    print_tag_stack("enclosing tags", tag_stack);
                    err_count += 1;
                    continue;
                }
                var elt = element_node(tag, token, children);
                children = children_stack.pop();
                children.push(elt);
            } else {                             // element open tag
            // If we reach here, we're seeing the open tag for an element:
            // - If the tag is also the close tag (e.g., <abc/>), close the
            //   element immediately, giving it an empty child list.
            // - Otherwise, push tag and child list on stacks, begin new child
            //   list for element body.
                if (token.matches("\\/>\\Z")) {     // tag is of form <abc/>
                    children.push(element_node(token, "", new ArrayDeque<>()));
                } else {             // tag is of form <abc>
                    tag_stack.push(token);
                    children_stack.push(children);
                    children = new ArrayDeque();
                }
            }
        }

        // At this point, the stacks should be empty if the document is
        // well-formed.

        if (!tag_stack.isEmpty()) {
            warn ("Error at EOF: Unclosed tags; malformed document?\n");
            print_tag_stack("unclosed tags", tag_stack);
            err_count += 1;
        }
        if (!children_stack.isEmpty()) {
            warn ("Error at EOF: Unprocessed child elements; malformed document?\n");
            // TODO: print out info about them
            err_count += 1;
        }

        tree = children;
        return err_count;
    }
    
    // Node-generating helper methods for tokens_to_tree

    // Generic node generator
    class node {
        final String type;
        String content;
        public String name;
        public String open_tag;
        public String close_tag;

        protected node(String type, String content) {
          this.type = type;
          this.content = content;
      }
    }

    // Generators for specific non-element nodes
    class text_node extends node {
      protected text_node( String content) {
          super("text", content);
      }
    }
    class comment_node extends node {
        protected comment_node( String content) {
            super("comment", content);
        }
    }
    class pi_node extends node {
        protected pi_node( String content) {
            super("pi", content);
        }
    }
    class doctype_node extends node {
        protected doctype_node( String content) {
            super("DOCTYPE", content);
        }
    }
    class cdata_node extends node {
        protected cdata_node( String content) {
            super("CDATA", content);
        }
    }

  // For an element node, create a standard node with the type and content
  // key/value pairs. Then add pairs for the "name", "open_tag", and
  // "close_tag" hash keys.

    node element_node(String open_tag, String close_tag, Deque<node> children) {
        node elt = new node("elt", children);
        // name is the open tag with angle brackets and attibutes stripped
        elt.name = extract_tag_name(open_tag);
        elt.open_tag = open_tag;
        elt.close_tag = close_tag;
        return elt;
    }

    // ----------------------------------------------------------------------

    // Convert the given XML document tree (or subtree) to string form by
    // concatentating all of its components.  Argument is a reference
    // to a list of nodes at a given level of the tree.  (If argument is
    // missing, use the top level of the tree.)

    // Does not modify the node list.
    String tree_stringify() {
        return tree_stringify(tree);
    }

    String tree_stringify(List<node> children){
        StringBuilder str = new StringBuilder();
        for(node child: children){
            // - Elements have list of child nodes as content (process recursively)
            // - All other node types have text content

            if (child.type.equals("elt")) {
                str.append(child.open_tag)
                   .append(tree_stringify(child.content.stream().toList()))
                   .append(child.close_tag);
            } else
                str.append(child.content);
        }
        return str.toString();
    }
  // ----------------------------------------------------------------------

    // Put tree in "canonical" form by eliminating extraneous whitespace
    // from element text content.

    // children is a list of child nodes

    // This function modifies the node list.

    // Canonizing occurs as follows:
    // - Comment, PI, DOCTYPE, and CDATA nodes remain untouched
    // - Verbatim elements and their descendants remain untouched
    // - Within non-normalized block elements:
    //   - Delete all-whitespace text node children
    //   - Leave other text node children untouched
    // - Within normalized block elements:
    //   - Convert runs of whitespace (including line-endings) to single spaces
    //   - Trim leading whitespace of first text node
    //   - Trim trailing whitespace of last text node
    //   - Trim whitespace that is adjacent to a verbatim or non-normalized
    //     sub-element.  (For example, if a <programlisting> is followed by
    //     more text, delete any whitespace at beginning of that text.)
    // - Within inline elements:
    //   - Normalize the same way as the enclosing block element, with the
    //     exception that a space at the beginning or end is not removed.
    //     (Otherwise, <para>three<literal> blind </literal>mice</para>
    //     would become <para>three<literal>blind</literal>mice</para>).

    void tree_canonize(int indent) {
        tree = tree_canonize2(tree, "*DOCUMENT", indent);
    }

    Deque<node> tree_canonize2(Deque<node> children, String par_name, int indent) {

        // Formatting options for parent
        var par_opts = get_opts(par_name);

        // If parent is a block element, remember its formatting options on
        // the block stack so they can be used to control canonization of
        // inline child elements.

        if (par_opts.get(OptionSetting.format) == "block") {
            begin_block(par_name, par_opts);
        }

        // Iterate through list of child nodes to preserve, modify, or
        // discard whitespace.  Return resulting list of children.

        // Canonize element and text nodes. Leave everything else (comments,
        // processing instructions, etc.) untouched.

        var new_children = new ArrayDeque<node>();

        while (!children.isEmpty()) {
            var child = children.pollLast();

            if (child.type == "elt") {

                // Leave verbatim elements untouched. For other element nodes,
                // canonize child list using options appropriate to element.

                if (get_opts(child.name).get(OptionSetting.format) != "verbatim") {
                    child.content = tree_canonize2(child.content, child.name, indent + (Integer) par_opts.get(OptionSetting.subindent));
                }

            } else if (child.type == "comment") {
                // Indent first line of the comment the same level as the sibilings
                var indent_str = " ".repeat(indent + (Integer)par_opts.get(OptionSetting.subindent));
                child.content = child.content.replaceAll("^", indent_str);

                // In multi-line comments, next lines are indented one more level
                var indent_cont_str = " ".repeat(indent + (Integer)par_opts.get(OptionSetting.subindent) * 2);
                child.content = child.content.replaceAll("\\n\\s*", indent_cont_str);

            } else if (child.type == "text") {

                // Delete all-whitespace node or strip whitespace as appropriate.

                // Paranoia check: We should never get here for verbatim elements,
                // because normalization is irrelevant for them.

                if (par_opts.get(OptionSetting.format) == "verbatim") {
                    die ("LOGIC ERROR: trying to canonize verbatim element "+par_name+"!\n");
                }

                if (!block_normalize()) {

                    // Enclosing block is not normalized:
                    // - Delete child all-whitespace text nodes.
                    // - Leave other text nodes untouched.

                    if (child.content.matches("\\A\\s*\\Z")) continue;

                } else {

                    // Enclosing block is normalized, so normalize this text node:
                    // - Convert runs of whitespace characters (including
                    //   line-endings characters) to single spaces.
                    // - Trim leading whitespace if this node is the first child
                    //   of a block element or it follows a non-normalized node.
                    // - Trim leading whitespace if this node is the last child
                    //   of a block element or it precedes a non-normalized node.

                    // These are nil if there is no prev or next child
                    var prev_child = new_children.peekLast();
                    var next_child = children.peekFirst();

                    child.content = child.content.replaceAll("\\s+"," ");
                    if ((prev_child==null && par_opts.get(OptionSetting.format) == "block") || non_normalized_node(prev_child)) {
                        child.content = child.content.replaceFirst("\\A ","");
                    }
                    if (next_child==null && par_opts.get(OptionSetting.format) == "block") || non_normalized_node(next_child)) {
                        child.content = child.content.replaceFirst(" \\Z","");
                    }

                    // If resulting text is empty, discard the node.
                    if (child.content.matches("\\A\\Z"))
                        continue;

                }
            }
            new_children.push(child);
        }

        // Pop block stack if parent was a block element
         if (par_opts.get(OptionSetting.format) == "block")
             end_block();

         return new_children;
    }

    // Helper function for tree_canonize().

    // Determine whether a node is normalized.  This is used to check
    // the node that is adjacent to a given text node (either previous
    // or following).
    // - No is node is nil
    // - No if the node is a verbatim element
    // - If the node is a block element, yes or no according to its
    //   normalize option
    // - No if the node is an inline element.  Inlines are normalized
    //   if the parent block is normalized, but this method is not called
    //   except while examinine normalized blocks. So its inline children
    //   are also normalized.
    // - No if node is a comment, PI, DOCTYPE, or CDATA section. These are
    //   treated like verbatim elements.

    boolean non_normalized_node(node node) {
        if (node==null) return false;

        switch (node.type) {
            case "elt":
                var opts = get_opts(node.name);
                switch (opts.get(OptionSetting.format).toString()) {
                    case "verbatim":
                        return true;
                    case "block":
                        return opts.get(OptionSetting.normalize) == "no";
                    case "inline":
                        return false;
                    default:
                        die("LOGIC ERROR: non_normalized_node: unhandled node format.\n");
                }
            case "comment", "pi", "DOCTYPE", "CDATA":
                return true;
            case "text":
                die("LOGIC ERROR: non_normalized_node: got called for text node.\n");
            default:
                die("LOGIC ERROR: non_normalized_node: unhandled node type.\n");
            }
        return false;
    }


  // ----------------------------------------------------------------------

    // Format (pretty-print) the document tree

    // Does not modify the node list.

    // The class maintains two variables for storing output:
    // - out_doc stores content that has been seen and "flushed".
    // - pending stores an array of strings (content of text nodes and inline
    //   element tags).  These are held until they need to be flushed, at
    //   which point they are concatenated and possibly wrapped/indented.
    //   Flushing occurs when a break needs to be written, which happens
    //   when something other than a text node or inline element is seen.

    // If parent name and children are not given, format the entire document.
    // Assume prevailing indent = 0 if not given.
    void tree_format() {
       return tree_format("*DOCUMENT",tree,0) ;
    }

    void tree_format(String par_name, Deque<node> children, int indent){

        // Formatting options for parent element
        var par_opts = get_opts(par_name);

        // If parent is a block element:
        // - Remember its formatting options on the block stack so they can
        //   be used to control formatting of inline child elements.
        // - Set initial break type to entry-break.
        // - Shift prevailing indent right before generating child content.

        if (par_opts.get(OptionSetting.format) == "block"){
            begin_block(par_name, par_opts);
            set_block_break_type("entry-break");
            indent += (Integer)par_opts.get(OptionSetting.subindent);
        }

        // Variables for keeping track of whether the previous child
        // was a text node. Used for controlling break behavior in
        // non-normalized block elements: No line breaks are added around
        // text in such elements, nor is indenting added.

        var prev_child_is_text = false;
        var cur_child_is_text = false;

        for(var child:children){

            prev_child_is_text = cur_child_is_text;

            // Text nodes: just add text to pending output

             if (child.type == "text"){
                 cur_child_is_text = true;
                 add_to_pending(child.content);
                 continue;
            }

            cur_child_is_text = false;

            // Element nodes: handle depending on format type

            if (child.type == "elt"){

                var child_opts = get_opts(child.name);

                // Verbatim elements:
                // - Print literally without change (use _stringify).
                // - Do not line-wrap or add any indent.

                if (child_opts.get(OptionSetting.format) == "verbatim"){
                    flush_pending(indent);
                    if (!(prev_child_is_text && !block_normalize)) emit_break(0);
                    set_block_break_type("element-break");
                    add_to_doc(child.open_tag +
                            tree_stringify(child.content) +
                            child.close_tag);
                    continue;
                }

                // Inline elements:
                // - Do not break or indent.
                // - Do not line-wrap content; just add content to pending output
                //   and let it be wrapped as part of parent's content.

                if (child_opts.get(OptionSetting.format) == "inline"){
                    add_to_pending(child.open_tag);
                    tree_format(child.name, child.content, indent);
                    add_to_pending(child.close_tag);
                    continue;
                }

                // If we get here, node is a block element.

                // - Break and flush any pending output
                // - Break and indent (no indent if break count is zero)
                // - Process element itself:
                //   - Put out opening tag
                //   - Put out element content
                //   - Put out any indent needed before closing tag. None needed if:
                //     - Element's exit-break is 0 (closing tag is not on new line,
                //       so don't indent it)
                //     - There is no separate closing tag (it was in <abc/> format)
                //     - Element has no children (tags will be written as
                //       <abc></abc>, so don't indent closing tag)
                //     - Element has children, but the block is not normalized and
                //       the last child is a text node
                //   - Put out closing tag

                flush_pending(indent);
                if (!(prev_child_is_text && !block_normalize()))  emit_break(indent) ;
                set_block_break_type("element-break");
                add_to_doc(child.open_tag);
                tree_format(child.name, child.content, indent);
                if (!(((Integer)child_opts.get(OptionSetting.exit_break)) <= 0 ||
                            child.close_tag.isEmpty() ||
                            child.content.isEmpty() ||
                            (!child.content.isEmpty() &&
                            child.content.last.type == "text" &&
                            child_opts.get(OptionSetting.normalize) == "no"))) {
                    add_to_doc(" ".repeat(indent));
                }
                add_to_doc(child.close_tag);
                continue;
            }

            // Comments, PIs, etc. (everything other than text and elements),
            // treat similarly to verbatim block:
            // - Flush any pending output
            // - Put out a break
            // - Add node content to collected output

            flush_pending(indent);
            if(!(prev_child_is_text && !block_normalize())) emit_break(0);
            set_block_break_type("element-break");
            add_to_doc(child.content);

        }

        prev_child_is_text = cur_child_is_text;

        // Done processing current element's children now.

        // If current element is a block element:
        // - If there were any children, flush any pending output and put
        //   out the exit break.
        // - Pop the block stack

        if (par_opts.get(OptionSetting.format) == "block") {
            if (!children.isEmpty()) {
                flush_pending(indent);
                set_block_break_type("exit-break");
                if (!(prev_child_is_text && !block_normalize())) emit_break(0);
            }
            end_block();
        }

    }

    // Emit a break - the appropriate number of newlines according to the
    // enclosing block's current break type.

    // In addition, emit the number of spaces indicated by indent.  (indent
    // > 0 when breaking just before emitting an element tag that should
    // be indented within its parent element.)

    // Exception: Emit no indent if break count is zero. That indicates
    // any following output will be written on the same output line, not
    // indented on a new line.

    // Initially, when processing a node's child list, the break type is
    // set to entry-break. Each subsequent break is an element-break.
    // (After child list has been processed, an exit-break is produced as well.)

    void emit_break(int indent) {

        // number of newlines to emit
        var break_value = block_break_value();

        add_to_doc("\n".repeat(break_value));
        // add indent if there *was* a break
        if (indent >0 && break_value > 0) add_to_doc(" ".repeat(indent));
     }

    // Flush pending output to output document collected thus far:
    // - Wrap pending contents as necessary, with indent before *each* line.
    // - Add pending text to output document (thus "flushing" it)
    // - Clear pending array.

    void flush_pending(int indent) {

    // Do nothing if nothing to flush
    if (pending.isEmpty()) return;

    // If current block is not normalized:
    // - Text nodes cannot be modified (no wrapping or indent).  Flush
    //   text as is without adding a break or indent.
    // If current block is normalized:
    // - Add a break.
    // - If line wrap is disabled:
    //   - Add indent if there is a break. (If there isn't a break, text
    //     should immediately follow preceding tag, so don't add indent.)
    //   - Add text without wrapping
    // - If line wrap is enabled:
    //   - First line indent is 0 if there is no break. (Text immediately
    //     follows preceding tag.) Otherwise first line indent is same as
    //     prevailing indent.
    //   - Any subsequent lines get the prevailing indent.

    // After flushing text, advance break type to element-break.


    StringBuilder s = new StringBuilder();

    if (!block_normalize())
        s.append(pending.stream().collect(Collectors.joining("")));
    else {
        emit_break(0);
        var wrap_len = block_wrap_length();
        var wrap_type = block_wrap_type();
        var break_value = block_break_value();
        if (wrap_len <= 0 && wrap_type == WRAP_TYPE.length) {
            if (break_value > 0) s.append(" ".repeat(indent));
            s.append(pending.stream().collect(Collectors.joining("")));
        } else {
            var first_indent = (break_value > 0 ? indent : 0);
            // Wrap lines, then join by newlines (don't add one at end)
            s.append(line_wrap(pending, first_indent, indent, wrap_type, wrap_len).stream().collect(Collectors.joining("\n")));
        }
    }

    add_to_doc(s.toString());
    pending = new ArrayList<>();
    set_block_break_type("element-break");
    }

    // Perform line-wrapping of string array to lines no longer than given
    // length (including indent).
    // Any word longer than line length appears by itself on line.
    // Return array of lines (not newline-terminated).

    // strs - array of text items to be joined and line-wrapped.
    // Each item may be:
    // - A tag (such as <emphasis role="bold">). This should be treated as
    //   an atomic unit, which is important for preserving inline tags intact.
    // - A possibly multi-word string (such as "This is a string"). In this
    //   latter case, line-wrapping preserves internal whitespace in the
    //   string, with the exception that if whitespace would be placed at
    //   the end of a line, it is discarded.

    // first_indent - indent for first line
    // rest_indent - indent for any remaining lines
    // max_len - maximum length of output lines (including indent)

    List<String> line_wrap(List<String> strs, int first_indent, int rest_indent, WRAP_TYPE wrap_type, int max_len) {
    
        // First, tokenize the strings
        List<String> words = new ArrayList<>();
        for(var str:strs){
            if (str.matches("\\A</")) {
                // String is a tag; treat as atomic unit and don't split
                words.add(str);
            } else {
                  // String of white and non-white tokens.
                // Tokenize into white and non-white tokens.
                //str.scan(/\S+|\s+/).each { |word| words << word }
                Pattern.compile("\\S+|\\s+").matcher(str)
                        .results().map(MatchResult::group)
                        .forEach(words::add);
            }
        }

        // Now merge tokens that are not separated by whitespace tokens. For
        // example, "<i>", "word", "</i>" gets merged to "<i>word</i>".  But
        // "<i>", " ", "word", " ", "</i>" gets left as separate tokens.

        var words2 = new ArrayDeque<String>();
        for(var word:words){
          // If there is a previous word that does not end with whitespace,
          // and the currrent word does not begin with whitespace, concatenate
          // current word to previous word.  Otherwise append current word to
          // end of list of words
            if (!words2.isEmpty() && !words2.peek().matches("\\s\\z") && !word.matches("\\A\\s")) {
                words2.push(words2.pop().concat(word));
            } else {
                words2.add(word);
            }
        }

        var lines = new ArrayList<String>();
        var line = "";
        var llen = 0;
        // set the indent for the first line
        var indent = first_indent;
        // saved-up whitespace to put before next non-white word
        var white = new StringBuilder();
        var prev_word = "";

        for(var word: words2){         // ... while words remain to wrap
            // If word is whitespace, save it. It gets added before next
            // word if no line-break occurs.
            if (word.matches("\\A\\s") ) {
                white.append(word);
                continue;
            }
            var wlen = word.length();
            if (llen == 0) {
                // New output line; it gets at least one word (discard any
                // saved whitespace)
                line = " ".repeat(indent) + word;
                llen = indent + wlen;
                indent = rest_indent;
                white = new StringBuilder();
                continue;
            }

            if (wrap_type == WRAP_TYPE.length && llen + white.length() + wlen > max_len) {
                // Word (plus saved whitespace) won't fit on current line.
                // Begin new line (discard any saved whitespace).
                lines.add(line);
                line = " ".repeat(indent) + word;
                llen = indent + wlen;
                indent = rest_indent;
                white = new StringBuilder();
                continue;
            }

            if( wrap_type == WRAP_TYPE.sentence) {
                if ((prev_word.substring(prev_word.length()-1).matches("[\\.\\?\\!]")) && (word.substring(0,1).matches("^[[:upper:]]"))) {
                    lines.add(line);
                    line = " ".repeat(indent) + word;
                    llen = indent + wlen;
                    indent = rest_indent;
                    white = new StringBuilder();
                    continue;
                }
                prev_word = word;
            }

            // add word to current line with saved whitespace between
            line = line.concat( white + word);
            llen += white.length() + wlen;
            white = new StringBuilder();
        }
  
        // push remaining line, if any
        if (!line.isEmpty()) lines.add(line);

        return lines;
    }

    // ----------------------------------------------------------------------

    // Begin main program

    public static void main(String... args) throws ParseException, IOException {
        String usage = """
                Usage: #{__dir__} #{PROG_NAME} [options] xml-file

                Options:
                --help, -h
                    Print this message and exit.
                --backup suffix -b suffix
                    Back up the input document, adding suffix to the input
                    filename to create the backup filename.
                --canonized-output
                    Proceed only as far as the document canonization stage,
                    printing the result.
                --check-parser
                    Parse the document into tokens and verify that their
                    concatenation is identical to the original input document.
                    This option suppresses further document processing.
                --config-file file_name, -f file_name
                    Specify the configuration filename. If no file is named,
                    xmlformat uses the file named by the environment variable
                    XMLFORMAT_CONF, if it exists, or ./xmlformat.conf, if it
                    exists. Otherwise, xmlformat uses built-in formatting
                    options.
                --in-place, -i
                    Format the document in place, replacing the contents of
                    the input file with the reformatted document. (It's a
                    good idea to use --backup along with this option.)
                --show-config, -s
                    Show configuration options after reading configuration
                    file. This option suppresses document processing.
                --show-unconfigured-elements, -u
                    Show elements that are used in the document but for
                    which no options were specified in the configuration
                    file. This option suppresses document output.
                --verbose, -v
                    Be verbose about processing stages.
                --version, -V
                    Show version information and exit.""";

        var help = false;
        String backup_suffix = null;
        String conf_file = null;
        var canonize_only = false;
        var check_parser = false;
        var in_place = false;
        var show_conf = false;
        var show_unconf_elts = false;
        var show_version = false;
        var verbose = false;

        org.apache.commons.cli.Options opts = new org.apache.commons.cli.Options();
        // TODO: Move descriptions
        opts.addOption(new Option( "h", "help",                       false,null));
        opts.addOption(new Option( "b", "backup",                     true, null));
        opts.addOption(new Option( "o", "canonized-output",           false,null));
        opts.addOption(new Option( "p", "check-parser",               false,null));
        opts.addOption(new Option( "f", "config-file",                true, null));
        opts.addOption(new Option( "i", "in-place",                   false,null));
        opts.addOption(new Option( "s", "show-config",                false,null));
        opts.addOption(new Option( "u", "show-unconfigured-elements", false,null));
        opts.addOption(new Option( "v", "verbose",                    false,null));
        opts.addOption(new Option( "V", "version",                    false,null));

        final CommandLine commandLine = new DefaultParser().parse(opts, args);
        for (var opt: commandLine.getOptions()){
            switch (opt.getLongOpt())   {
                case "--help":
                    help = true; break;
                case "backup":
                    backup_suffix = opt.getValue(); break;
                case "canonized-output":
                    canonize_only = true; break;
                case "check-parser":
                    check_parser = true; break;
                case "config-file":
                    conf_file = opt.getValue(); break;
                case "in-place":
                    in_place = true; break;
                case "show-config":
                    show_conf = true; break;
                case "show-unconfigured-elements":
                    show_unconf_elts = true; break;
                case "version":
                    show_version = true; break;
                case "verbose":
                    verbose = true; break;
                default:
                    die("LOGIC ERROR: unhandled option: "+opt.getLongOpt()+"\n");
            }
        }

        if (help) {
            new HelpFormatter().printHelp(PROG_NAME, opts);
            exit(0);
        }

        if (show_version) {
            out.println(PROG_NAME+" "+PROG_VERSION+ "("+PROG_LANG+" version)");
            exit(0);
        }

        // --in-place option requires a named file

        if (in_place && commandLine.getArgs().length == 0) {
            warn("WARNING: --in-place/-i option ignored (requires named input files)\n");
        }

        // --backup/-b is meaningless without --in-place

        if (backup_suffix != null) {
            if (!in_place)
                die("--backup/-b option meaningless without --in-place/-i option\n");
        }

        // Save input filenames
        //in_file = ARGV.dup

        var xf = new xmlformat();

        var env_conf_file = System.getenv("XMLFORMAT_CONF");
        var def_conf_file = "./xmlformat.conf";

        // If no config file was named, but XMLFORMAT_CONF is set, use its value
        // as the config file name.
        if ((conf_file==null) && (env_conf_file!=null)){
            warn("No config file provided. Using envvar XMLFORMAT_CONF: "+env_conf_file);
            conf_file = env_conf_file;
        }

        // If config file still isn't defined, use the default file if it exists.
        if (conf_file==null){
            if (Files.isReadable(Paths.get(def_conf_file)) && !Files.isDirectory(Paths.get(def_conf_file))) {
                    warn("No config file provided. Defaulting to: " + def_conf_file);
                    conf_file = def_conf_file;
            }
        }

        if (conf_file!=null) {
            if (verbose) warn("Reading configuration file "+conf_file+"\n");
            if (!Files.isReadable(Paths.get(conf_file))) {
                die("Configuration file '"+conf_file+"' is not readable.\n");
            }
            if (Files.isDirectory(Paths.get(conf_file))) {
                die("Configuration file '"+conf_file+"' is a directory.\n");
            }
            xf.read_config(conf_file);
        }

        if (show_conf)  {      // show configuration and exit
            xf.display_config();
            exit(0);
        }

        // Process arguments.
        // - If no files named, read string, write to stdout.
        // - If files named, read and process each one. Write output to stdout
        //   unless --in-place option was given.  Make backup of original file
        //   if --backup option was given.

        if ( commandLine.getArgs().length == 0) {
            if (verbose) warn("Reading document...\n");
            var in_doc = new String(in.readAllBytes());
            out_doc = xf.process_doc(in_doc,
                        verbose, check_parser, canonize_only, show_unconf_elts, 0);
            if (out_doc!=null) {
                if (verbose) warn("Writing output document...\n");
                out.println(out_doc);
            }
        }  else {
            for(var file:commandLine.getArgs()) {
                if (verbose) warn("Reading document //{file}...\n");
                var in_doc = Files.lines(Path.of(file), StandardCharsets.UTF_8).collect(Collectors.joining("\n"));

                out_doc = xf.process_doc(in_doc,
                    verbose, check_parser, canonize_only, show_unconf_elts, 0);
                if (out_doc==null) continue;
                if (in_place) {
                    if (backup_suffix != null) {
                        if (verbose)
                            warn("Making backup of " + file + " to " + file + "" + backup_suffix + "...\n");
                        Files.move(Path.of(file), Path.of(file + backup_suffix));
                    }
                    if (verbose)
                        warn("Writing output document to " + file + "...\n");
                    Files.writeString(Path.of(file), out_doc, StandardCharsets.UTF_8, StandardOpenOption.WRITE);
                } else {
                    if (verbose) warn("Writing output document...\n");
                    out.println(out_doc);
                }
            }
        }

        if (verbose) warn("Done!\n");

        exit(0);
    }
}

enum WRAP_TYPE {
    sentence, length, none
}

enum OptionSetting {
    format       ( String.class),
    normalize    ( Boolean.class),
    subindent    ( Integer.class),
    wrap_type    ( WRAP_TYPE.class),
    wrap_length  ( Integer.class),
    entry_break  ( Integer.class),
    exit_break   ( Integer.class),
    element_break( Integer.class)
    ;

    final Class backingClass;

    OptionSetting(Class backingClass){
        this.backingClass = backingClass;
    }

    Object checkOptionSetting(String settingValue){
        if (Integer.class.equals(this.backingClass)) {
            return Integer.valueOf(settingValue);
        } else if (Boolean.class.equals(this.backingClass)) {
            return Boolean.valueOf(settingValue);
        } else if (WRAP_TYPE.class.equals(this.backingClass)) {
            return WRAP_TYPE.valueOf(settingValue.replaceAll("-","_"));
        } else {
            return settingValue;
        }

    }

}

class Options extends EnumMap<OptionSetting, Object> {

    public Options() {
        super(OptionSetting.class);
    }

    public Options(String format, boolean normalize,
                   int subindent, WRAP_TYPE wrap_type,
                   int wrap_length, int entry_break,
                   int exit_break, int element_break) {
        super(OptionSetting.class);
        this.put(OptionSetting.format,format);
        this.put(OptionSetting.normalize,normalize);
        this.put(OptionSetting.subindent,subindent);
        this.put(OptionSetting.wrap_type,wrap_type);
        this.put(OptionSetting.wrap_length,wrap_length);
        this.put(OptionSetting.entry_break,entry_break);
        this.put(OptionSetting.exit_break,exit_break);
        this.put(OptionSetting.element_break,element_break);
    }

    public void putSetting(OptionSetting setting, String value) {
        this.put(setting, setting.checkOptionSetting(value));
    }
}

@FunctionalInterface
interface TriFunction<T, U, V, R> {

    /**
     * Applies this function to the given arguments.
     *
     * @param t the first function argument
     * @param u the second function argument
     * @param v the third function argument
     * @return the function result
     */
    R apply(T t, U u, V v);

    /**
     * Returns a composed function that first applies this function to
     * its input, and then applies the {@code after} function to the result.
     * If evaluation of either function throws an exception, it is relayed to
     * the caller of the composed function.
     *
     * @param <W>   the type of output of the {@code after} function, and of the
     *              composed function
     * @param after the function to apply after this function is applied
     * @return a composed function that first applies this function and then
     * applies the {@code after} function
     * @throws NullPointerException if after is null
     */
    default <W> TriFunction<T, U, V, W> andThen(Function<? super R, ? extends W> after) {
        Objects.requireNonNull(after);
        return (T t, U u, V v) -> after.apply(apply(t, u, v));
    }
}

