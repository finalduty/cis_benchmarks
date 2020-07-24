Describe "test_is_enabled"
    Include cis-audit.sh
    test_start() { echo 1; }
    test_finish() { echo 99; }
    write_result() { echo "$*"; }
    
    It "returns a Pass when a service is enabled"
        systemctl() { echo "enabled"; }
        When call test_is_enabled 1 2 3 4
        The output should eq "1,Ensure 4 service is enabled,Scored,2,Pass,99ms"
    End

    It "returns a Fail when a service is disabled"
        systemctl() { echo "disabled"; }
        When call test_is_enabled 1 2 3 4
        The output should eq "1,Ensure 4 service is enabled,Scored,2,Fail,99ms"
    End
    
    It "returns a Fail when a service is null"
        systemctl() { echo ""; }
        When call test_is_enabled 1 2 3 4
        The output should eq "1,Ensure 4 service is enabled,Scored,2,Fail,99ms"
    End
    
End