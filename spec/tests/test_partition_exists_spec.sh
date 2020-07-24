Describe "test_partition_exists"
    Include cis-audit.sh
    test_start() { echo 1; }
    test_finish() { echo 99; }
    write_result() { echo "$*"; }
    
    It "returns a Pass when partition exists"
        mount() { echo "tmpfs on /tmp type tmpfs (rw,nosuid,nodev,noexec,relatime,seclabel,size=524288k,mode=1777"; }
        
        When call test_partition_exists 1 2 3 /tmp
        The output should eq "1,3,Scored,2,Pass,99ms"
    End
    
    It "returns a Fail when partition doesn't exist"
        mount() { echo ""; }
        When call test_partition_exists 1 2 3 /tmp
        The output should eq "1,3,Scored,2,Fail,99ms"
    End
    
    It "doesn't return a false positive for similar directories"
        mount() { echo "tmpfs on /var/tmp type tmpfs (rw,nosuid,nodev,noexec,relatime,seclabel,size=524288k,mode=1777"; }

        When call test_partition_exists 1 2 3 /tmp
        The output should eq "1,3,Scored,2,Fail,99ms"
    End
End