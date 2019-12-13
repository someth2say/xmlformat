#!/bin/sh

result=$(./forbidden-files.sh)
exitcode=$?
if [ $? -ne 0 ]; then
  echo "Failed test when no files provided ($exitcode)."
  echo "Output:"
  echo $result
  echo
  exit 1
fi

result=$(./forbidden-files.sh test.txt test2.txt)

if [ $? -eq 0 ]; then
  echo "Failed test when files provided  ($exitcode)."
  echo "Output:"
  echo $result
  echo
  exit 1
fi

echo "All tests passed."
exit 0