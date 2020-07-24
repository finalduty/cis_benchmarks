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

Describe "test_start"
    Before 'setup' 

    It "registers a test has started"
        When call test_start 1 
        The file $FILE_COUNTER_STARTED contents should eq "."
        The first line should eq "Test 1 started"
        The second line should eq "Progress: 0/1 tests."
        The third line should eq 123
    End
    
    It "registers a second test has started"
        When call test_start 2 
        The file $FILE_COUNTER_STARTED contents should eq ".
."
        The first line should eq "Test 2 started"
        The second line should eq "Progress: 0/2 tests."
        The third line should eq 123
    End

    After 'cleanup'
    It 'posthook'
      When call echo ok
      The output should eq 'ok'
    End
End

