Describe "test_gpgcheck_is_globally_active"
    Include cis-audit.sh
    TEST_BASE="$(mktemp -d ".tmp-XXXXXXXX")"

    cleanup() { rm -rf "$TEST_BASE"; }
    test_start() { echo 1; }
    test_finish() { echo 99; }
    write_result() { echo "$*"; }
    
    setup() {  
        echo gpgcheck=1 > "$TEST_BASE/yum-good.conf";
        echo gpgcheck=0 > "$TEST_BASE/yum-bad.conf";
        echo > "$TEST_BASE/yum-missing.conf";
        
        echo "[repo]\nenabled=1\ngpgcheck=1\n"   > "$TEST_BASE/repo-on_gpg-on";
        echo "[repo]\nenabled=1\ngpgcheck=0\n"   > "$TEST_BASE/repo-on_gpg-off";
        echo "[repo]\nenabled=1\n"               > "$TEST_BASE/repo-on_gpg-default";
        
        echo "[repo]\nenabled=0\ngpgcheck=1\n"   > "$TEST_BASE/repo-off_gpg-on";
        echo "[repo]\nenabled=0\ngpgcheck=0\n"   > "$TEST_BASE/repo-off_gpg-off";
        echo "[repo]\nenabled=0\n"               > "$TEST_BASE/repo-off_gpg-default";
        
        echo "[repo]\ngpgcheck=1\n"              > "$TEST_BASE/repo-default_gpg-on";
        echo "[repo]\ngpgcheck=0\n"              > "$TEST_BASE/repo-default_gpg-off";
        echo "[repo]\n"                          > "$TEST_BASE/repo-default_gpg-default";
    }
    

    BeforeAll 'setup'
    Describe "When gpgcheck is enabled globally, "
    
        It "will pass if repo-on and gpg-on"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-good.conf" "$TEST_BASE/repo-on_gpg-on"
            The output should eq "1,3,Scored,2,Pass,99ms"
        End
        It "will fail if repo-on and gpg-off"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-good.conf" "$TEST_BASE/repo-on_gpg-off"
            The output should eq "1,3,Scored,2,Fail,99ms"
            The variable "state" should eq 2
        End
        It "will pass if repo-on and gpg-default"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-good.conf" "$TEST_BASE/repo-on_gpg-default"
            The output should eq "1,3,Scored,2,Pass,99ms"
        End

        It "will pass if repo-off and gpg-on"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-good.conf" "$TEST_BASE/repo-off_gpg-on"
            The output should eq "1,3,Scored,2,Pass,99ms"
        End
        It "will pass if repo-off and gpg-off"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-good.conf" "$TEST_BASE/repo-off_gpg-off"
            The output should eq "1,3,Scored,2,Pass,99ms"
        End
        It "will pass if repo-off and gpg-default"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-good.conf" "$TEST_BASE/repo-off_gpg-default"
            The output should eq "1,3,Scored,2,Pass,99ms"
        End
        
        It "will pass if repo-default and gpg-on"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-good.conf" "$TEST_BASE/repo-default_gpg-on"
            The output should eq "1,3,Scored,2,Pass,99ms"
        End
        It "will fail if repo-default and gpg-off"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-good.conf" "$TEST_BASE/repo-default_gpg-off"
            The output should eq "1,3,Scored,2,Fail,99ms"
            The variable "state" should eq 2
        End
        It "will pass if repo-default and gpg-default"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-good.conf" "$TEST_BASE/repo-default_gpg-default"
            The output should eq "1,3,Scored,2,Pass,99ms"
        End
    End

    Describe "When gpgcheck is disabled globally, "
        It "will fail even if repo-on and gpg-on"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-bad.conf" "$TEST_BASE/repo-on_gpg-on"
            The output should eq "1,3,Scored,2,Fail,99ms"
            The variable "state" should eq 1
        End
    End

    Describe "When gpgcheck is missing globally, "
        It "will fail even if repo-on and gpg-on"
            When call test_gpgcheck_is_globally_active 1 2 3 "$TEST_BASE/yum-missing.conf" "$TEST_BASE/repo-on_gpg-on"
            The output should eq "1,3,Scored,2,Fail,99ms"
            The variable "state" should eq 1
        End
    End

    After 'cleanup'
    It "posthook"
        When call echo ok
        The output should eq ok
    End

End