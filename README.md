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

**Testing**
```
  bin/xmlformat.pl sentence_wrap.sgml
```
or
```
  bin/xmlformat.sh pl sentence_wrap.sgml
```

## xmlformat_ruby
Ruby version. Requires ruby interpreter installed.

**Sample**
```
- id: xmlformat_ruby
  args: ["-s"]
  types: [xml]
```

**Testing**
````
  bin/xmlformat.rb sentence_wrap.sgml
```
or
```
  bin/xmlformat.sh rb sentence_wrap.sgml
```
## xmlformat_docker
Containerized version. Requires docker (podman not supported yet).
Unlike other versions, this one accepts no arguments.

**Sample**
```
- id: xmlformat_docker
  types: [xml]
```

**Testing**
```
    podman run -v ./test:/tmp:z --rm -it quay.io/someth2say/xmlformat:0.4 /tmp/sentence_wrap.sgml
```
### Build image
```
  podman build -t quay.io/someth2say/xmlformat:0.4 .
```

# Arguments
* `-f [config_file]`: Sets the XML format configuration file to use.
**Absolute paths must be used.**
* `-s` : Dumps configuration to be used and exits.

*  `-u` : List XML tags with no explicit entry in configuration file. `*DEFAULT` configuration block will be used for those elements.

* `-o` : Canonize output. Skips line-wrapping, indentation and line-break additions.

* `-v` : Increases verbosity level. Once, file progress is shown. Twice, formatting progress for each file is shown.

* `-p` : Parses the XML documents, but applies not format.
