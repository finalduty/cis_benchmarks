Describe "test_permissions"
    Include cis-audit.sh

    TEST_BASE=".tmp"
    TEST_FILE="$TEST_BASE/perms"

    DESCRIPTION="Ensure permissions on $TEST_FILE are configured"
    configured_user="root"
    configured_group="root"
    
    cleanup() { rm -rf "$TEST_BASE"; }
    setup() {
        mkdir -p "$TEST_BASE"
        touch "$TEST_FILE"
        chmod "$PERMS" "$TEST_FILE"
    }
    test_start() { echo 1; }
    test_finish() { echo 99; }
    write_result() { echo "$*"; }

    stat() { echo "$PERMS root root"; }

    It "will fail on a missing file"
        When call test_permissions 1 2 640 "$TEST_FILE"
        The variable "state" should eq 1
        The output should eq "1,$DESCRIPTION,Scored,2,Fail,99ms"
    End

    PERMS=123
    Before 'setup'
    It "will correctly extract permission bits"
        When call test_permissions 1 2 640 "$TEST_FILE"
        The variable "required_u" should eq 6
        The variable "required_g" should eq 4
        The variable "required_o" should eq 0
        The variable "configured_u" should eq 1
        The variable "configured_g" should eq 2
        The variable "configured_o" should eq 3
        The output should not eq ""
    End

    PERMS=000
    Before 'setup'
    Describe "on a file with 000"
        It "will Pass when permissions must be >= 000"
            When call test_permissions 1 2 000 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Pass,99ms"
            The variable "state" should eq 0
        End

        It "will Pass when permissions must be >= 400"
            When call test_permissions 1 2 400 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Pass,99ms"
            The variable "state" should eq 0
        End

        It "will Pass when permissions must be >= 600"
            When call test_permissions 1 2 600 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Pass,99ms"
            The variable "state" should eq 0
        End

        It "will Pass when permissions must be >= 640"
            When call test_permissions 1 2 640 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Pass,99ms"
            The variable "state" should eq 0
        End
    End

    PERMS=400
    Before 'setup'
    Describe "on a file with 400"
        It "will Fail when permissions must be >= 000"
            When call test_permissions 1 2 000 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Fail,99ms"
            The variable "state" should eq 8
        End

        It "will Pass when permissions must be >= 400"
            When call test_permissions 1 2 400 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Pass,99ms"
            The variable "state" should eq 0
        End

        It "will Pass when permissions must be >= 600"
            When call test_permissions 1 2 600 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Pass,99ms"
            The variable "state" should eq 0
        End

        It "will Pass when permissions must be >= 640"
            When call test_permissions 1 2 640 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Pass,99ms"
            The variable "state" should eq 0
        End
    End

    PERMS=640
    Before 'setup'
    Describe "on a file with 640"
        It "will Fail when permissions must be >= 000"
            When call test_permissions 1 2 000 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Fail,99ms"
            The variable "state" should eq 24
        End

        It "will Pass when permissions must be >= 400"
            When call test_permissions 1 2 400 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Fail,99ms"
            The variable "state" should eq 24
        End

        It "will Pass when permissions must be >= 600"
            When call test_permissions 1 2 600 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Fail,99ms"
            The variable "state" should eq 16
        End

        It "will Pass when permissions must be >= 640"
            When call test_permissions 1 2 640 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Pass,99ms"
            The variable "state" should eq 0
        End
    End

    PERMS=777
    Before 'setup'
    Describe "on a file with 777"
        It "will Fail when permissions must be >= 000"
            When call test_permissions 1 2 000 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Fail,99ms"
            The variable "state" should eq 56
        End

        It "will Fail when permissions must be >= 400"
            When call test_permissions 1 2 400 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Fail,99ms"
            The variable "state" should eq 56
        End

        It "will Fail when permissions must be >= 600"
            When call test_permissions 1 2 600 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Fail,99ms"
            The variable "state" should eq 56
        End

        It "will Fail when permissions must be >= 640"
            When call test_permissions 1 2 640 "$TEST_FILE"
            The output should eq "1,$DESCRIPTION,Scored,2,Fail,99ms"
            The variable "state" should eq 56
        End
    End

    Before 'cleanup'
    It "posthook"
        When call echo ok
        The output should eq "ok"
    End
End