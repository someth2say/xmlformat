#! /bin/sh
#   shellcheck disable=SC2039

set +o posix

assertDiffCommandVsFile() {
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

assertDiffCommandVsCommand() {
    filenames="$1"
    lang1="$2"
    lang2="$3"
    output=$(diff <( ../bin/xmlformat.${lang1} -f ${filenames}.conf ${filenames} ) <( ../bin/xmlformat.${lang2} -f ${filenames}.conf ${filenames} ) )
    exitcode=$?
    assertEquals "Command diff does not match: \n${output}\n" 0 "${exitcode}"
}


assertMultipleCommandsVsCommand(){
    XML_FILE="$1"
    shift
    for a; do
        shift
        for b; do
            printf "%s - %s: %s\n" "$a" "$b" "$XML_FILE"
            assertDiffCommandVsCommand "$XML_FILE" "$a" "$b" 
        done
    done
}

assertMultipleCommandsVsFile(){
    XML_FILE="$1"
    shift
    for i in "$@"
    do
        assertDiffCommandVsFile "${XML_FILE}" "$i" || exit 1;
    done
}

########################################################

test_length_wrap(){
    assertMultipleCommandsVsFile "wrap/length_wrap.sgml" "pl" "rb" "java"
}

test_sentence_wrap() {
    assertMultipleCommandsVsFile "wrap/sentence_wrap.sgml" "pl" "rb" "java"
}

test_length_wrap() {
    assertMultipleCommandsVsFile "wrap/length_wrap.sgml" "pl" "rb" "java"
}

test_none_wrap() {
    assertMultipleCommandsVsFile "wrap/none_wrap.sgml" "pl" "rb" "java"
}

test_both_length_wrap() {
    assertMultipleCommandsVsCommand "wrap/length_wrap.sgml" "pl" "rb" "java"
}

test_both_none_wrap() {
    assertMultipleCommandsVsCommand "wrap/none_wrap.sgml"  "pl" "rb" "java"
}

test_both_sentence_wrap() {
    assertMultipleCommandsVsCommand "wrap/sentence_wrap.sgml" "pl" "rb" "java"
}

test_big_file(){
    assertMultipleCommandsVsFile "big/howto.xml" "pl" "rb" "java"
}

# shellcheck source=shunit2
. ./shunit2