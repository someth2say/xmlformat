#! /bin/sh
#   shellcheck disable=SC2039

set +o posix

assertEqualsDiffCommandVsFile() {
    filenames="$1"
    lang="$2"
    echo "$lang($filenames) vs $filenames.formatted"
    if [ "$lang" == "java" ]; then
        output=$(diff "${filenames}.formatted" <(jbang ../bin/xmlformat.${lang} -f ${filenames}.conf ${filenames} ) )
    else
        output=$(diff "${filenames}.formatted" <(../bin/xmlformat.${lang} -f ${filenames}.conf ${filenames} ) )
    fi
    exitcode=$?
    assertEquals "File diff does not match: \n${output}\n" 0 "${exitcode}"
}

assertEqualsDiffCommandVsCommand() {
    filenames="$1"
    lang1="$2"
    lang2="$3"
    if [ "$lang1" == "java" ]; then
        output=$(diff <( jbang ../bin/xmlformat.${lang1} -f ${filenames}.conf ${filenames} ) <( ../bin/xmlformat.${lang2} -f ${filenames}.conf ${filenames} ) )
    else 
        if [ "$lang2" == "java" ]; then
            output=$(diff <( ../bin/xmlformat.${lang1} -f ${filenames}.conf ${filenames} ) <( jbang ../bin/xmlformat.${lang2} -f ${filenames}.conf ${filenames} ) )
        else
            output=$(diff <( ../bin/xmlformat.${lang1} -f ${filenames}.conf ${filenames} ) <( ../bin/xmlformat.${lang2} -f ${filenames}.conf ${filenames} ) )
        fi
    fi
    exitcode=$?
    assertEquals "Command diff does not match: \n${output}\n" 0 "${exitcode}"
}


assertEqualsMultipleCommandsVsCommand(){
    XML_FILE="$1"
    shift
    for a; do
        shift
        for b; do
            printf "%s - %s: %s\n" "$a" "$b" "$XML_FILE"
            assertEqualsDiffCommandVsCommand "$XML_FILE" "$a" "$b" 
        done
    done
}

assertEqualsMultipleCommandsVsFile(){
    XML_FILE="$1"
    shift
    for i in "$@"
    do
        assertEqualsDiffCommandVsFile "${XML_FILE}" "$i" || exit 1;
    done
}

########################################################

test_length_wrap(){
    assertEqualsMultipleCommandsVsFile "wrap/length_wrap.sgml" "pl" "rb" "java"
}

test_sentence_wrap() {
    assertEqualsMultipleCommandsVsFile "wrap/sentence_wrap.sgml" "pl" "rb" "java"
}

test_length_wrap() {
    assertEqualsMultipleCommandsVsFile "wrap/length_wrap.sgml" "pl" "rb" "java"
}

test_none_wrap() {
    assertEqualsMultipleCommandsVsFile "wrap/none_wrap.sgml" "pl" "rb" "java"
}

test_both_length_wrap() {
    assertEqualsMultipleCommandsVsCommand "wrap/length_wrap.sgml" "pl" "rb" "java"
}

test_both_none_wrap() {
    assertEqualsMultipleCommandsVsCommand "wrap/none_wrap.sgml"  "pl" "rb" "java"
}

test_both_sentence_wrap() {
    assertEqualsMultipleCommandsVsCommand "wrap/sentence_wrap.sgml" "pl" "rb" "java"
}

test_big_file(){
    assertEqualsMultipleCommandsVsFile "big/howto.xml" "pl" "rb" "java"
}

test_missing_close(){
    true
}

# shellcheck source=shunit2
. ./shunit2