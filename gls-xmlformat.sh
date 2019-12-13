#!/bin/bash

for inputfile in $*; do  
    echo "Formatting $inputfile"
    output=`./xmlformat.pl -i -f ./xmlformat.cfg $inputfile`
    errorcode = $?
    if [$errorcode -ne 0]; then
      echo "ERROR: unable to format $inputfile ($errorcode)"
      echo $output
      echo
      let errors+=1
    fi 
done

exit $errors