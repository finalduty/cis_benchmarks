Describe "test_is_not_installed"
    Include cis-audit.sh
    test_start() { echo 1; }
    test_finish() { echo 99; }
    write_result() { echo "$*"; }
    
    It "returns a Pass when package is not installed"
        rpm() { echo ""; return 1; }
    
        When call test_is_not_installed 1 2 3 4
        The output should eq "1,Ensure 4 is not installed,Scored,2,Pass,99ms"
    End

    It "returns a Fail when package is installed"
        rpm() { echo "pkg"; return 0; }
    
        When call test_is_not_installed 1 2 3 4
        The output should eq "1,Ensure 4 is not installed,Scored,2,Fail,99ms"
    End
End