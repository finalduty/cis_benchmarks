Describe "test_gpg_keys_are_configured"
    Include cis-audit.sh
    TEST_BASE=".tmp"

    cleanup() { rm -rf "$TEST_BASE"; }
    setup() { mkdir -p "$TEST_BASE"; }
    test_start() { echo 1; }
    test_finish() { echo 99; }
    write_result() { echo "$*"; }

    write_one() { 
        echo gpgkey= > $TEST_BASE/one.repo; 
        touch $TEST_BASE/two.repo
    }
    write_two() { echo gpgkey= > $TEST_BASE/two.repo; }

    Before 'setup' 'write_one'
    It "will fail"
        When call test_gpg_keys_are_configured 1 2 3 "$TEST_BASE"
        The output should eq "1,3,Not Scored,2,Fail,99ms"
    End

    Before 'write_two'
    It "will pass"
        When call test_gpg_keys_are_configured 1 2 3 "$TEST_BASE"
        The output should eq "1,3,Not Scored,2,Pass,99ms"
    End
    
    Before 'cleanup'
    It "posthook"
        When call echo ok
        The output should eq ok
    End
End