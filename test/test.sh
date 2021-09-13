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
    #  TODO: USE BUILT COMMANDS
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

    for i in "${langs[@]}"; do
        local CMD
        buildCommandInto CMD "$XML_FILE" "$i" "$configFile"
        assertEqualsDiffCommandVsFile "$CMD" "${XML_FILE}.formatted" || exit 1;
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

# Test 0: no-config source defined -> default config
test_no_confg_source() {
   pushd config/folder_without_config || fail "$@"
   assertEqualsMultipleCommandsVsFile "test_base.xml" "" "pl rb java"
   popd || fail "$@"
}

# Test 1: Parameter over default config

# Test 2: local over parameter and default config

# Test 3: XDG_CONFIG_HOME over local config, parameter and default config

# Test 4: XMLFORMAT_CONF over XDG_CONFIG_HOME, local, parameter and default config



# Source test sub-modules
source config/test.sh

# shellcheck source=shunit2
. ./shunit2
