#!/bin/bash

# Parameters
script_folder=$(dirname "$0")
language="${XMLFORMAT_LANG:-pl}"
verbose_flag=0

while getopts l:f:vsuhoVp FLAG; do
  case $FLAG in
    l)
      language=$OPTARG #TODO: sanitize
      ;;
    f)
      cfg_file="$OPTARG"
      XMLFORMAT_ARGS="-$FLAG ${XMLFORMAT_ARGS}"
      ;;
    v) 
      (( verbose_flag++ ))
      ;;
    s|u|h|o|V|p)
      XMLFORMAT_ARGS="-$FLAG ${XMLFORMAT_ARGS}"
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -$OPTARG not allowed."
      ;;
  esac
done
shift $(($OPTIND - 1))

# Default configuration
if [ -z "$cfg_file" ] ; then
  cfg_file="${XMLFORMAT_CONF:-$script_folder/xmlformat.conf}" 
  XMLFORMAT_ARGS="-f $cfg_file ${XMLFORMAT_ARGS}"
fi

# Verbosity level
(( verbose_flag > 0)) && echo "Configuration file: $cfg_file"
(( verbose_flag > 1)) && XMLFORMAT_ARGS="-v ${XMLFORMAT_ARGS}"
(( verbose_flag > 1)) && echo "Format arguments: $XMLFORMAT_ARGS"
let errors=0
for inputfile in $@; do  
    (( verbose_flag > 0)) && echo "Formatting file: $inputfile"
    output=$($script_folder/xmlformat.$language $XMLFORMAT_ARGS -i $inputfile 2>&1)
    errorcode=$?
    if [[ $errorcode != 0 ]]; then
      echo "Error while formatting file $inputfile ($errorcode):"
      echo "$output"
      let errors+=1
    else 
      (( verbose_flag > 1)) && echo "$output"
    fi
    
done

if [[ $errors != 0 ]] ; then
  echo "Exitting with errors ($errors)"
  exit 1
fi

exit 0

