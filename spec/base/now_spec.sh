Include cis-audit.sh
Describe "now"
    date() { echo "1594967834539939000"; }
    It "does a thing"
        When call now
        The output should eq 1594967834539
    End
End
