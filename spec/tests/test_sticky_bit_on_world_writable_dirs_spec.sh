Describe "test_sticky_bit_on_world_writable_dirs"
    Include cis-audit.sh
    TEST_BASE=".tmp"
    TEST_DIR="$TEST_BASE/test"

    test_start() { echo 1; }
    test_finish() { echo 99; }
    write_result() { echo "$*"; }
    
    df() { echo -e "Headers\n1 2 3 4 5 $TEST_DIR"; }

    Describe "when sticky bit is set"
        setup() {
            rm -rf "$TEST_DIR"
            mkdir -p "$TEST_DIR"
            chmod 1777 "$TEST_DIR"
        }

        Before 'setup'
        It "will Pass"

            When call test_sticky_bit_on_world_writable_dirs 1 2 3
            The output should eq "1,3,Scored,2,Pass,99ms"
        End
    End
    
    Describe "when sticky bit is not set"
        setup() {
            rm -rf "$TEST_DIR"
            mkdir -p "$TEST_DIR"
            chmod 0777 "$TEST_DIR"
        }

        Before 'setup'
        It "will Fail"

            When call test_sticky_bit_on_world_writable_dirs 1 2 3
            The output should eq "1,3,Scored,2,Fail,99ms"
        End
    End

    Describe "when suid bit is set and sticky bit is set"
        setup() {
            rm -rf "$TEST_DIR"
            mkdir -p "$TEST_DIR"
            chmod 3777 "$TEST_DIR"
        }

        Before 'setup'
        It "will Pass"

            When call test_sticky_bit_on_world_writable_dirs 1 2 3
            The output should eq "1,3,Scored,2,Pass,99ms"
        End
    End

    Describe "when suid bit is set and sticky bit is not set"
        setup() {
            rm -rf "$TEST_DIR"
            mkdir -p "$TEST_DIR"
            chmod 2777 "$TEST_DIR"
        }

        Before 'setup'
        It "will Fail"

            When call test_sticky_bit_on_world_writable_dirs 1 2 3
            The output should eq "1,3,Scored,2,Fail,99ms"
        End
    End

    cleanup() { rm -rf "$TEST_BASE"; }
    Before 'cleanup'
    It "posthook"
        When call echo ok
        The output should eq "ok"
    End
End