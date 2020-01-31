#!/usr/bin/ruby -w
# vim:set ts=2 sw=2 expandtab:

# xmlformat.rb - XML document reformatter

# Copyright (c) 2004, 2005, Kitebird, LLC.  All rights reserved.
# Some portions are based on the REX shallow XML parser, which
# is Copyright (c) 1998, Robert D. Cameron. These include the
# regular expression parsing variables and the shallow_parse()
# method.
# This software is licensed as described in the file LICENSE,
# which you should have received as part of this distribution.

# Differences from Perl version:
# - Pattern for classifying token as text node is different.
#   (cannot use !~ op for case)
# - It's important to use \A and \z|\Z rather than ^ and $ in pattern
#   matches on tokens, because ^ and $ might match after/before a
#   newline for a token that spans multiple lines!

require "getoptlong"

PROG_NAME = "xmlformat"
PROG_VERSION = "1.04"
PROG_LANG = "Ruby"

# ----------------------------------------------------------------------

# XMLFormat module

# Contains:
# - Methods for parsing XML document
# - Methods for reading configuration file and operating on configuration
#   information.

module XMLFormat


# ----------------------------------------------------------------------

# Module methods

# warn - print message to stderr
# die - print message to stderr and exit

def warn(*args)
  $stderr.print args
end

def die(*args)
  $stderr.print args
  exit(1)
end

# ----------------------------------------------------------------------

# Module variables - these do not vary per class invocation

# Regular expressions for parsing document components. Based on REX.

# Compared to Perl version, these variable names use more Ruby-like
# lettercase. (Ruby likes to interpret variables that begin with
# uppercase as constants.)

# spe = shallow parsing expression
# se = scanning expression
# ce = completion expression
# rsb = right square brackets
# qm = question mark

@@text_se = "[^<]+"
@@until_hyphen = "[^-]*-"
@@until_2_hyphens = "#{@@until_hyphen}(?:[^-]#{@@until_hyphen})*-"
@@comment_ce = "#{@@until_2_hyphens}>?"
@@until_rsbs = "[^\\]]*\\](?:[^\\]]+\\])*\\]+"
@@cdata_ce = "#{@@until_rsbs}(?:[^\\]>]#{@@until_rsbs})*>"
@@s = "[ \\n\\t\\r]+"
@@name_strt = "[A-Za-z_:]|[^\\x00-\\x7F]"
@@name_char = "[A-Za-z0-9_:.-]|[^\\x00-\\x7F]"
@@name = "(?:#{@@name_strt})(?:#{@@name_char})*"
@@quote_se = "\"[^\"]*\"|'[^']*'"
@@dt_ident_se = "#{@@s}#{@@name}(?:#{@@s}(?:#{@@name}|#{@@quote_se}))*"
@@markup_decl_ce = "(?:[^\\]\"'><]+|#{@@quote_se})*>"
@@s1 = "[\\n\\r\\t ]"
@@until_qms = "[^?]*\\?+"
@@pi_tail = "\\?>|#{@@s1}#{@@until_qms}(?:[^>?]#{@@until_qms})*>"
@@dt_item_se =
"<(?:!(?:--#{@@until_2_hyphens}>|[^-]#{@@markup_decl_ce})|\\?#{@@name}(?:#{@@pi_tail}))|%#{@@name};|#{@@s}"
@@doctype_ce =
"#{@@dt_ident_se}(?:#{@@s})?(?:\\[(?:#{@@dt_item_se})*\\](?:#{@@s})?)?>?"
@@decl_ce =
"--(?:#{@@comment_ce})?|\\[CDATA\\[(?:#{@@cdata_ce})?|DOCTYPE(?:#{@@doctype_ce})?"
@@pi_ce = "#{@@name}(?:#{@@pi_tail})?"
@@end_tag_ce = "#{@@name}(?:#{@@s})?>?"
@@att_val_se = "\"[^<\"]*\"|'[^<']*'"
@@elem_tag_se =
"#{@@name}(?:#{@@s}#{@@name}(?:#{@@s})?=(?:#{@@s})?(?:#{@@att_val_se}))*(?:#{@@s})?/?>?"
@@markup_spe =
"<(?:!(?:#{@@decl_ce})?|\\?(?:#{@@pi_ce})?|/(?:#{@@end_tag_ce})?|(?:#{@@elem_tag_se})?)"
@@xml_spe = Regexp.new("#{@@text_se}|#{@@markup_spe}")

#
@@sentence_end = "[.?]\"?"
# ----------------------------------------------------------------------

# Allowable formatting options and their possible values:
# - The keys of this hash are the allowable option names
# - The value for each key is list of allowable option values
# - If the value is nil, the option value must be numeric
# If any new formatting option is added to this program, it
# must be specified here, *and* a default value for it should
# be listed in the *DOCUMENT and *DEFAULT pseudo-element
# option hashes.

@@opt_list = {
  "format"        => [ "block", "inline", "verbatim" ],
  "normalize"     => [ "yes", "no" ],
  "subindent"     => nil,
  "wrap-length"   => nil,
  "entry-break"   => nil,
  "exit-break"    => nil,
  "element-break" => nil
}

class XMLFormatter

  # Object creation: set up the default formatting configuration
  # and variables for maintaining input and output document.

  def initialize

    # Formatting options for each element.

    @elt_opts = { }

    # The formatting options for the *DOCUMENT and *DEFAULT pseudo-elements can
    # be overridden in the configuration file, but the options must also be
    # built in to make sure they exist if not specified in the configuration
    # file.  Each of the structures must have a value for every option.

    # Options for top-level document children.
    # - Do not change entry-break: 0 ensures no extra newlines before
    #   first element of output.
    # - Do not change exit-break: 1 ensures a newline after final element
    #   of output document.
    # - It's probably best not to change any of the others, except perhaps
    #   if you want to increase the element-break.

    @elt_opts["*DOCUMENT"] = {
      "format"        => "block",
      "normalize"     => "no",
      "subindent"     => 0,
      "wrap-length"   => 0,
      "entry-break"   => 0, # do not change
      "exit-break"    => 1, # do not change
      "element-break" => 1
    }

    # Default options. These are used for any elements in the document
    # that are not specified explicitly in the configuration file.

    @elt_opts["*DEFAULT"] = {
      "format"        => "block",
      "normalize"     => "no",
      "subindent"     => 1,
      "wrap-length"   => 0,
      "entry-break"   => 1,
      "exit-break"    => 1,
      "element-break" => 1
    }

    # Run the *DOCUMENT and *DEFAULT options through the option-checker
    # to verify that the built-in values are legal.

    err_count = 0

    @elt_opts.keys.each do |elt_name|                 # ... for each element
      @elt_opts[elt_name].each do |opt_name, opt_val| # ... for each option
        opt_val, err_msg = check_option(opt_name, opt_val)
        if err_msg.nil?
          @elt_opts[elt_name][opt_name] = opt_val
        else
          warn "LOGIC ERROR: #{elt_name} default option is invalid\n"
          warn "#{err_msg}\n"
          err_count += 1
        end
      end
    end

    # Make sure that the every option is represented in the
    # *DOCUMENT and *DEFAULT structures.

    @@opt_list.keys.each do |opt_name|
      @elt_opts.keys.each do |elt_name|
        if !@elt_opts[elt_name].has_key?(opt_name)
          warn "LOGIC ERROR: #{elt_name} has no default '#{opt_name}' option\n"
          err_count += 1
        end
      end
    end

    if err_count > 0
      raise "Cannot continue; internal default formatting options must be fixed"
    end

  end

  # Initialize the variables that are used per-document

  def init_doc_vars

    # Elements that are used in the document but not named explicitly
    # in the configuration file.

    @unconf_elts = { }

    # List of tokens for current document.

    @tokens = [ ]

    # List of line numbers for each token

    @line_num = [ ]

    # Document node tree (constructed from the token list)

    @tree = [ ]

    # Variables for formatting operations:
    # @out_doc = resulting output document (constructed from document tree)
    # @pending = array of pending tokens being held until flushed

    @out_doc = ""
    @pending = [ ]

    # Inline elements within block elements are processed using the
    # text normalization (and possible line-wrapping) values of their
    # enclosing block. Blocks and inlines may be nested, so we maintain
    # a stack that allows the normalize/wrap-length values of the current
    # block to be determined.

    @block_name_stack = [ ] # for debugging
    @block_opts_stack = [ ]

    # A similar stack for maintaining each block's current break type.

    @block_break_type_stack = [ ]
  end

  # Accessors for token list and resulting output document

  def tokens
    return @tokens
  end

  def out_doc
    return @out_doc
  end

  # Methods for adding strings to output document or
  # to the pending output array

  def add_to_doc(str)
    @out_doc << str
  end

  def add_to_pending(str)
    @pending << str
  end


  # Block stack maintenance methods

  # Push options onto or pop options off from the stack.  When doing
  # this, also push or pop an element onto the break-level stack.

  def begin_block(name, opts)
    @block_name_stack << name
    @block_opts_stack << opts
    @block_break_type_stack << "entry-break"
  end

  def end_block
    @block_name_stack.pop
    @block_opts_stack.pop
    @block_break_type_stack.pop
  end

  # Return the current block's normalization status or wrap length

  def block_normalize
    return @block_opts_stack.last["normalize"] == "yes"
  end

  def block_wrap_length
    return @block_opts_stack.last["wrap-length"]
  end

  # Set the current block's break type, or return the number of newlines
  # for the block's break type

  def set_block_break_type(type)
    @block_break_type_stack[@block_break_type_stack.size-1] = type
  end

  def block_break_value
    return @block_opts_stack.last[@block_break_type_stack.last]
  end


  # Read configuration information.  For each element, construct a hash
  # containing a hash key and value for each option name and value.
  # After reading the file, fill in missing option values for
  # incomplete option structures using the *DEFAULT options.

  def read_config(conf_file)
    elt_names = nil
    in_continuation = false
    saved_line = ""

    File.open(conf_file) do |fh|
      fh.each_line do |line|
        line.chomp!
        next if line =~ /^\s*($|#)/       # skip blank lines, comments
        if in_continuation
          line = saved_line + " " + line
          saved_line = ""
          in_continuation = false
        end
        if line !~ /^\s/
          # Line doesn't begin with whitespace, so it lists element names.
          # Names are separated by whitespace or commas, possibly followed
          # by a continuation character or comment.
          if line =~ /\\$/
            in_continuation = true
            saved_line = line.sub(/\\$/, "")  # remove continuation character
            next
          end
          line.sub!(/\s*#.*$/, "")            # remove any trailing comment
          elt_names = line.split(/[\s,]+/)
          # make sure each name has an entry in the elt_opts structure
          elt_names.each do |elt_name|
            @elt_opts[elt_name] = { } unless @elt_opts.has_key?(elt_name)
          end
        else
          # Line begins with whitespace, so it contains an option
          # to apply to the current element list, possibly followed by
          # a comment.  First check that there is a current list.
          # Then parse the option name/value.

          if elt_names.nil?
            raise "#{conf_file}:#{$.}: Option setting found before any " +
                "elements were named.\n"
          end
          line.sub!(/\s*#.*$/, "")
          line =~ /^\s*(\S+)(?:\s+|\s*=\s*)(\S+)$/
          opt_name, opt_val = $1, $2
          raise "#{conf_file}:#{$.}: Malformed line: #{$_}" if opt_val.nil?

          # Check option. If illegal, die with message. Otherwise,
          # add option to each element in current element list

          opt_val, err_msg = check_option(opt_name, opt_val)
          raise "#{conf_file}:#{$.}: #{err_msg}\n" unless err_msg.nil?
          elt_names.each do |elt_name|
            @elt_opts[elt_name][opt_name] = opt_val
          end

        end
      end
    end

    # For any element that has missing option values, fill in the values
    # using the options for the *DEFAULT pseudo-element.  This speeds up
    # element option lookups later.  It also makes it unnecessary to test
    # each option to see if it's defined: All element option structures
    # will have every option defined.

    def_opts = @elt_opts["*DEFAULT"]

    @elt_opts.keys.each do |elt_name|
      next if elt_name == "*DEFAULT"
      def_opts.keys.each do |opt_name|
        next if @elt_opts[elt_name].has_key?(opt_name)   # already set
        @elt_opts[elt_name][opt_name] = def_opts[opt_name]
      end
    end

  end


  # Check option name to make sure it's legal. Check the value to make sure
  # that it's legal for the name.  Return a two-element array:
  # (value, nil) if the option name and value are legal.
  # (nil, message) if an error was found; message contains error message.
  # For legal values, the returned value should be assigned to the option,
  # because it may get type-converted here.

  def check_option(opt_name, opt_val)

    # - Check option name to make sure it's a legal option
    # - Then check the value.  If there is a list of values
    #   the value must be one of them.  Otherwise, the value
    #   must be an integer.

    if !@@opt_list.has_key?(opt_name)
      return [ nil, "Unknown option name: #{opt_name}" ]
    end

    allowable_val = @@opt_list[opt_name]
    if !allowable_val.nil?
      if !allowable_val.find { |val| val == opt_val }
        return [ nil, "Unknown '#{opt_name}' value: #{opt_val}" ]
      end
    elsif !opt_val.is_a?(Integer)
      if opt_val =~ /^\d+$/
        opt_val = opt_val.to_i
      else
        return [ nil, "'#{opt_name}' value (#{opt_val}) should be an integer" ]
      end
    end
    return [ opt_val, nil ]
  end
  private :check_option


  # Return hash of option values for a given element.  If no options are found:
  # - Add the element name to the list of unconfigured options.
  # - Assign the default options to the element.  (This way the test for the
  #   option fails only once.)

  def get_opts(elt_name)
    opts = @elt_opts[elt_name]
    if opts.nil?
      @unconf_elts[elt_name] = 1
      opts = @elt_opts[elt_name] =  @elt_opts["*DEFAULT"]
    end
    return opts
  end
  private :get_opts


  # Display contents of configuration options to be used to process document.
  # For each element named in the elt_opts structure, display its format
  # type, and those options that apply to the type.

  def display_config
    # Format types and the additional options that apply to each type
    format_opts = {
      "block" => [
                  "entry-break",
                  "element-break",
                  "exit-break",
                  "subindent",
                  "normalize",
                  "wrap-length"
                  ],
      "inline" => [ ],
      "verbatim" => [ ]
    }
    @elt_opts.keys.sort.each do |elt_name|
      puts elt_name
      opts = @elt_opts[elt_name]
      format = opts["format"]
      # Write out format type, then options that apply to the format type
      puts "  format = #{format}"
      format_opts[format].each do |opt_name|
        puts "  #{opt_name} = #{opts[opt_name]}"
      end
      puts
    end
  end


  # Display the list of elements that are used in the document but not
  # configured in the configuration file.

  # Then re-unconfigure the elements so that they won't be considered
  # as configured for the next document, if there is one.

  def display_unconfigured_elements
    elts = @unconf_elts.keys
    if elts.empty?
      puts "The document contains no unconfigured elements."
    else
      puts "The following document elements were assigned no formatting options:"
      puts line_wrap([elts.sort.join(" ")], 0, 0, 65).join("\n")
    end

    elts.each do |elt_name|
      @elt_opts.delete(elt_name)
    end
  end

  # ----------------------------------------------------------------------

  # Main document processing routine.
  # - Argument is a string representing an input document
  # - Return value is the reformatted document, or nil. An nil return
  #   signifies either that an error occurred, or that some option was
  #   given that suppresses document output. In either case, don't write
  #   any output for the document.  Any error messages will already have
  #   been printed when this returns.

  def process_doc(doc, verbose, check_parser, canonize_only,
                  show_unconf_elts, indent)

    init_doc_vars

    # Perform lexical parse to split document into list of tokens
    warn "Parsing document...\n" if verbose
    shallow_parse(doc)

    if (check_parser)
      warn "Checking parser...\n" if verbose
      # concatentation of tokens should be identical to original document
      if doc == tokens.join("")
        puts "Parser is okay"
      else
        puts "PARSER ERROR: document token concatenation differs from document"
      end
      return nil
    end

    # Assign input line number to each token
    assign_line_numbers

    # Look for and report any error tokens returned by parser
    warn "Checking document for errors...\n" if verbose
    if report_errors > 0
      warn "Cannot continue processing document.\n"
      return nil
    end

    # Convert the token list to a tree structure
    warn "Convert document tokens to tree...\n" if verbose
    if tokens_to_tree > 0
      warn "Cannot continue processing document.\n"
      return nil
    end

    # Check: Stringify the tree to convert it back to a single string,
    # then compare to original document string (should be identical)
    # (This is an integrity check on the validity of the to-tree and stringify
    # operations; if one or both do not work properly, a mismatch should occur.)
    #str = tree_stringify
    #print str
    #warn "ERROR: mismatch between document and resulting string\n" if doc != str

    # Canonize tree to remove extraneous whitespace
    warn "Canonizing document tree...\n" if verbose
    tree_canonize(indent)

    if (canonize_only)
      puts tree_stringify
      return nil
    end

    # One side-effect of canonizing the tree is that the formatting
    # options are looked up for each element in the document.  That
    # causes the list of elements that have no explicit configuration
    # to be built.  Display the list and return if user requested it.

    if show_unconf_elts
      display_unconfigured_elements
      return nil
    end

    # Format the tree to produce formatted XML as a single string
    warn "Formatting document tree...\n" if verbose
    tree_format

    # If the document is not empty, add a newline and emit a warning if
    # reformatting failed to add a trailing newline.  This shouldn't
    # happen if the *DOCUMENT options are set up with exit-break = 1,
    # which is the reason for the warning rather than just silently
    # adding the newline.

    str = out_doc
    if !str.empty? && str !~ /\n\z/
      warn "LOGIC ERROR: trailing newline had to be added\n"
      str << "\n"
    end

    return str
  end

  # ----------------------------------------------------------------------

  # Parse XML document into array of tokens and store array

  def shallow_parse(xml_document)
    @tokens = xml_document.scan(@@xml_spe)
  end

  # ----------------------------------------------------------------------

  # Extract a tag name from a tag and return it. This uses a subset
  # of the document-parsing pattern elements.

  # Dies if the tag cannot be found, because this is supposed to be
  # called only with a legal tag.

  def extract_tag_name(tag)
    match = /\A<\/?(#{@@name})/.match(tag)
    return match[1] if match
    raise "Cannot find tag name in tag: #{tag}"
  end
  private :extract_tag_name

  # ----------------------------------------------------------------------

  # Assign an input line number to each token.  The number indicates
  # the line number on which the token begins.

  def assign_line_numbers
    line_num = 1;

    @line_num = [ ]
    @tokens.each do |token|
      @line_num << line_num
      line_num += token.count "\n"
    end
  end
  private :assign_line_numbers

  # ----------------------------------------------------------------------

  # Check token list for errors and report any that are found. Error
  # tokens are those that begin with "<" but do not end with ">".

  # Returns the error count.

  # Does not modify the original token list.

  def report_errors
    err_count = 0

    @tokens.each_index do |i|
      token = @tokens[i]
      if token =~ /\A</ && token !~ />\Z/
        warn "Malformed token at line #{@line_num[i]}, token #{i+1}: #{token}\n"
        err_count += 1
      end
    end

    warn "Number of errors found: #{err_count}\n" if err_count > 0
    return err_count
  end

  # ----------------------------------------------------------------------

  # Helper routine to print tag stack for tokens_to_tree

  def print_tag_stack(label, stack)
    if stack.size < 1
      warn "  #{label}: none\n"
    else
      warn "  #{label}:\n"
      stack.each_with_index do |tag, i|
        warn "  #{i+1}: #{tag}\n"
      end
    end
  end

  # Convert the list of XML document tokens to a tree representation.
  # The implementation uses a loop and a stack rather than recursion.

  # Does not modify the original token list.

  # Returns an error count.

  def tokens_to_tree

    tag_stack = [ ]        # stack for element tags
    children_stack = [ ]   # stack for lists of children
    children = [ ]         # current list of children
    err_count = 0

    # Note: the text token pattern test assumes that all text tokens
    # are non-empty. This should be true, because REX doesn't create
    # empty tokens.

    @tokens.each_index do |i|
      token = @tokens[i]
      line_num = @line_num[i]
      tok_err = "Error near line #{line_num}, token #{i+1} (#{token})"
      case token
      when /\A[^<]/                      # text
        children << text_node(token)
      when /\A<!--/                      # comment
        children << comment_node(token)
      when /\A<\?/                       # processing instruction
        children << pi_node(token)
      when /\A<!DOCTYPE/                 # DOCTYPE
        children << doctype_node(token)
      when /\A<!\[/                      # CDATA
        children << cdata_node(token)
      when /\A<\//                       # element close tag
        if tag_stack.empty?
          warn "#{tok_err}: Close tag w/o preceding open tag; malformed document?\n"
          err_count += 1
          next
        end
        if children_stack.empty?
          warn "#{tok_err}: Empty children stack; malformed document?\n"
          err_count += 1
          next
        end
        tag = tag_stack.pop
        open_tag_name = extract_tag_name(tag)
        close_tag_name = extract_tag_name(token)
        if open_tag_name != close_tag_name
          warn "#{tok_err}: Tag mismatch; malformed document?\n"
          warn "  open tag: #{tag}\n"
          warn "  close tag: #{token}\n"
          print_tag_stack("enclosing tags", tag_stack)
          err_count += 1
          next
        end
        elt = element_node(tag, token, children)
        children = children_stack.pop
        children << elt
      else                              # element open tag
        # If we reach here, we're seeing the open tag for an element:
        # - If the tag is also the close tag (e.g., <abc/>), close the
        #   element immediately, giving it an empty child list.
        # - Otherwise, push tag and child list on stacks, begin new child
        #   list for element body.
        case token
        when /\/>\Z/     # tag is of form <abc/>
          children << element_node(token, "", [ ])
        else              # tag is of form <abc>
          tag_stack << token
          children_stack << children
          children = [ ]
        end
      end
    end

    # At this point, the stacks should be empty if the document is
    # well-formed.

    if !tag_stack.empty?
      warn "Error at EOF: Unclosed tags; malformed document?\n"
      print_tag_stack("unclosed tags", tag_stack)
      err_count += 1
    end
    if !children_stack.empty?
      warn "Error at EOF: Unprocessed child elements; malformed document?\n"
# TODO: print out info about them
      err_count += 1
    end

    @tree = children
    return err_count
  end


  # Node-generating helper methods for tokens_to_tree

  # Generic node generator

  def node(type, content)
    return { "type" => type, "content" => content }
  end
  private :node

  # Generators for specific non-element nodes

  def text_node(content)
    return node("text", content)
  end
  private :text_node

  def comment_node(content)
    return node("comment", content)
  end
  private :comment_node

  def pi_node(content)
    return node("pi", content)
  end
  private :pi_node

  def doctype_node(content)
    return node("DOCTYPE", content)
  end
  private :doctype_node

  def cdata_node(content)
    return node("CDATA", content)
  end
  private :cdata_node

  # For an element node, create a standard node with the type and content
  # key/value pairs. Then add pairs for the "name", "open_tag", and
  # "close_tag" hash keys.

  def element_node(open_tag, close_tag, children)
    elt = node("elt", children)
    # name is the open tag with angle brackets and attibutes stripped
    elt["name"] = extract_tag_name(open_tag)
    elt["open_tag"] = open_tag
    elt["close_tag"] = close_tag
    return elt
  end
  private :element_node

  # ----------------------------------------------------------------------

  # Convert the given XML document tree (or subtree) to string form by
  # concatentating all of its components.  Argument is a reference
  # to a list of nodes at a given level of the tree.  (If argument is
  # missing, use the top level of the tree.)

  # Does not modify the node list.

  def tree_stringify(children = @tree)
    str = ""

    children.each do |child|
      # - Elements have list of child nodes as content (process recursively)
      # - All other node types have text content
      if child["type"] == "elt"
        str << child["open_tag"] +
              tree_stringify(child["content"]) +
              child["close_tag"]
      else
        str << child["content"]
      end
    end
    return str
  end

  # ----------------------------------------------------------------------

  # Put tree in "canonical" form by eliminating extraneous whitespace
  # from element text content.

  # children is a list of child nodes

  # This function modifies the node list.

  # Canonizing occurs as follows:
  # - Comment, PI, DOCTYPE, and CDATA nodes remain untouched
  # - Verbatim elements and their descendants remain untouched
  # - Within non-normalized block elements:
  #   - Delete all-whitespace text node children
  #   - Leave other text node children untouched
  # - Within normalized block elements:
  #   - Convert runs of whitespace (including line-endings) to single spaces
  #   - Trim leading whitespace of first text node
  #   - Trim trailing whitespace of last text node
  #   - Trim whitespace that is adjacent to a verbatim or non-normalized
  #     sub-element.  (For example, if a <programlisting> is followed by
  #     more text, delete any whitespace at beginning of that text.)
  # - Within inline elements:
  #   - Normalize the same way as the enclosing block element, with the
  #     exception that a space at the beginning or end is not removed.
  #     (Otherwise, <para>three<literal> blind </literal>mice</para>
  #     would become <para>three<literal>blind</literal>mice</para>).

  def tree_canonize(indent)
    @tree = tree_canonize2(@tree, "*DOCUMENT", indent)
  end

  def tree_canonize2(children, par_name, indent)

    # Formatting options for parent
    par_opts = get_opts(par_name)

    # If parent is a block element, remember its formatting options on
    # the block stack so they can be used to control canonization of
    # inline child elements.

    if par_opts["format"] == "block"
      begin_block(par_name, par_opts)
    end

    # Iterate through list of child nodes to preserve, modify, or
    # discard whitespace.  Return resulting list of children.

    # Canonize element and text nodes. Leave everything else (comments,
    # processing instructions, etc.) untouched.

    new_children = [ ]

    while !children.empty?

      child = children.shift

      if child["type"] == "elt"

        # Leave verbatim elements untouched. For other element nodes,
        # canonize child list using options appropriate to element.

        if get_opts(child["name"])["format"] != "verbatim"
          child["content"] = tree_canonize2(child["content"], child["name"], indent+par_opts["subindent"])
        end

      elsif child["type"] == "text"

        # Delete all-whitespace node or strip whitespace as appropriate.

        # Paranoia check: We should never get here for verbatim elements,
        # because normalization is irrelevant for them.

        if par_opts["format"] == "verbatim"
          die "LOGIC ERROR: trying to canonize verbatim element #{par_name}!\n"
        end

        if !block_normalize

          # Enclosing block is not normalized:
          # - Delete child all-whitespace text nodes.
          # - Leave other text nodes untouched.

          next if child["content"] =~ /\A\s*\Z/

        else

          # Enclosing block is normalized, so normalize this text node:
          # - Convert runs of whitespace characters (including
          #   line-endings characters) to single spaces.
          # - Trim leading whitespace if this node is the first child
          #   of a block element or it follows a non-normalized node.
          # - Trim leading whitespace if this node is the last child
          #   of a block element or it precedes a non-normalized node.

          # These are nil if there is no prev or next child
          prev_child = new_children.last
          next_child = children.first

          child["content"].gsub!(/\s+/, " ")
          if (prev_child.nil? && par_opts["format"] == "block") ||
              non_normalized_node(prev_child)
            child["content"].sub!(/\A /, "")
          end
          if (next_child.nil? && par_opts["format"] == "block") ||
              non_normalized_node(next_child)
            child["content"].sub!(/ \Z/, "")
          end

          # After whitespace normalization, split the text into sentences
          # This is done by a simple regexp replacement, 
          # looking for period and interrogation symbols and adding a break after them.
          # Note also that the split should also be indented correctly after the break.
          indent_str = (" " * (indent+par_opts["subindent"]));
          child["content"].gsub!(/(#{@@sentence_end})\s+/,'\1'+"\n"+indent_str)

          # If resulting text is empty, discard the node.
          next if child["content"] =~ /\A\Z/

        end
      end
      new_children << child
    end

    # Pop block stack if parent was a block element
    end_block if par_opts["format"] == "block"

    return new_children
  end
  private :tree_canonize2


  # Helper function for tree_canonize().

  # Determine whether a node is normalized.  This is used to check
  # the node that is adjacent to a given text node (either previous
  # or following).
  # - No is node is nil
  # - No if the node is a verbatim element
  # - If the node is a block element, yes or no according to its
  #   normalize option
  # - No if the node is an inline element.  Inlines are normalized
  #   if the parent block is normalized, but this method is not called
  #   except while examinine normalized blocks. So its inline children
  #   are also normalized.
  # - No if node is a comment, PI, DOCTYPE, or CDATA section. These are
  #   treated like verbatim elements.

  def non_normalized_node(node)
    return false if node.nil?
    case node["type"]
    when "elt"
      opts = get_opts(node["name"])
      case opts["format"]
      when "verbatim"
        return true
      when "block"
        return opts["normalize"] == "no"
      when "inline"
        return false
      else
        die "LOGIC ERROR: non_normalized_node: unhandled node format.\n"
      end
    when "comment", "pi", "DOCTYPE", "CDATA"
      return true
    when "text"
      die "LOGIC ERROR: non_normalized_node: got called for text node.\n"
    else
      die "LOGIC ERROR: non_normalized_node: unhandled node type.\n"
    end
  end
  private :non_normalized_node

  # ----------------------------------------------------------------------

  # Format (pretty-print) the document tree

  # Does not modify the node list.

  # The class maintains two variables for storing output:
  # - out_doc stores content that has been seen and "flushed".
  # - pending stores an array of strings (content of text nodes and inline
  #   element tags).  These are held until they need to be flushed, at
  #   which point they are concatenated and possibly wrapped/indented.
  #   Flushing occurs when a break needs to be written, which happens
  #   when something other than a text node or inline element is seen.

  # If parent name and children are not given, format the entire document.
  # Assume prevailing indent = 0 if not given.

  def tree_format(par_name = "*DOCUMENT", children = @tree, indent = 0)

    # Formatting options for parent element
    par_opts = get_opts(par_name)

    # If parent is a block element:
    # - Remember its formatting options on the block stack so they can
    #   be used to control formatting of inline child elements.
    # - Set initial break type to entry-break.
    # - Shift prevailing indent right before generating child content.

    if par_opts["format"] == "block"
      begin_block(par_name, par_opts)
      set_block_break_type("entry-break")
      indent += par_opts["subindent"]
    end

    # Variables for keeping track of whether the previous child
    # was a text node. Used for controlling break behavior in
    # non-normalized block elements: No line breaks are added around
    # text in such elements, nor is indenting added.

    prev_child_is_text = false
    cur_child_is_text = false

    children.each do |child|

      prev_child_is_text = cur_child_is_text

      # Text nodes: just add text to pending output

      if child["type"] == "text"
        cur_child_is_text = true
        add_to_pending(child["content"])
        next
      end

      cur_child_is_text = false

      # Element nodes: handle depending on format type

      if child["type"] == "elt"

        child_opts = get_opts(child["name"])

        # Verbatim elements:
        # - Print literally without change (use _stringify).
        # - Do not line-wrap or add any indent.

        if child_opts["format"] == "verbatim"
          flush_pending(indent)
          emit_break(0) unless prev_child_is_text && !block_normalize
          set_block_break_type("element-break")
          add_to_doc(child["open_tag"] +
                    tree_stringify(child["content"]) +
                    child["close_tag"])
          next
        end

        # Inline elements:
        # - Do not break or indent.
        # - Do not line-wrap content; just add content to pending output
        #   and let it be wrapped as part of parent's content.

        if child_opts["format"] == "inline"
          add_to_pending(child["open_tag"])
          tree_format(child["name"], child["content"], indent)
          add_to_pending(child["close_tag"])
          next
        end

        # If we get here, node is a block element.

        # - Break and flush any pending output
        # - Break and indent (no indent if break count is zero)
        # - Process element itself:
        #   - Put out opening tag
        #   - Put out element content
        #   - Put out any indent needed before closing tag. None needed if:
        #     - Element's exit-break is 0 (closing tag is not on new line,
        #       so don't indent it)
        #     - There is no separate closing tag (it was in <abc/> format)
        #     - Element has no children (tags will be written as
        #       <abc></abc>, so don't indent closing tag)
        #     - Element has children, but the block is not normalized and
        #       the last child is a text node
        #   - Put out closing tag

        flush_pending(indent)
        emit_break(indent) unless prev_child_is_text && !block_normalize
        set_block_break_type("element-break")
        add_to_doc(child["open_tag"])
        tree_format(child["name"], child["content"], indent)
        unless child_opts["exit-break"] <= 0 ||
            child["close_tag"].empty? ||
            child["content"].empty? ||
            (!child["content"].empty? &&
              child["content"].last["type"] == "text" &&
              child_opts["normalize"] == "no")
          add_to_doc(" " * indent)
        end
        add_to_doc(child["close_tag"])
        next
      end

      # Comments, PIs, etc. (everything other than text and elements),
      # treat similarly to verbatim block:
      # - Flush any pending output
      # - Put out a break
      # - Add node content to collected output

      flush_pending(indent)
      emit_break(0) unless prev_child_is_text && !block_normalize
      set_block_break_type("element-break")
      add_to_doc(child["content"])

    end

    prev_child_is_text = cur_child_is_text

    # Done processing current element's children now.

    # If current element is a block element:
    # - If there were any children, flush any pending output and put
    #   out the exit break.
    # - Pop the block stack

    if par_opts["format"] == "block"
      if !children.empty?
        flush_pending(indent)
        set_block_break_type("exit-break")
        emit_break(0) unless prev_child_is_text && !block_normalize
      end
      end_block
    end

  end


  # Emit a break - the appropriate number of newlines according to the
  # enclosing block's current break type.

  # In addition, emit the number of spaces indicated by indent.  (indent
  # > 0 when breaking just before emitting an element tag that should
  # be indented within its parent element.)

  # Exception: Emit no indent if break count is zero. That indicates
  # any following output will be written on the same output line, not
  # indented on a new line.

  # Initially, when processing a node's child list, the break type is
  # set to entry-break. Each subsequent break is an element-break.
  # (After child list has been processed, an exit-break is produced as well.)

  def emit_break(indent)

    # number of newlines to emit
    break_value = block_break_value

    add_to_doc("\n" * break_value)
    # add indent if there *was* a break
    add_to_doc(" " * indent) if indent >0 && break_value > 0
  end
  private :emit_break


  # Flush pending output to output document collected thus far:
  # - Wrap pending contents as necessary, with indent before *each* line.
  # - Add pending text to output document (thus "flushing" it)
  # - Clear pending array.

  def flush_pending(indent)

    # Do nothing if nothing to flush
    return if @pending.empty?

    # If current block is not normalized:
    # - Text nodes cannot be modified (no wrapping or indent).  Flush
    #   text as is without adding a break or indent.
    # If current block is normalized:
    # - Add a break.
    # - If line wrap is disabled:
    #   - Add indent if there is a break. (If there isn't a break, text
    #     should immediately follow preceding tag, so don't add indent.)
    #   - Add text without wrapping
    # - If line wrap is enabled:
    #   - First line indent is 0 if there is no break. (Text immediately
    #     follows preceding tag.) Otherwise first line indent is same as
    #     prevailing indent.
    #   - Any subsequent lines get the prevailing indent.

    # After flushing text, advance break type to element-break.


    s = ""

    if !block_normalize
      s << @pending.join("")
    else
      emit_break(0)
      wrap_len = block_wrap_length
      break_value = block_break_value
      if wrap_len <= 0
        s << " " * indent if break_value > 0
        s << @pending.join("")
      else
        first_indent = (break_value > 0 ? indent : 0)
        # Wrap lines, then join by newlines (don't add one at end)
        s << line_wrap(@pending, first_indent, indent, wrap_len).join("\n")
      end
    end

    add_to_doc(s)
    @pending = [ ]
    set_block_break_type("element-break")
  end
  private :flush_pending


  # Perform line-wrapping of string array to lines no longer than given
  # length (including indent).
  # Any word longer than line length appears by itself on line.
  # Return array of lines (not newline-terminated).

  # strs - array of text items to be joined and line-wrapped.
  # Each item may be:
  # - A tag (such as <emphasis role="bold">). This should be treated as
  #   an atomic unit, which is important for preserving inline tags intact.
  # - A possibly multi-word string (such as "This is a string"). In this
  #   latter case, line-wrapping preserves internal whitespace in the
  #   string, with the exception that if whitespace would be placed at
  #   the end of a line, it is discarded.

  # first_indent - indent for first line
  # rest_indent - indent for any remaining lines
  # max_len - maximum length of output lines (including indent)
  
  def line_wrap(strs, first_indent, rest_indent, max_len)

    # First, tokenize the strings
    words = []
    strs.each do |str|
      if str =~ /\A</
        # String is a tag; treat as atomic unit and don't split
        words << str
      else
        # String of white and non-white tokens.
        # Tokenize into white and non-white tokens.
        str.scan(/\S+|\s+/).each { |word| words << word }
      end
    end

    # Now merge tokens that are not separated by whitespace tokens. For
    # example, "<i>", "word", "</i>" gets merged to "<i>word</i>".  But
    # "<i>", " ", "word", " ", "</i>" gets left as separate tokens.

    words2 = []
    words.each do |word|
      # If there is a previous word that does not end with whitespace,
      # and the currrent word does not begin with whitespace, concatenate
      # current word to previous word.  Otherwise append current word to
      # end of list of words.
      if words2.last && words2.last !~ /\s\z/ && word !~ /\A\s/
          words2.last << word
      else
          words2 << word
      end
    end

    lines = [ ]
    line = ""
    llen = 0
    # set the indent for the first line
    indent = first_indent
    # saved-up whitespace to put before next non-white word
    white = ""
  
    words2.each do |word|            # ... while words remain to wrap
      # If word is whitespace, save it. It gets added before next
      # word if no line-break occurs.
      if word =~ /\A\s/
        white << word
        next
      end
      wlen = word.size
      if llen == 0
        # New output line; it gets at least one word (discard any
        # saved whitespace)
        line = " " * indent + word
        llen = indent + wlen
        indent = rest_indent
        white = ""
        next
      end
      if llen + white.length + wlen > max_len
        # Word (plus saved whitespace) won't fit on current line.
        # Begin new line (discard any saved whitespace).
        lines << line
        line = " " * indent + word
        llen = indent + wlen
        indent = rest_indent
        white = ""
        next
      end
      # add word to current line with saved whitespace between
      line << white + word
      llen += white.length + wlen
      white = ""
    end
  
    # push remaining line, if any
    lines << line unless line.empty?
  
    return lines
  end
  private :line_wrap

end # class XMLFormatter

end # module XMLFormat

# ----------------------------------------------------------------------

# Begin main program

include XMLFormat

usage = "Usage: #{__dir__} #{PROG_NAME} [options] xml-file

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
--show-config
    Show configuration options after reading configuration
    file. This option suppresses document processing.
--show-unconfigured-elements
    Show elements that are used in the document but for
    which no options were specified in the configuration
    file. This option suppresses document output.
--verbose, -v
    Be verbose about processing stages.
--version, -V
    Show version information and exit.
"

help = false
backup_suffix = nil
conf_file = nil
canonize_only = false
check_parser = false
in_place = false
show_conf = false
show_unconf_elts = false
show_version = false
verbose = false

opts = GetoptLong.new(
  [ "--help",                       "-h", GetoptLong::NO_ARGUMENT ],
  [ "--backup",                     "-b", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--canonized-output",           "-o", GetoptLong::NO_ARGUMENT ],
  [ "--check-parser",               "-p", GetoptLong::NO_ARGUMENT ],
  [ "--config-file",                "-f", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--in-place",                   "-i", GetoptLong::NO_ARGUMENT ],
  [ "--show-config",                "-s", GetoptLong::NO_ARGUMENT ],
  # need better name
  [ "--show-unconfigured-elements", "-u", GetoptLong::NO_ARGUMENT ],
  [ "--verbose",                    "-v", GetoptLong::NO_ARGUMENT ],
  [ "--version",                    "-V", GetoptLong::NO_ARGUMENT ]
)

opts.each do |opt, arg|
  case opt
  when "--help"
    help = true
  when "--backup"
    backup_suffix = arg
  when "--canonized-output"
    canonize_only = true
  when "--check-parser"
    check_parser = true
  when "--config-file"
    conf_file = arg
  when "--in-place"
    in_place = true
  when "--show-config"
    show_conf = true
  when "--show-unconfigured-elements"
    show_unconf_elts = true
  when "--version"
    show_version = true
  when "--verbose"
    verbose = true
  else
    die "LOGIC ERROR: unhandled option: #{opt}\n"
  end
end

if help
  puts usage
  exit(0)
end

if show_version
  puts "#{PROG_NAME} #{PROG_VERSION} (#{PROG_LANG} version)"
  exit(0)
end

# --in-place option requires a named file

if in_place && ARGV.length == 0
  warn "WARNING: --in-place/-i option ignored (requires named input files)\n"
end

# --backup/-b is meaningless without --in-place

if backup_suffix
  unless in_place
    die "--backup/-b option meaningless without --in-place/-i option\n"
  end
end

# Save input filenames
#in_file = ARGV.dup

xf = XMLFormatter.new

env_conf_file = ENV["XMLFORMAT_CONF"]
def_conf_file = "#{__dir__}/xmlformat.conf"

# If no config file was named, but XMLFORMAT_CONF is set, use its value
# as the config file name.
if conf_file.nil? && !env_conf_file.nil?
  warn "No config file provided. Using envvar XMLFORMAT_CONF: "+env_conf_file 
  conf_file = env_conf_file
end

# If config file still isn't defined, use the default file if it exists.
if conf_file.nil?
  if FileTest.readable?(def_conf_file) && !FileTest.directory?(def_conf_file)
    warn "No config file provided. Defaulting to : "+def_conf_file 
    conf_file = def_conf_file
  end
end

if !conf_file.nil?
  warn "Reading configuration file #{conf_file}\n" if verbose
  if !FileTest.readable?(conf_file)
    die "Configuration file '#{conf_file}' is not readable.\n";
  end
  if FileTest.directory?(conf_file)
    die "Configuration file '#{conf_file}' is a directory.\n";
  end
  xf.read_config(conf_file)
end

if show_conf        # show configuration and exit
  xf.display_config
  exit(0)
end

# Process arguments.
# - If no files named, read string, write to stdout.
# - If files named, read and process each one. Write output to stdout
#   unless --in-place option was given.  Make backup of original file
#   if --backup option was given.

if ARGV.length == 0
  warn "Reading document...\n" if verbose
  in_doc = ""
  while gets; in_doc << $_; end

  out_doc = xf.process_doc(in_doc,
              verbose, check_parser, canonize_only, show_unconf_elts, 0)
  if !out_doc.nil?
    warn "Writing output document...\n" if verbose
    print out_doc
  end
else
  ARGV.each do |file|
    warn "Reading document #{file}...\n" if verbose
    in_doc = ""
    File.open(file, :encoding => 'utf-8') do |fh|
      fh.each_line do |line|
        in_doc << line
      end
    end
    out_doc = xf.process_doc(in_doc,
                verbose, check_parser, canonize_only, show_unconf_elts, 0)
    next if out_doc.nil?
    if in_place
      if backup_suffix
        warn "Making backup of #{file} to #{file}#{backup_suffix}...\n" if verbose
        File.rename(file, file + backup_suffix)
      end
      warn "Writing output document to #{file}...\n" if verbose
      File.open(file, "w") do |fh|
        fh.print out_doc
      end
    else
      warn "Writing output document...\n" if verbose
      print out_doc
    end
  end
end

warn "Done!\n" if verbose

exit(0)
