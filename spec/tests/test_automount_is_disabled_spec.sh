Describe "test_automount_is_disabled"
    Include cis-audit.sh
    test_start() { echo 1; }
    test_finish() { echo 99; }
    write_result() { echo "$*"; }

    It "returns Pass when autofs is absent"
        systemctl() { echo ""; }

        When call test_automount_is_disabled 1 2 3
        The output should eq "1,3,Scored,2,Pass,99ms"
    End
    
    It "returns Pass when autofs is not enabled"
        systemctl() { echo "disabled"; return 1; }
        service="autofs.service"

        When call test_automount_is_disabled 1 2 3
        The output should eq "1,3,Scored,2,Pass,99ms"
    End
    
    It "returns Fail when autofs is enabled"
        systemctl() { echo "enabled"; return; }
        service="autofs.service"

        When call test_automount_is_disabled 1 2 3
        The output should eq "1,3,Scored,2,Fail,99ms"
    End
End