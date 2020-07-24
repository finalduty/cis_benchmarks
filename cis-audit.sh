#!/usr/bin/env bash
#shellcheck disable=SC2000,SC2181
## https://github.com/finalduty/cis_benchmarks_audit [rev: c0a2487]

##
## Copyright 2020 Andy Dustin
##
## Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except 
## in compliance with the License. You may obtain a copy of the License at
##
## http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software distributed under the License is 
## distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and limitations under the License.
##

## This script checks for compliance against CIS Benchmarks.
## Each individual standard has it's own function and is forked to the background, allowing for 
## multiple tests to be run in parallel, reducing execution time.

## You can obtain a copy of the CIS Benchmarks from https://www.cisecurity.org/cis-benchmarks/

## Thanks to these projects which has helped the development of this tool:
## https://github.com/koalaman/shellcheck/wiki
## https://github.com/shellspec/shellspec



### Variables ###
## This section defines global variables used in the script

ARGS="$*"
COLOURIZE=True
DEBUG=False
#EXECUTE=True
EXIT_CODE=0
FILE_BASE="/tmp/.cis_audit-$(date +%y%m%d%H%M%S)"
FILE_COUNTER_FINISHED="$FILE_BASE/finished"
FILE_COUNTER_STARTED="$FILE_BASE/started"
FILE_OUTPUT="$FILE_BASE/output"
FILE_STATUS="$FILE_BASE/status"
ME=$(basename "$0")
PROGRESS_UPDATE_DELAY="0.1"
RENICE=True
RENICE_VALUE=5
RUNNING_TESTS_MAX=10
TEST_LEVEL=0
TIME_START=$(date +%s)
TRACE=False
WAIT_TIME="0.25"

## Detect if we're running inside the test suite
#[ "$SHELLSPEC_VERSION" != "" ] && EXECUTE="False"

## Deprecated global variables
#count=0
#result=Fail
#state=0


### Functions ###
## This section defines functions used in the script 
is_test_included() {
    id=$1
    level=$2
    state=0
    
    [ -z "$level" ] && level="$TEST_LEVEL"
    
    ## Check if the $level is one we're going to run
    if [ "$TEST_LEVEL" -ne 0 ]; then
        if [ "$TEST_LEVEL" != "$level" ]; then
            write_debug "Excluding level $level test $id"
            state=1
        fi
    fi
    
    ## Check if there were explicitly included tests
    if [ "$(echo "$include" | wc -c )" -gt 3 ]; then
        
        ## Check if the $id is in the included tests
        if [ "$(echo " $include " | grep -c " $id ")" -gt 0 ]; then
            write_debug "Test $id was explicitly included"
            state=0
        elif [ "$(echo " $include " | grep -c " $id\.")" -gt 0 ]; then
            write_debug "Test $id is the parent of an included test"
            state=0
        elif [ "$(for i in $include; do echo " $id" | grep " $i\."; done | wc -l)" -gt 0 ]; then
            write_debug "Test $id is the child of an included test"
            state=0
        elif [ "$TEST_LEVEL" == 0 ]; then
            write_debug "Excluding test $id (Not found in the include list)"
            state=1
        fi
    fi
    
    ## If this $id was included in the tests check it wasn't then excluded
    if [ "$(echo " $exclude " | grep -c " $id ")" -gt 0 ]; then
        write_debug "Excluding test $id (Found in the exclude list)"
        state=1
    elif [ "$(for i in $exclude; do echo " $id" | grep " $i\."; done | wc -l)" -gt 0 ]; then
        write_debug "Excluding test $id (Parent found in the exclude list)"
        state=1
    fi
    
    [ $state -eq 0 ] && write_debug "Including test $id"
    
    #return $state
    echo $state
} ## Checks whether to run a particular test or not
help_text() {
    cat  << EOF |fmt -sw99
This script runs tests on the system to check for compliance against the CIS CentOS 7 Benchmarks.
No changes are made to system files by this script.

  Options:
EOF

    cat << EOF | column -t -s'|'
||-h,|--help|Prints this help text
|||--debug|Run script with debug output turned on
|||--level (1,2)|Run tests for the specified level only
|||--include "<test_ids>"|Space delimited list of tests to include
|||--exclude "<test_ids>"|Space delimited list of tests to exclude
|||--nice |Lower the CPU priority for test execution. This is the default behaviour.
|||--no-nice|Do not lower CPU priority for test execution. This may make the tests complete faster but at 
||||the cost of putting a higher load on the server. Setting this overrides the --nice option.
|||--no-colour|Disable colouring for STDOUT. Output redirected to a file/pipe is never coloured.

EOF

    cat << EOF

  Examples:
  
    Run with debug enabled:
      $ME --debug
      
    Exclude tests from section 1.1 and 1.3.2:
      $ME --exclude "1.1 1.3.2"
      
    Include tests only from section 4.1 but exclude tests from section 4.1.1:
      $ME --include 4.1 --exclude 4.1.1
    
    Run only level 1 tests
      $ME --level 1
    
    Run level 1 tests and include some but not all SELinux questions
      $ME --level 1 --include 1.6 --exclude 1.6.1.2

EOF

exit 0

} ## Outputs help text
now() {
    echo $(( $(date +%s%N) / 1000000 ))
} ## Short function to give standardised time for right now (saves updating the date method everywhere)
outputter() {
    write_debug "Formatting and writing results to STDOUT"
    echo
    echo " CIS CentOS 7 Benchmark v3.0.0 Results "
    echo "---------------------------------------"
    
    if [ -t 1 ] && [ "$COLOURIZE" == "True" ]; then
        (
            echo "ID,Description,Scoring,Level,Result,Duration"
            echo "--,-----------,-------,-----,------,--------"
            sort -V "$FILE_OUTPUT"
        ) | column -t -s , |\
            sed -e $'s/^[0-9]\s.*$/\\n\e[1m&\e[22m/' \
                -e $'s/^[0-9]\.[0-9]\s.*$/\e[1m&\e[22m/' \
                -e $'s/\sFail\s/\e[31m&\e[39m/' \
                -e $'s/\sPass\s/\e[32m&\e[39m/' \
                -e $'s/^.*\sSkipped\s.*$/\e[2m&\e[22m/'
    else
        (
            echo "ID,Description,Scoring,Level,Result,Duration"
            sort -V "$FILE_OUTPUT"
        ) | column -t -s , | sed -e '/^[0-9]\ / s/^/\n/'
    fi
    
    tests_total=$(grep -c "Scored" "$FILE_OUTPUT")
    tests_skipped=$(grep -c ",Skipped," "$FILE_OUTPUT")
    #tests_ran=$(( tests_total - tests_skipped ))
    tests_passed=$(grep -Ec ",Pass," "$FILE_OUTPUT")
    #tests_failed=$(grep -Ec ",Fail," "$FILE_OUTPUT")
    tests_errored=$(grep -Ec ",Error," "$FILE_OUTPUT")
    tests_duration=$(( $( date +%s ) - TIME_START ))
    
    echo
    echo "Passed $tests_passed of $tests_total tests in $tests_duration seconds ($tests_skipped Skipped, $tests_errored Errors)"
    echo
    
    write_debug "All results written to STDOUT"
} ## Prettily prints the results to the terminal
parse_args() {
    args="$*"
    
    ## Call help_text function if -h or --help present
    [ "$(echo "$args" | grep -Ec -- '-h|--help')" -ne 0 ]  &&   help_text
    
    ## Check arguments for --debug
    [ "$(echo "$args" | grep -c -- '--debug')" -ne 0 ]  &&   DEBUG="True"
    
    ## Full noise output
    [ "$(echo "$args" | grep -c -- '--trace')" -ne 0 ]  &&  TRACE="True" && set -x
    [ "$TRACE" == "True" ] && write_debug "Trace enabled"
    
    ## Renice / lower priority of script execution
    [ "$(echo "$args" | grep -c -- '--nice')" -ne 0 ]  &&   RENICE="True"
    [ "$(echo "$args" | grep -c -- '--no-nice')" -ne 0 ]  &&   RENICE="False"
    [ "$RENICE" == "True" ] && write_debug "Tests will run with reduced CPU priority"
    
    ## Disable colourised output
    [ "$(echo "$args" | grep -Ec -- '--no-color|--no-colour')" -ne 0 ]  &&   COLOURIZE="False" || COLOURIZE="True"
    [ "$COLOURIZE" == "False" ] && write_debug "Coloured output disabled"
    
    ## Check arguments for --exclude
    ## NB: The whitespace at the beginning and end is required for the greps later on
    exclude=" $(echo "$args" | sed -e 's/^.*--exclude //' -e 's/--.*$//') "
    if [ "$(echo "$exclude" | wc -c )" -gt 3 ]; then
        write_debug "Exclude list is populated \"$exclude\""
    else
        write_debug "Exclude list is empty"
    fi
    
    ## Check arguments for --include
    ## NB: The whitespace at the beginning and end is required for the greps later on
    include=" $(echo "$args" | sed -e 's/^.*--include //' -e 's/--.*$//') "
    if [ "$(echo "$include" | wc -c )" -gt 3 ]; then
        write_debug "Include list is populated \"$include\""
    else
        write_debug "Include list is empty"
    fi
    
    ## Check arguments for --level
    if [ "$(echo "$args" | grep -- '--level 1' &>/dev/null; echo $?)" -eq 0 ]; then
        TEST_LEVEL=$(( TEST_LEVEL + 1 ))
        write_debug "Going to run Level 1 tests"
    fi
    if [ "$(echo "$args" | grep -- '--level 2' &>/dev/null; echo $?)" -eq 0 ]; then
        TEST_LEVEL=$(( TEST_LEVEL + 2 ))
        write_debug "Going to run Level 2 tests"
    fi
    if [ "$TEST_LEVEL" -eq 0 ] || [ "$TEST_LEVEL" -eq 3 ]; then
        TEST_LEVEL=0
        write_debug "Going to run tests from any level"
    fi
} ## Parse arguments passed in to the script
progress() {
    ## We don't want progress output while we're spewing debug or trace output
    write_debug "Not displaying progress ticker while debug is enabled" && return 0
    [ "$TRACE" == "True" ] && return 0
    
    #shellcheck disable=SC1001
    array=(\| \/ \- \\)
    
    while [ "$(running_children)" -gt 1 ] || [ "$(cat "$FILE_STATUS")" == "LOADING" ]; do 
        started=$( wc -l "$FILE_COUNTER_STARTED" | awk '{print $1}' )
        finished=$( wc -l "$FILE_COUNTER_FINISHED" | awk '{print $1}' )
        #running=$(( started - finished ))
        
        tick=$(( tick + 1 ))
        pos=$(( tick % 4 ))
        char=${array[$pos]}
        
        script_duration="$(date +%T -ud @$(( $(date +%s) - TIME_START )))"
        #shellcheck disable=2059
        printf "\r[$script_duration] ($char) $finished of $started tests completed " >&2
        sleep $PROGRESS_UPDATE_DELAY
    done
    
    ## When all tests have finished, make a final update
    finished=$( wc -l "$FILE_COUNTER_FINISHED" | awk '{print $1}' )
    script_duration="$(date +%T -ud @$(( $(date +%s) - TIME_START )))"
    printf '\r[%s] (✓) %s of %s tests completed\n' "$script_duration" "$started" "$started" >&2
} ## Prints a pretty progress spinner while running tests
run_test() {
    id=$1; shift
    level=$1; shift
    description=$1; shift
    test_module=$1; shift
    #args=$(echo $@ | awk '{$1 = $2 = $3 = $4 = ""; print $0}' | sed 's/^ *//')
    args="$*"
    
    if [ "$(is_test_included "$id" "$level")" -eq 0 ]; then
        write_debug "Requesting test $id by calling \"$test_module $id $level \"$description\" $args &\""
        
        while [ "$(pgrep -P $$ 2>/dev/null | wc -l)" -ge $RUNNING_TESTS_MAX ]; do 
            write_debug "There were already max_running_tasks ($RUNNING_TESTS_MAX) while attempting to start test $id. Pausing for $WAIT_TIME seconds"
            sleep $WAIT_TIME
        done
        
        write_debug "There were $(( $(pgrep -P $$ 2>&1 | wc -l) - 1 ))/$RUNNING_TESTS_MAX max_running_tasks when starting test $id."
        
        ## Don't try to thread the script if trace or debug is enabled so it's output is tidier :)
        if [ $TRACE == "True" ]; then
            #shellcheck disable=2086
            $test_module "$id" "$level" "$description" "$level" $args
            
        elif [ $DEBUG == "True" ]; then
            set -x
            #shellcheck disable=2086
            $test_module "$id" "$level" "$description" $args
            set +x
            
        else
            #shellcheck disable=2086
            $test_module "$id" "$level" "$description" $args &
        fi
    fi
    
    return 0
} ## Compares test id against includes / excludes list and returns whether to run test or not
running_children() {
    ## Originally tried using pgrep, but it returned one line even when output was "empty"
    search_terms="PID|ps$|grep$|wc$|sleep$"

    #shellcheck disable=SC2009
    (
        [ $DEBUG == True ] && ps --ppid $$ | grep -Ev "$search_terms"
        ps --ppid $$ | grep -Evc "$search_terms"
    )
} ## Ghetto implementation that returns how many child processes are running
setup() {
    write_debug "Creating tmp files under $FILE_BASE"
    mkdir -p "$FILE_BASE"
    cat /dev/null > "$FILE_COUNTER_FINISHED"
    cat /dev/null > "$FILE_COUNTER_STARTED"
    cat /dev/null > "$FILE_OUTPUT"
    echo "LOADING" > "$FILE_STATUS"

    write_debug "Script was started with PID: $$"
    if [ "$RENICE" == "True" ]; then
        if [ "$RENICE_VALUE" -gt 0 ] && [ "$RENICE_VALUE" -le 19 ]; then
            renice_output="$(renice +$RENICE_VALUE $$)"
            write_debug "Renicing $renice_output"
        fi
    fi
} ## Sets up required files for test
test_start() {
    id=$1
    
    write_debug "Test $id started"
    echo "." >> "$FILE_COUNTER_STARTED"
    write_debug "Progress: $( wc -l "$FILE_COUNTER_FINISHED" | awk '{print $1}' )/$( wc -l "$FILE_COUNTER_STARTED" | awk '{print $1}' ) tests."
    
    now
} ## Prints debug output (when enabled) and returns current time
test_finish() {
    id=$1
    start_time=$2
    duration="$(( $(now) - start_time ))"
    
    write_debug "Test ""$id"" completed after ""$duration""ms"
    echo "." >> "$FILE_COUNTER_FINISHED"
    write_debug "Progress: $( wc -l "$FILE_COUNTER_FINISHED" | awk '{print $1}' )/$( wc -l "$FILE_COUNTER_STARTED" | awk '{print $1}' ) tests."
    
    echo $duration
} ## Prints debug output (when enabled) and returns duration since $start_time
tidy_up() {
    [ $DEBUG == "True" ] && opt="-v"
    rm -rf "$opt" "$FILE_BASE"* 2>/dev/null
} ## Tidys up files created during testing
write_cache() {
    write_debug "Writing to $FILE_OUTPUT - $*"
    printf "%s\n" "$*" >> "$FILE_OUTPUT"
} ## Writes additional rows to the output cache
write_debug() {
    [ "$DEBUG" == "True" ] && printf "[DEBUG] $(date -Ins) %s\n" "$*" >&2
} ## Writes debug output to STDERR
write_err() {
    printf "[ERROR] %s\n" "$*" >&2
} ## Writes error output to STDERR
write_result() {
    write_debug "Writing result to $FILE_OUTPUT - $*"
    printf "%s\n" "$*" >> "$FILE_OUTPUT"
} ## Writes test results to the output cache


### Benchmark Tests ###
## This section defines the benchmark tests that are called by the script

skip_test() {
    ## This function is a blank for any tests too complex to perform 
    ## or that rely too heavily on site policy for definition
    
    id=$1
    level=$2
    description=$3
    result="Skipped"

    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_automount_is_disabled() {
    id=$1
    level=$2
    description=$3
    scored="Scored"
    test_start_time=$(test_start "$id")
    
    ## Tests Start ##
    service=$(systemctl | awk '/autofs/ {print $1}')
    if [ -n "$service" ]; then
        result="Pass"
    elif [ "$(systemctl is-enabled "$service")" != "enabled" ]; then
        result="Pass"
    else
        result="Fail"
    fi
    ## Tests End ##

    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_gpg_keys_are_configured() {
    id=$1
    level=$2
    description=$3
    search_dir=${4:-"/etc/yum.repos.d"}
    scored="Not Scored"
    test_start_time=$(test_start "$id")
    state=0
    
    ## Tests Start ##
    repo_files=$(find "$search_dir" -name '*.repo' | wc -w)
    repo_files_with_gpgkeys=$(grep -Rhc '^gpgkey=' "$search_dir/"*.repo | paste -sd+ - | bc)

    if [ "$repo_files" -eq "$repo_files_with_gpgkeys" ]; then
        result="Pass"
    elif [ "$repo_files" -gt "$repo_files_with_gpgkeys" ]; then
        result="Fail"
        state=1
    else
        result="Fail"
        state=2
    fi
    ## Tests End ##

    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_gpgcheck_is_globally_active() {
    id=$1
    level=$2
    description=$3
    
    ## We do this to allow shellspec to inject variables for testing
    yum_config=${4:-"/etc/yum.conf"}
    repo_files=${5:-"/etc/yum.repos.d/*.repo"}
    
    scored="Scored"
    state=0
    test_start_time=$(test_start "$id")
    
    ## Tests Start ##
    ## First test ensures gpgcheck has been explicitly enabled in the yum.conf, which specifies the default for all repos. 
    ## Notably, gpgcheck is not enabled by default if it is not set here.
    [ "$(grep -Rhc ^gpgcheck=1 "$yum_config" )" -ne 1 ] && state=$(( state + 1 ))

    ## Second check checks individual repo files haven't disabled gpgcheck, unless the repo itself is also disabled in which case it is not even used
    repos_with_disabled_gpg=$(awk -v 'RS=[' -F '\n' '/\n\s*gpgcheck\s*=\s*0(\W.*)?/  &&  ! /\n\s*enabled\s*=\s*0(\W.*)?/ { t=substr($1, 1, index($1, "]")-1); print t }' "$repo_files")
    [ "$(echo "$repos_with_disabled_gpg" | wc -w)" -ne 0 ] && state=$(( state + 2 ))
    
    [ "$state" -eq 0 ] && result="Pass" || result="Fail"
    ## Tests End ##
    
    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_is_enabled() {
    id=$1
    level=$2
    service=$3
    name=$4
    description="Ensure $name service is enabled"
    scored="Scored"
    test_start_time=$(test_start "$id")
    
    ## Tests Start ##
    [ "$( systemctl is-enabled "$service" )" == "enabled" ] && result="Pass" || result="Fail"
    ## Tests End ##
    
    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_is_installed() {
    id=$1
    level=$2
    pkg=$3
    name=$4
    description="Ensure $name is installed"
    scored="Scored"
    test_start_time=$(test_start "$id")
    
    ## Tests Start ##
    [ "$(rpm -q "$pkg" &>/dev/null; echo $?)" -eq 0 ] && result="Pass" || result="Fail"
    ## Tests End ##
    
    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_is_not_installed() {
    id=$1
    level=$2
    pkg=$3
    name=$4
    description="Ensure $name is not installed"
    scored="Scored"
    test_start_time=$(test_start "$id")
    
    ## Tests Start ##
    [ "$(rpm -q "$pkg" &>/dev/null; echo $?)" -eq 0 ] && result="Fail" || result="Pass"
    ## Tests End ##
    
    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_kernel_module_is_disabled() {
    id=$1
    level=$2
    description=$3
    filesystem=$4
    test_start_time=$(test_start "$id")
    state=0
    
    ## Tests Start ##
    #[ $(diff -qsZ <(modprobe -n -v $filesystem 2>/dev/null | tail -n1) <(echo "install /bin/true") &>/dev/null; echo $?) -ne 0 ] && state=$(( $state + 1 ))
    [ "$(modprobe -nv "$filesystem" | grep -E "($filesystem|install)")" != "install /bin/true " ] && state=$(( state + 1 ))
    [ "$(lsmod | grep -c "$filesystem")" -ne 0 ] && state=$(( state + 2 ))
    [ $state -eq 0 ] && result="Pass" || result="Fail"
    ## Tests End ##
    
    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_mount_option_is_set() {
    id=$1
    level=$2
    description=$3
    partition=$4
    fs_opt=$5
    scored="Scored"
    test_start_time=$(test_start "$id")
    
    ## Tests Start ##
    [ "$(mount | grep -Ec "$partition .*$fs_opt")" -gt 0 ]  && result="Pass" || result="Fail"
    ## Tests End ##
    
    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_mount_option_on_removable_media() {
    id=$1
    level=$2
    fs_opt=$3
    description="Ensure $fs_opt option set on removable media partitions"
    scored="Not Scored"
    test_start_time=$(test_start "$id")
    
    ## Tests Start ##
    ## Note: Only usb media is supported at the moment. Need to investigate what 
    ##  difference a CDROM, etc. can make, but I've set it up ready to add 
    ##  another search term. You're welcome :)
    devices=$(lsblk -pnlS | awk '/usb/ {print $1}')
    filesystems=$(for device in $devices; do lsblk -nlp "$device" | grep -Ev "^$device|[SWAP]" | awk '{print $1}'; done)
    
    for filesystem in $filesystems; do
        fs_without_opt=$(mount | grep "$filesystem " | grep -cv "$fs_opt" &>/dev/null)
        [ "$fs_without_opt" -ne 0 ]  && state=1
    done
        
    [ $state -eq 0 ] && result=Pass
    ## Tests End ##
    
    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_partition_exists() {
    id=$1
    level=$2
    description=$3
    partition=$4
    scored="Scored"
    test_start_time=$(test_start "$id")
    
    ## Tests Start ##
    mount | awk '{print $3}' | grep -E "^$partition$" &>/dev/null  && result="Pass" || result="Fail"
    ## Tests End ##
    
    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_permissions() {
    id=$1
    level=$2
    required_permissions=$3
    file=$4
    description="Ensure permissions on $file are configured"
    scored="Scored"
    state=0
    test_start_time=$(test_start "$id")
    
    ## Tests Start ##
    if [ -e "$file" ]; then
        configured_permissions="$(stat -Lc "%a %U %G" /vagrant/.tmp/perms)"
        configured_user=$(echo "$configured_permissions" | awk '{print $2}')
        configured_group=$(echo "$configured_permissions" | awk '{print $3}')
        configured_u=$(echo "$configured_permissions" | cut -c1)
        configured_g=$(echo "$configured_permissions" | cut -c2)
        configured_o=$(echo "$configured_permissions" | cut -c3)
        required_u=$(echo "$required_permissions" | cut -c1)
        required_g=$(echo "$required_permissions" | cut -c2)
        required_o=$(echo "$required_permissions" | cut -c3)
    
        [ "$configured_user" == "root" ] || state=$(( state + 2 ))
        [ "$configured_group" == "root" ] || state=$(( state + 4 ))
        [ "$configured_u" -le "$required_u" ] || state=$(( state + 8 ))
        [ "$configured_g" -le "$required_g" ] || state=$(( state + 16 ))
        [ "$configured_o" -le "$required_o" ] || state=$(( state + 32 ))
    
        [ $state -eq 0 ] && result="Pass" || result="Fail"
    else
        result="Fail"
        state=$(( state + 1 ))
    fi
    ## Tests End ##
    
    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}
test_sticky_bit_on_world_writable_dirs() {
    id=$1
    level=$2
    description=$3
    scored="Scored"
    test_start_time=$(test_start "$id")
    
    ## Tests Start ##
    search_dirs=$(df --local -P | awk '{if (NR!=1) print $6}')
    bad_dirs=$(for dir in $search_dirs; do find "$dir" -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null; done)
    dir_count=$(echo "$bad_dirs" | wc -w)
    [ "$dir_count" -eq 0 ] && result="Pass"  || result="Fail"
    ## Tests End ##
    
    duration="$(test_finish "$id" "$test_start_time")ms"
    write_result "$id,$description,$scored,$level,$result,$duration"
}


### Main ###
## Return if script has been sourced by shellspec
${__SOURCED__:+return}

## Parse arguments passed in to the script
parse_args "$ARGS"

## Run setup function
setup
progress & 

## Run Tests
## These tests could've been condensed using loops but I left it exploded for ease of understanding / updating in the future.

## Section 1 - Initial Setup
if [ "$(is_test_included 1)" -eq 0 ]; then
    write_cache "1,Initial Setup"

    ## Section 1.1 - Filesystem Configuration
    if [ "$(is_test_included 1.1)" -eq 0 ]; then
        write_cache "1.1,Filesystem Configuration"
        
        ## Section 1.1.1 - Disable unused filesystems
        if [ "$(is_test_included 1.1.1)" -eq 0 ]; then
            write_cache "1.1.1,Disable unused filesystems"
            run_test 1.1.1.1 1 'Ensure mounting of cramfs is disabled' test_kernel_module_is_disabled cramfs
            run_test 1.1.1.2 1 'Ensure mounting of squashfs is disabled' test_kernel_module_is_disabled squashfs
            run_test 1.1.1.3 1 'Ensure mounting of udf is disabled' test_kernel_module_is_disabled udf 
            run_test 1.1.1.4 2 'Ensure mounting of FAT filesystems is limited' skip_test 
        fi
            
        run_test 1.1.2  1 "Ensure /tmp is configured" test_partition_exists /tmp
        run_test 1.1.3  1 "Ensure noexec option set on /tmp partition" test_mount_option_is_set /tmp noexec
        run_test 1.1.4  1 "Ensure nodev option set on /tmp partition" test_mount_option_is_set /tmp nodev
        run_test 1.1.5  1 "Ensure nosuid option set on /tmp partition" test_mount_option_is_set /tmp nosuid
        
        run_test 1.1.6  1 "Ensure /dev/shm is configured" test_partition_exists /dev/shm
        run_test 1.1.7  1 "Ensure noexec option set on /dev/shm partition" test_mount_option_is_set /dev/shm noexec
        run_test 1.1.8  1 "Ensure nodev option set on /dev/shm partition" test_mount_option_is_set /dev/shm nodev
        run_test 1.1.9  1 "Ensure nosuid option set on /dev/shm partition" test_mount_option_is_set /dev/shm nosuid
        
        run_test 1.1.10 2 "Ensure separate partition exists for /var" test_partition_exists /var
        run_test 1.1.11 2 "Ensure separate partition exists for /var/tmp" test_partition_exists /var/tmp
        run_test 1.1.12 1 "Ensure noexec option set on /var/tmp" test_mount_option_is_set /var/tmp noexec
        run_test 1.1.13 1 "Ensure nodev option set on /var/tmp" test_mount_option_is_set /var/tmp nodev
        run_test 1.1.14 1 "Ensure nosuid option set on /var/tmp" test_mount_option_is_set /var/tmp nosuid
        
        run_test 1.1.15 2 "Ensure separate partition exists for /var/log" test_partition_exists /var/log
        run_test 1.1.16 2 "Ensure separate partition exists for /var/log/audit" test_partition_exists /var/log/audit
        run_test 1.1.17 2 "Ensure separate partition exists for /home" test_partition_exists /home
        run_test 1.1.18 1 "Ensure nodev option set on /home" test_mount_option_is_set /home nodev
        
        run_test 1.1.19 1 "Ensure noexec option set on removable media partitions" skip_test
        run_test 1.1.20 1 "Ensure nodev option set on removable media partitions" skip_test
        run_test 1.1.21 1 "Ensure nosuid option set on removable media partitions" skip_test
        
        run_test 1.1.22 1 "Ensure Sticky bit is set on all world-writable dirs" test_sticky_bit_on_world_writable_dirs
        run_test 1.1.23 1 "Disable Automounting" test_automount_is_disabled
        run_test 1.1.24 1 "Disable USB Storage" test_kernel_module_is_disabled usb-storagete
    fi

    ## Section 1.2 - Configure Software Updates
    if [ "$(is_test_included 1.2)" -eq 0 ]; then
        write_cache "1.2,Configure Software Updates"
        
        run_test 1.2.1 1 "Ensure GPG keys are Configured" test_gpg_keys_are_configured
        run_test 1.2.2 1 "Ensure package manager repositories are configured" skip_test
        run_test 1.2.3 1 "Ensure gpgcheck is globally activated" test_gpgcheck_is_globally_active
    fi
    
    #if [ "$(is_test_included 1.3; echo $?)"]
fi

## Wait while all tests exit
echo "RUNNING" > "$FILE_STATUS"
wait
echo "FINISHED" > "$FILE_STATUS"
write_debug "All tests have completed"

## Output test results
outputter
tidy_up
write_debug "Exiting with code $EXIT_CODE"
exit $EXIT_CODE
