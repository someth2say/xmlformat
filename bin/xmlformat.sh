#!/bin/bash
# Parameters
script_folder=$(dirname "$0")
language="${XMLFORMAT_LANG:-pl}"
cfg_flag="-f ${XMLFORMAT_CONF:-$script_folder/xmlformat.conf}"

while getopts l:c: FLAG; do
  case $FLAG in
    l)
      language=$OPTARG #TODO: sanitize
      ;;
    c)
      cfg_flag="-f $OPTARG"
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -$OPTARG not allowed."
      ;;
  esac
done
shift $(($OPTIND - 1))

let errors=0
for inputfile in $@; do  
    # echo "Formatting file: $inputfile ($cfg_flag)"
    output="$($script_folder/xmlformat.$language $cfg_flag $XMLFORMAT_EXTRA_ARGS -i $inputfile)"
    errorcode=$?
    if [[ $errorcode != 0 ]]; then
      echo "Unable to format file $inputfile ($errorcode):"
      echo " - $output"
      let errors+=1
    fi
done

if [[ $errors != 0 ]] ; then
  echo "Exitting with errors ($errors)"
  exit 1
fi

exit 0