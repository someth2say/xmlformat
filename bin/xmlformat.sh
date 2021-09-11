#!/bin/bash

function has() {
  #curl -sL https://git.io/_has | bash -s $1
  "$script_folder"/has.sh "$1"
  if [ "$?" == "0" ]; then
    language=$1
    return 0
  fi
 return 1;
}

function autoDetectLang() {
  echo "Starting language autodetection."
  has "perl" || has "ruby" || has "podman" ||  has "docker" || (echo "Unable to detect a supported language. Defaulting to Java (through JBang)"; language="java")
}

# Parameters
script_folder=$(dirname "$0")
language="${XMLFORMAT_LANG}"
verbose_flag=0

while getopts "l:f:vsuhoVpi" FLAG; do
  case $FLAG in
    l)
      language=$OPTARG #TODO: sanitize
      ;;
    f)
      cfg_file="$OPTARG"
      [ -z "$cfg_file" ] && (echo "Unable to reach configuration file: $OPTARG" ; exit 4 )
      XMLFORMAT_ARGS="-$FLAG ${XMLFORMAT_ARGS}"
      ;;
    v) 
      (( verbose_flag++ ))
      ;;
    s|u|h|o|V|p)
      XMLFORMAT_ARGS="-$FLAG ${XMLFORMAT_ARGS}"
      ;;
    * ) # unrecognized option - send down
      XMLFORMAT_ARGS="-$FLAG $OPTARG ${XMLFORMAT_ARGS}"
      ;;
  esac
done
shift $(($OPTIND - 1))

## Main #######

# If language not set by parameter, run language autodetection.
[ -z "$language" ] && autoDetectLang

# Default configuration
if [ -z "$cfg_file" ] ; then
  cfg_file="${XMLFORMAT_CONF:-$script_folder/xmlformat.conf}" 
  XMLFORMAT_ARGS="-f $cfg_file ${XMLFORMAT_ARGS}"
fi

# Logging before formating
(( verbose_flag > 0)) && echo "Configuration file: $cfg_file"
(( verbose_flag > 1)) && XMLFORMAT_ARGS="-v ${XMLFORMAT_ARGS}"
(( verbose_flag > 1)) && echo "Format arguments: $XMLFORMAT_ARGS"
(( verbose_flag > 1)) && echo "Language: $language"

(( errors=0 ))
if [ "$language" == "java" ]; then
  # shellcheck disable=SC2068,SC2086
  SCRIPT_OUTPUT=$("$script_folder/jbang" "$script_folder/xmlformat.$language" $XMLFORMAT_ARGS $@)
else
  # shellcheck disable=SC2068,SC2086
  SCRIPT_OUTPUT=$("$script_folder/xmlformat.$language" $XMLFORMAT_ARGS $@)
fi

errorcode=$?
echo "$SCRIPT_OUTPUT"

if [[ $errorcode != 0 ]]; then
  echo "Error while formatting files ($errorcode):"
  (( errors+=1 ))
else 
  (( verbose_flag > 0)) && echo "Formatting complete."
fi

if [[ $errors != 0 ]] ; then
  (( verbose_flag > 0)) && echo "Exitting with errors ($errors)"
  exit 1
fi

exit 0

