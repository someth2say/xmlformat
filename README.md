# Overview
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-4-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->
A pre-commit hook that applies formatting to XML files.
Based on the formatter by Kitebird (http://www.kitebird.com/software/xmlformat/).
A copy of the original documentation is kept at [here](https://github.com/someth2say/xmlformat/blob/master/docs.md).

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
* `java` (through Jbang)

`perl`,`ruby` and `java` will execute the language-based version of the formatter. `podman` or `docker` will use the appropriate container runtime to execute the latest container at quay.io/someth2say/xmlformat:latest.

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
    rev: 0.5
    hooks:
      - id: xmlformat
```

The same way as you can do with the `bin/xmlformat.sh`, you can select your runtime and many other option by passing hook arguments:

```
repos:
  - repo: https://github.com/someth2say/xmlformat
    rev: 0.5
    hooks:
      - id: xmlformat
        args: ["-i","-l","java"]

```
> :warning: If you provide `args` to your hook reference, then always provide the `-i` argument to make sure your files are updated. Else, the files will not be modified, and the hook will never fail.

If the only argument you are passing is the language, you can alternatively use the pre-defined hooks: `xmlformat_ruby`, `xmlformat_perl`, `xmlformat_java`, `xmlformat_podman`, and `xmlformat_docker`

# Configuration format
The default formatting rules applied by `XMLFormat` are highly opinionated, and target the DocBook XML format.

You can create your own formatting rules in a configuration file and passing it to the formatter. The format of the configuration file is based on the format described [here](https://github.com/someth2say/xmlformat/blob/master/docs.md), with the following additions:

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
  wrap-type = sentence
```

> :information_source: The `*DEFAULT` entry in a configuration file applies the formatting settings to all tags.

Once you have the configuration ready, use the `-f` option to provide the file to the formatter:

```
# bin/xmlformat.sh -f myconfig.conf test/test_base.xml
```

# Configuration sources
XMLFormat will look for configuration files in the following order:

1) If the `-f` option is provided, then the parameter file will be used. If the file do not exist or is not readable, then the program will exit.
2) Else, it looks the file in the `XMLFORMAT_CONF` environment variable, or for a `xmlformat.conf` file in the `XMLFORMAT_CONF` folder.
3) Else, it looks the file in the `XDG_CONFIG_HOME` environment variable, or for a `xmlformat.conf` file in the `XDG_CONFIG_HOME` folder.
4) Else, it looks for a `xmlformat.conf` file in the current folder (pwd).
5) Else, it defaults to the embedded configuration.
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

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="https://github.com/tomschr"><img src="https://avatars.githubusercontent.com/u/1312925?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Tom Schraitle</b></sub></a><br /><a href="#maintenance-tomschr" title="Maintenance">🚧</a></td>
    <td align="center"><a href="https://github.com/tbazant"><img src="https://avatars.githubusercontent.com/u/2240174?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Tomáš Bažant</b></sub></a><br /><a href="https://github.com/someth2say/xmlformat/commits?author=tbazant" title="Code">💻</a> <a href="#design-tbazant" title="Design">🎨</a></td>
    <td align="center"><a href="https://github.com/dkolepp"><img src="https://avatars.githubusercontent.com/u/10145457?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Dan Kolepp</b></sub></a><br /><a href="https://github.com/someth2say/xmlformat/commits?author=dkolepp" title="Tests">⚠️</a></td>
    <td align="center"><a href="https://sknorr.codeberg.page"><img src="https://avatars.githubusercontent.com/u/5476547?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Stefan Knorr</b></sub></a><br /><a href="https://github.com/someth2say/xmlformat/commits?author=sknorr" title="Documentation">📖</a></td>
  </tr>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
