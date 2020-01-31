# Overview
A pre-commit hook that applies formatting to XML files

Comes in three flavors:

## xmlformat_perl
Perl version. Requires perl interpreter installed.

**Sample**
```
- id: xmlformat_perl
  args: ["-v"]
  types: [xml]
```

## xmlformat_ruby
Ruby version. Requires ruby interpreter installed.

**Sample**
```
- id: xmlformat_ruby
  args: ["-s"]
  types: [xml]
```


## xmlformat_docker
Containerized version. Requires docker (podman not supported yet).
Unlike other versions, this one accepts no arguments.

**Sample**
```
- id: xmlformat_docker
  types: [xml]
```

# Arguments
* `-f [config_file]`: Sets the XML format configuration file to use.
**Absolute paths must be used.**
* `-s` : Dumps configuration to be used and exits.

*  `-u` : List XML tags with no explicit entry in configuration file. `*DEFAULT` configuration block will be used for those elements.

* `-o` : Canonize output. Skips line-wrapping, indentation and line-break additions.

* `-v` : Increases verbosity level. Once, file progress is shown. Twice, formatting progress for each file is shown.

* `-p` : Parses the XML documents, but applies not format.
