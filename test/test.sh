#! /bin/sh
#   shellcheck disable=SC2039

set +o posix

assertDiffCommandVsFile() {
    filenames="$1"
    lang="$2"
    output=$(diff "${filenames}.formatted" <( perl ../bin/xmlformat.${lang} -f ${filenames}.conf ${filenames} ) )
    exitcode=$?
    assertEquals "File diff does not match: \n${output}\n" 0 "${exitcode}"
}

assertDiffCommandVsCommand() {
    filenames="$1"
    output=$(diff <( ruby ../bin/xmlformat.rb -f ${filenames}.conf ${filenames} ) <( perl ../bin/xmlformat.pl -f ${filenames}.conf ${filenames} ) )
    exitcode=$?
    assertEquals "Command diff does not match: \n${output}\n" 0 "${exitcode}"
}

test_pl_length_wrap() {
    assertDiffCommandVsFile "wrap/length_wrap.sgml" "pl"
}

test_pl_none_wrap() {
    assertDiffCommandVsFile "wrap/none_wrap.sgml" "pl"
}

test_pl_sentence_wrap() {
    assertDiffCommandVsFile "wrap/sentence_wrap.sgml" "pl"
}

test_pl_wrap_only_normalized() {
    assertDiffCommandVsFile "wrap/00014-wrap_only_normalized.sgml" "pl"
}

test_rb_length_wrap() {
    assertDiffCommandVsFile "wrap/length_wrap.sgml" "rb"
}

test_rb_none_wrap() {
    assertDiffCommandVsFile "wrap/none_wrap.sgml" "rb"
}

test_rb_sentence_wrap() {
    assertDiffCommandVsFile "wrap/sentence_wrap.sgml" "rb"
}

test_rb_wrap_only_normalized() {
    assertDiffCommandVsFile "wrap/00014-wrap_only_normalized.sgml" "rb"
}

test_both_length_wrap() {
    assertDiffCommandVsCommand "wrap/length_wrap.sgml" 
}

test_both_none_wrap() {
    assertDiffCommandVsCommand "wrap/none_wrap.sgml" 
}

test_both_sentence_wrap() {
    assertDiffCommandVsCommand "wrap/sentence_wrap.sgml"
}

test_wrap_only_normalized() {
    assertDiffCommandVsCommand "wrap/00014-wrap_only_normalized.sgml" 
}

# shellcheck source=shunit2
. ./shunit2