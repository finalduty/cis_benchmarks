Include cis-audit.sh
Describe "parse_args"
    write_debug() { cat /dev/null; }

    help_text() { echo "tested ok"; }

    It "variables have default values"
        When call parse_args
        The variable DEBUG should eq "False"
        The variable COLOURIZE should eq "True"
        The variable TEST_LEVEL should eq 0
    End

    It "--help calls help_text"
        When call parse_args --help
        The output should eq "tested ok"
    End

    It "--debug sets DEBUG variable to True"
        When call parse_args --debug
        The variable DEBUG should eq "True"
    End

    It "--trace sets TRACE to True"
        When call parse_args --trace
        The variable TRACE should eq "True"
        The error should not eq ""
    End

    It "--nice sets RENICE to True"
        When call parse_args --nice
        The variable RENICE should eq "True"
    End

    It "--no-nice sets RENICE to False"
        When call parse_args --no-nice
        The variable RENICE should eq "False"
    End

    It "--no-color sets COLOURIZE to False"
        When call parse_args --no-color
        The variable COLOURIZE should eq "False"
    End

    It "--no-colour sets COLOURIZE to False"
        When call parse_args --no-colour
        The variable COLOURIZE should eq "False"
    End

    It "--level 1 sets TEST_LEVEL to 1"
        When call parse_args --level 1
        The variable TEST_LEVEL should eq 1
    End

    It "--level 2 sets TEST_LEVEL to 2"
        When call parse_args --level 2
        The variable TEST_LEVEL should eq 2
    End

    It "--level 1 --level 2 sets TEST_LEVEL to 0"
        When call parse_args --level 1 --level 2
        The variable TEST_LEVEL should eq 0
    End
End

