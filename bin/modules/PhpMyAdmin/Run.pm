#!/usr/bin/perl

package PhpMyAdmin::Run;
use strict;
use File::Basename;
use Getopt::Long;
use Cwd qw(getcwd abs_path);
use Exporter 'import';
use Term::ANSIScreen qw(cls);
use lib(dirname(abs_path(__FILE__))  . "/../modules");
use PhpMyAdmin::Config qw(get_configuration);
use PhpMyAdmin::Utility qw(splash);

our @EXPORT_OK = qw(run);

warn $@ if $@; # handle exception

# Folder Paths
my $binDir = abs_path(dirname(__FILE__) . '/../../');
my $applicationRoot = abs_path(dirname($binDir));
my $etcDir = "$applicationRoot/etc";
my $optDir = "$applicationRoot/opt";
my $tmpDir = "$applicationRoot/tmp";
my $varDir = "$applicationRoot/var";
my $webDir = "$applicationRoot/web";
my $cacheDir = "$varDir/cache";
my $logDir = "$varDir/log";
my $user = $ENV{"LOGNAME"};
my $terminalSupervisor = "$etcDir/supervisor/conf.d/supervisord.conf";
my $daemonSupervisor = "$etcDir/supervisor/conf.d/supervisord.service.conf";
my $dockerSupervisor = "$etcDir/supervisor/conf.d/supervisord.docker.conf";

# Files and Dist
my $errorLog = "$logDir/error.log";
my $runScript = "$binDir/run";

# Get Configuration
my %cfg = get_configuration();

1;

my $daemon = 0;
my $docker = 0;
GetOptions (
    "daemon" => \$daemon,
    "docker" => \$docker,
);

# ====================================
#    Subroutines below this point
# ====================================

# Performs the install routine.
sub run {
    my $supervisorConfig = $terminalSupervisor;

    if ($daemon) {
        $supervisorConfig = $daemonSupervisor;
    }

    if ($docker) {
        $supervisorConfig = $dockerSupervisor;
    }

    $ENV{'USER'} = $user;
    $ENV{'BIN'} = $binDir;
    $ENV{'DIR'} = $applicationRoot;
    $ENV{'ETC'} = $etcDir;
    $ENV{'OPT'} = $optDir;
    $ENV{'TMP'} = $tmpDir;
    $ENV{'VAR'} = $varDir;
    $ENV{'WEB'} = $webDir;
    $ENV{'CACHE_DIR'} = $cacheDir;
    $ENV{'LOG_DIR'} = $logDir;
    $ENV{'PORT'} = $cfg{nginx}{PORT};
    $ENV{'SSL'} = $cfg{nginx}{IS_SSL};
    $ENV{'REDIS_HOST'} = $cfg{redis}{REDIS_HOST};


    my @cmd = ('supervisord');
    push @cmd, '-c';
    push @cmd, $supervisorConfig;

    cls();
    splash();

    system(@cmd);
}
