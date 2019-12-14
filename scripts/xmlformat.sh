#!/bin/bash
let errors=0
for inputfile in $*; do  
    echo "Formatting file: $inputfile"
    output="$($XMLFORMAT_SCRIPTS_DIR/xmlformat.pl -f $XMLFORMAT_CFG_FILE $XMLFORMAT_EXTRA_ARGS $inputfile)"
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