#! /bin/bash

set +o posix
set -u

TEST_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
BIN_PATH="${TEST_PATH}/../bin"

buildCommandInto(){
    local INTO=$1
    local filename=$2
    local lang=$3
    local configFile=$4

    local COMMAND
    if [ "$lang" == "java" ]; then
        COMMAND="jbang ${BIN_PATH}/xmlformat.${lang}"
    else
        COMMAND="${BIN_PATH}/xmlformat.${lang}"
    fi

    local EXTRAS
    [ -n "$configFile" ] && EXTRAS=" -f ${configFile}"

    eval "${INTO}=\"$COMMAND $EXTRAS $filename\""
}

assertEqualsDiffCommandVsFile() {
    local cmd="$1"
    local file="$2"
    echo Diffing \"$cmd\" vs \"$file\"
    output=$(diff "$file" <($cmd) )
    exitcode=$?
    assertEquals "File diff does not match: \n${output}\n" 0 "${exitcode}"
}

assertEqualsDiffCommandVsCommand() {
    local CMD1="$1"
    local CMD2="$2"

    local output
    echo Diffing \"$CMD1\" vs \"$CMD2\"

    output=$(diff <($CMD1) <($CMD2))
    exitcode=$?
    assertEquals "Command diff does not match: \n${output}\n" 0 "${exitcode}"
}


assertEqualsMultipleCommandsVsCommand(){
    local XML_FILE="$1"
    local configFile="$2"
    local langs
    IFS=" " read -r -a langs <<< "$3"

    for((i=0;i<${#langs[@]}-1;++i)); do
        local CMDA
        buildCommandInto CMDA "$XML_FILE" "${langs[i]}" "$configFile"

        for((j=i+1;j<${#langs[@]};++j)); do
            local CMDB
            buildCommandInto CMDB "$XML_FILE" "${langs[j]}" "$configFile"

            assertEqualsDiffCommandVsCommand "$CMDA" "$CMDB"

        done
    done
}

assertEqualsMultipleCommandsVsFile(){
    local XML_FILE="$1"
    local configFile="$2"
    local langs
    IFS=" " read -r -a langs <<< "$3"
    local formattedFile="${4:-${XML_FILE}.formatted}"

    for i in "${langs[@]}"; do
        local CMD
        buildCommandInto CMD "$XML_FILE" "$i" "$configFile"
        assertEqualsDiffCommandVsFile "$CMD" "$formattedFile" || exit 1;
    done
}

########################################################

test_length_wrap(){
    assertEqualsMultipleCommandsVsFile "wrap/length_wrap.sgml" "wrap/length_wrap.sgml.conf" "pl rb java"
}

test_sentence_wrap() {
    assertEqualsMultipleCommandsVsFile "wrap/sentence_wrap.sgml" "wrap/sentence_wrap.sgml.conf" "pl rb java"
}

test_length_wrap() {
    assertEqualsMultipleCommandsVsFile "wrap/length_wrap.sgml" "wrap/length_wrap.sgml.conf" "pl rb java"
}

test_none_wrap() {
    assertEqualsMultipleCommandsVsFile "wrap/none_wrap.sgml" "wrap/none_wrap.sgml.conf" "pl rb java"
}

test_both_length_wrap() {
    assertEqualsMultipleCommandsVsCommand "wrap/length_wrap.sgml" "wrap/length_wrap.sgml.conf"  "pl rb java"
}

test_both_none_wrap() {
    assertEqualsMultipleCommandsVsCommand "wrap/none_wrap.sgml" "wrap/none_wrap.sgml.conf" "pl rb java"
}

test_both_sentence_wrap() {
    assertEqualsMultipleCommandsVsCommand "wrap/sentence_wrap.sgml" "wrap/sentence_wrap.sgml.conf" "pl rb java"
}

test_big_file(){
    assertEqualsMultipleCommandsVsFile "big/howto.xml" "big/howto.xml.conf" "pl rb java"
}

#test_missing_close(){
    # TODO
#}

# Config

# Test 0: no-config source defined -> default config
test_config_default() {
   assertEqualsMultipleCommandsVsFile "test_base.xml" "" "pl rb java" "test_base.xml.formatted"
}

# Test 2: local over default config
test_config_local() {
   pushd test_base || fail "$@"
   assertEqualsMultipleCommandsVsFile "test_base.xml" "" "pl rb java"  "test_base.local.xml.formatted"
   popd || fail "$@"
}

# Test 3: XDG_CONFIG_HOME over local config and default config
test_config_xdg() {
   pushd test_base || fail "$@"
   export XDG_CONFIG_HOME=test_base.length.conf
   assertEqualsMultipleCommandsVsFile "test_base.xml" "" "pl rb java" "test_base.lenght.xml.formatted"
   unset XDG_CONFIG_HOME
   popd || fail "$@"
}

# Test 4: XMLFORMAT_CONF over XDG_CONFIG_HOME, local and default config
test_config_env() {
   pushd test_base || fail "$@"
   export XDG_CONFIG_HOME=test_base.length.conf
   export XMLFORMAT_CONF=test_base.sentence.conf
   assertEqualsMultipleCommandsVsFile "test_base.xml" "" "pl rb java" "test_base.sentence.xml.formatted"
   unset XDG_CONFIG_HOME
   popd || fail "$@"
}

# Test 1: Parameter over everything else
test_config_param() {
   pushd test_base || fail "$@"
   assertEqualsMultipleCommandsVsFile "test_base.xml" "test_base.length.conf" "pl rb java" "test_base.lenght.xml.formatted"
   popd || fail "$@"
}

# shellcheck source=shunit2
. ./shunit2
