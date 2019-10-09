#!/usr/bin/perl
####################################################################################################################################
# Travis CI Test Wrapper
####################################################################################################################################

####################################################################################################################################
# Perl includes
####################################################################################################################################
use strict;
use warnings FATAL => qw(all);
use Carp qw(confess longmess);
use English '-no_match_vars';

# Convert die to confess to capture the stack trace
$SIG{__DIE__} = sub { Carp::confess @_ };

use File::Basename qw(dirname);
use Getopt::Long qw(GetOptions);
use Cwd qw(abs_path);

use lib dirname($0) . '/lib';
use lib dirname(dirname($0)) . '/lib';

use pgBackRest::Common::Exception;
use pgBackRest::Common::Log;

use pgBackRestTest::Common::ContainerTest;
use pgBackRestTest::Common::ExecuteTest;
use pgBackRestTest::Common::VmTest;

####################################################################################################################################
# Usage
####################################################################################################################################

=head1 NAME

travis.pl - Travis CI Test Wrapper

=head1 SYNOPSIS

test.pl [options] doc|test

 VM Options:
   --vm                 docker container to build/test

 General Options:
   --help               display usage and exit
=cut

####################################################################################################################################
# Command line parameters
####################################################################################################################################
my $strVm;
my $bHelp;

GetOptions ('help' => \$bHelp,
            'vm=s' => \$strVm)
    or pod2usage(2);

####################################################################################################################################
# Begin/end functions to track timing
####################################################################################################################################
my $lProcessBegin;
my $strProcessTitle;

sub processBegin
{
    $strProcessTitle = shift;

    &log(INFO, "Begin ${strProcessTitle}");
    $lProcessBegin = time();
}

sub processExec
{
    my $strCommand = shift;
    my $rhParam = shift;

    &log(INFO, "    Exec ${strCommand}");
    executeTest($strCommand, $rhParam);
}

sub processEnd
{
    &log(INFO, "    End ${strProcessTitle} (" . (time() - $lProcessBegin) . 's)');
}

####################################################################################################################################
# Run in eval block to catch errors
####################################################################################################################################
eval
{
    # Display version and exit if requested
    if ($bHelp)
    {
        syswrite(*STDOUT, "Travis CI Test Wrapper\n");

        syswrite(*STDOUT, "\n");
        pod2usage();

        exit 0;
    }

    if (@ARGV != 1)
    {
        syswrite(*STDOUT, "test|doc required\n\n");
        pod2usage();
    }

    # VM must be defined
    if (!defined($strVm))
    {
        confess &log(ERROR, '--vm is required');
    }

    ################################################################################################################################
    # Paths
    ################################################################################################################################
    my $strBackRestBase = dirname(dirname(abs_path($0)));
    my $strReleaseExe = "${strBackRestBase}/doc/release.pl";
    my $strTestExe = "${strBackRestBase}/test/test.pl";

    logLevelSet(INFO, INFO, OFF);

    processBegin('install common packages');
    processExec('sudo apt-get -qq update', {bSuppressStdErr => true, bSuppressError => true});
    processExec('sudo apt-get install libxml-checker-perl libyaml-libyaml-perl', {bSuppressStdErr => true});
    processEnd();

    ################################################################################################################################
    # Build documentation
    ################################################################################################################################
    if ($ARGV[0] eq 'doc')
    {
        if ($strVm eq VM_CO7)
        {
            processBegin('LaTeX install');
            processExec(
                'sudo apt-get install -y --no-install-recommends texlive-latex-base texlive-latex-extra texlive-fonts-recommended',
                {bSuppressStdErr => true});
            processExec('sudo apt-get install -y texlive-font-utils latex-xcolor', {bSuppressStdErr => true});
        }

        processBegin('release documentation');
        processExec("${strReleaseExe} --build --no-gen --vm=${strVm}", {bShowOutputAsync => true, bOutLogOnError => false});
        processEnd();
    }

    ################################################################################################################################
    # Run test
    ################################################################################################################################
    elsif ($ARGV[0] eq 'test')
    {
        my $strParam = "";
        my $strVmHost = VM_U14;

        # Build list of packages that need to be installed
        my $strPackage = "libperl-dev";

        if (vmCoverageC($strVm))
        {
            $strPackage .= " lcov";
        }

        if ($strVm eq VM_NONE)
        {
            $strPackage .= " valgrind";
        }
        else
        {
            $strPackage .= " libdbd-pg-perl";
        }

        processBegin('install test packages');
        processExec("sudo apt-get install -y ${strPackage}", {bSuppressStdErr => true});
        processEnd();

        # Run tests that can be run without a container
        if ($strVm eq VM_NONE)
        {
            processBegin('/tmp/pgbackrest owned by root so tests cannot use it');
            processExec('sudo mkdir -p /tmp/pgbackrest && sudo chown root:root /tmp/pgbackrest && sudo chmod 700 /tmp/pgbackrest');
            processEnd();

            $strVmHost = VM_U18;
        }
        # Else run tests that require a container
        else
        {
            processBegin("create backrest user");
            processExec("sudo adduser --ingroup=\${USER?} --uid=5001 --disabled-password --gecos \"\" " . BACKREST_USER);
            processEnd();

            # Build the container
            processBegin("${strVm} build");
            processExec("${strTestExe} --vm-build --vm=${strVm}", {bShowOutputAsync => true, bOutLogOnError => false});
            processEnd();

            # Run tests
            $strParam .= " --vm-max=2";

            if ($strVm eq VM_U18)
            {
                $strParam .= " --container-only";
            }
            elsif ($strVm ne VM_U12)
            {
                $strParam .= " --module=command --module=mock --module=real --module=storage --module=performance";
            }
        }

        processBegin(($strVm eq VM_NONE ? "no container" : $strVm) . ' test');
        processExec(
            "${strTestExe} --no-gen --no-ci-config --vm-host=${strVmHost} --vm=${strVm}${strParam}",
            {bShowOutputAsync => true, bOutLogOnError => false});
        processEnd();
    }

    ################################################################################################################################
    # Catch error
    ################################################################################################################################
    else
    {
        confess &log(ERROR, 'invalid command ' . $ARGV[0]);
    }

    &log(INFO, "CI Complete");

    # Exit with success
    exit 0;
}

####################################################################################################################################
# Check for errors
####################################################################################################################################
or do
{
    # If a backrest exception then return the code
    exit $EVAL_ERROR->code() if (isException(\$EVAL_ERROR));

    # Else output the unhandled error
    print $EVAL_ERROR;
    exit ERROR_UNHANDLED;
};

# It shouldn't be possible to get here
&log(ASSERT, 'execution reached invalid location in ' . __FILE__ . ', line ' . __LINE__);
exit ERROR_ASSERT;
