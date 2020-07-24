Include cis-audit.sh

FILE_COUNTER_STARTED=".tmp/counter"
FILE_COUNTER_FINISHED=".tmp/finished"

setup() {
    mkdir -p .tmp
    touch .tmp/counter
    touch .tmp/finished
}
cleanup() {  rm -rf .tmp; }
now() { echo 123; }
write_debug() { echo "$*"; }

Describe "test_finish"
    Before 'setup'
    It "registers a test has finished"
        When call test_finish 1 100
        The file "$FILE_COUNTER_FINISHED" contents should eq "."
        The first line should eq "Test 1 completed after 23ms"
        The second line should eq "Progress: 1/0 tests."
        The third line should eq "23"
    End

    It "registers a second test has finished"
        When call test_finish 2 50
        The file "$FILE_COUNTER_FINISHED" contents should eq ".
."
        The first line should eq "Test 2 completed after 73ms"
        The second line should eq "Progress: 2/0 tests."
        The third line should eq "73"
    End

    After 'cleanup'
    It "posthook"
        When call echo ok
        The output should eq "ok"
    End
End
