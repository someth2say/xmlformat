# Overview
A pre-commit hook that applies formatting to XML files.
Based on the formatter by Kitebird (http://www.kitebird.com/software/xmlformat/).
A copy of the original documentation is kept at [here](https://github.com/someth2say/xmlformat/blob/master/The%20xmlformat%20XML%20Document%20Formatter.html).

## Description
XML formatting should not be strict.
Many environments require special rules to format their XML documents.
This tool allow those environments to programmatically define their own formatting rules, controlling the formatting applied to different XML tags.


## Usage
You can use this application in multiple ways, both standalone, containerized or as a [pre-commit](https://pre-commit.com/) hook.

### Standalone
The most basic usage goes through downloading the [latest release](https://github.com/someth2say/xmlformat/releases) of the application, unzipping it, and run the `bin/xmlformat.sh` script.
For example, for getting command help you can do:

```
# bin/xmlformat.sh -h
```

> :warning: Currently only short parameters are supported.

For displaying the formatted output, just pass the XML file name to the script

```
# bin/xmlformat.sh test/test_base.xml
```

### Supported languages
The default version of the `xmlformat.sh` script tries to autodetect the language interpreter available in your system.

`XMLFormat` comes with three different implementations, so you can choose the one better fitting your infrastructure.
To be precise, it tries the following runnable commands:
* `perl`
* `ruby`
* `podman`
* `docker`

The two further will execute the language-based version of the formatter. The two later will use `podman` or `docker` container runtimes to execute the latest container at quay.io/someth2say/xmlformat:latest. 

> :information_source: The containerized versions will *always* execute the ruby version of the application inside the container.

If you have an special need to override this behaviour, you can use the `-l` option to force the language to be used.

```
# bin/xmlformat.sh -l perl test/test_base.xml
```

> :information_source: You can also use `pl` for `perl` and `rb` for `ruby`.

### Pre-commit hook
`XMLFormat` can also be used with [pre-commit](https://pre-commit.com/) in order to format your XML files before sending them to the repo.

Just add the hook reference to your `.pre-commit-config.yaml` file:

```
repos:
  - repo: https://github.com/someth2say/xmlformat
    rev: 0.4
    hooks:
      - id: xmlformat
```
The same way as you can do with the `bin/xmlformat.sh`, you can select your runtime and many other option by passing hook arguments:

```
repos:
  - repo: https://github.com/someth2say/xmlformat
    rev: 0.4
    hooks:
      - id: xmlformat
        args: ["-i","-l","podman"]

```
> :warning: If you provide `args` to your hook reference, then always provide the `-i` argument to make sure your files are updated. Else, the files will not be modified, and the hook will never fail.

If the only argument you are passing is the language, you can alternatively use the pre-defined hooks: `xmlformat_ruby`, `xmlformat_perl`, `xmlformat_podman`, and `xmlformat_docker`

# Configuration
The default formatting rules applied by `XMLFormat` are highly opinionated, and target the DocBook XML format.

You can create your own formatting rules in a configuration file and passing it to the formatter. The format of the configuration file is based on the format described [here](https://github.com/someth2say/xmlformat/blob/master/The%20xmlformat%20XML%20Document%20Formatter.html), with the following additions:

* The `wrap-type` attribute controls how the content of a text node is wrapped. This attribute accepts three values: `length`, `sentence` and `none`.
    * `length` makes sure lines are not longer than a fixed length. The length of the lines is controlled by the `wrap-length` attribute.
    * `sentence` splits the contents in one sentence per line. Sentence ends are identified by the `.`, `?` and `!` characters.
    * `none` means no line wrapp applies, so all the content of the node will be contiguous.
  In all cases, words are never wrapped.

A sample configuration entry follows:
```
para
  entry-break = 1
  subindent = 2
  normalize = yes
```

> :information_source: The `*DEFAULT` entry in a configuration file applies the formatting settings to all tags.

Once you have the configuration ready, use the `-f` option to provide the file to the formatter:


```
# bin/xmlformat.sh -f myconfig.conf test/test_base.xml
```


# Arguments
The following arguments are accepted by `XMLFormat`:
* `-l [lang]`: Sets the execution language or container infrastructure

* `-h`: Shows a help message.

* `-f [config_file]`: Sets the XML format configuration file to use.
**Absolute paths must be used.**

* `-s`: Dumps configuration to be used and exits.

* `-u`: List XML tags with no explicit entry in configuration file. `*DEFAULT` configuration block will be used for those elements.

* `-o`: Canonize output. Skips line-wrapping, indentation and line-break additions.

* `-v`: Increases verbosity level. Once, file progress is shown. Twice, formatting progress for each file is shown.

* `-V`: Shows the *underlying* script version and exits.

* `-p`: Parses the XML documents, but applies not format.

* `-i`: Format the document in place, replacing the contents of the input file with the reformatted document. If not provided, formatted results are sent to standard output.
