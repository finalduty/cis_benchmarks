Include cis-audit.sh

write_result() { echo "$*"; }

Describe "skip_test"
    It "returns a skipped result"
        When call skip_test 1 2 3
        The output should eq "1,3,,2,Skipped,"
    End
End
