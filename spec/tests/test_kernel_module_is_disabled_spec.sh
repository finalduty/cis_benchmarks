Describe "test_kernel_module_is_disabled"
    Include cis-audit.sh
    test_start() { echo 1; }
    test_finish() { echo 99; }
    write_result() { echo "$*"; }
    
    It "returns a Pass when kernel module is disabled"
        modprobe() { echo "install /bin/true "; }
        lsmod() { echo ""; }

        When call test_kernel_module_is_disabled 1 2 3 4 
        The output should eq "1,3,,2,Pass,99ms"
        The variable "state" should eq 0
    End

    It "returns a Fail when modprobe returns a module"
        modprobe() { echo "insmod /lib/modules/3.10.0-1127.10.1.el7.x86_64/kernel/fs/udf/udf.ko.xz "; }
        lsmod() { echo ""; }

        When call test_kernel_module_is_disabled 1 2 3 4 
        The output should eq "1,3,,2,Fail,99ms"
        The variable "state" should eq 1
    End

    It "returns a Fail when lsmod returns a module"
        modprobe() { echo "install /bin/true "; }
        lsmod() { echo "libcrc32c              12644  1 xfs"; }

        When call test_kernel_module_is_disabled 1 2 3 4 
        The output should eq "1,3,,2,Fail,99ms"
        The variable "state" should eq 2
    End

    It "returns a Fail when modprobe and lsmod return a module"
        modprobe() { echo "insmod /lib/modules/3.10.0-1127.10.1.el7.x86_64/kernel/fs/udf/udf.ko.xz "; }
        lsmod() { echo "libcrc32c              12644  1 xfs"; }

        When call test_kernel_module_is_disabled 1 2 3 4 
        The output should eq "1,3,,2,Fail,99ms"
        The variable "state" should eq 3
    End
End