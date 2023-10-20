#!/usr/bin/perl

package PhpMyAdmin::Configure;
use strict;
use File::Basename;
use Bytes::Random::Secure qw(random_bytes_hex);
use Cwd qw(getcwd abs_path);
use List::Util 1.29 qw( pairs );
use Exporter 'import';
use Scalar::Util qw(looks_like_number);
use Term::Prompt;
use Term::Prompt qw(termwrap);
use Term::ANSIScreen qw(cls);
use lib(dirname(abs_path(__FILE__))  . "/../modules");
use PhpMyAdmin::Config qw(
    get_configuration
    save_configuration
    write_config_file
);
use PhpMyAdmin::Utility qw(splash);

use Data::Dumper;

our @EXPORT_OK = qw(configure);

warn $@ if $@; # handle exception

# Folder Paths
my $secret = random_bytes_hex(32);
my $binDir = abs_path(dirname(__FILE__) . '/../../');
my $applicationRoot = abs_path(dirname($binDir));
my $webDir = "$applicationRoot/web";
my $varDir = "$applicationRoot/var";
my $etcDir = "$applicationRoot/etc";
my $logDir = "$varDir/log";
my $uploadDir = "$varDir/upload";
my $saveDir = "$varDir/cache";

# Files and Dist
my $errorLog = "$logDir/error.log";
my $runScript = "$binDir/phpmyadmin";
my $sslCertificate = "$etcDir/ssl/certs/phpmyadmin.cert";
my $sslKey = "$etcDir/ssl/private/phpmyadmin.key";
my $serviceRunScript = "$binDir/phpmyadmind";

my $phpMyAdminConfDist = "$etcDir/config.dist.php";
my $phpMyAdminConfFile = "$etcDir/config.php";
my $phpMyAdminConfSymlink = "$webDir/config.php";

my $initdDist = "$etcDir/init.d/init-template.sh.dist";
my $initdFile = "$etcDir/init.d/phpmyadmin";

my $forceSslDist = "$etcDir/nginx/force-ssl.dist.conf";
my $forceSslFile = "$etcDir/nginx/force-ssl.conf";

my $sslParamsDist = "$etcDir/nginx/ssl-params.dist.conf";
my $sslParamsFile = "$etcDir/nginx/ssl-params.conf";

my $nginxConfDist = "$etcDir/nginx/nginx.dist.conf";
my $nginxConfFile = "$etcDir/nginx/nginx.conf";

my $opensslConfDist = "$etcDir/ssl/openssl.dist.conf";
my $opensslConfFile = "$etcDir/ssl/openssl.conf";

# Get Configuration and Defaults
my %cfg = get_configuration();

my %defaults = (
    phpmyadmin => {
        APP_NAME                => 'phpmyadmin',
        CONTROL_HOST            => '127.0.0.1',
        CONTROL_PORT            => '3306',
        CONTROL_USER            => 'phpmyadmin',
        CONTROL_PASSWORD        => 'password',
        AUTH_TYPE               => 'cookie',
        HOST                    => 'localhost',
        ALLOW_NO_PASSWORD       => 'no',
        BLOWFISH_SECRET         => $secret,
        UPLOAD_DIR              => $uploadDir,
        SAVE_DIR                => $saveDir,
    },
    nginx => {
        DOMAINS                 => '127.0.0.1',
        IS_SSL                  => 'no',
        PORT                    => '8080',
        SSL_CERT                => $sslCertificate,
        SSL_KEY                 => $sslKey,
    },
    redis => {
        REDIS_HOST              => 'localhost',
    }
);

1;

# ====================================
#    Subroutines below this point
# ====================================

# Performs the install routine.
sub configure {
    cls();
    splash();

    print (''."\n");
    print ('================================================================='."\n");
    print (' This will create your application\'s runtime configuration'."\n");
    print ('================================================================='."\n");
    print (''."\n");

    request_user_input();

    merge_defaults();

    save_configuration(%cfg);

    # Create configuration files
    write_phpmyadmin_conf();
    write_initd_script();
}

sub write_phpmyadmin_conf {
    my %c = %{$cfg{phpmyadmin}};
    write_config_file($phpMyAdminConfDist, $phpMyAdminConfFile, %c);

    unless (-e $phpMyAdminConfSymlink) {
        symlink($phpMyAdminConfFile, $phpMyAdminConfSymlink);
    }
}

sub write_initd_script {
    my $mode = 0755;
    my %c = %{$cfg{nginx}};
    $c{'APP_NAME'} = $cfg{phpmyadmin}{'APP_NAME'};
    $c{'START_SCRIPT'} = $serviceRunScript;
    write_config_file($initdDist, $initdFile, %c);
    chmod $mode, $initdFile;
}

# Runs the user through a series of setup config questions.
# Confirms the answers.
# Returns Hash Table
sub request_user_input {
    # APP_NAME
    input('phpmyadmin', 'APP_NAME', 'Application Name');

    # CONTROL_HOST
    input('phpmyadmin', 'CONTROL_HOST', 'Database Host');

    # CONTROL_PORT
    input('phpmyadmin', 'CONTROL_PORT', 'Database Port');

    # CONTROL_USER
    input('phpmyadmin', 'CONTROL_USER', 'Database User');

    # CONTROL_BASSWORD
    input('phpmyadmin', 'CONTROL_PASSWORD', 'Database Password');

    # AUTH_TYPE
    input('phpmyadmin', 'AUTH_TYPE', 'Auth Type');
    
    # HOST
    input('phpmyadmin', 'HOST', 'Host');

    # BLOWFISH_SECRET
    input('phpmyadmin', 'BLOWFISH_SECRET', 'Blowfish Secret (Encryption Key)');

    # ALLOW_NO_PASSWORD
    input_boolean('phpmyadmin', 'ALLOW_NO_PASSWORD', 'Allow No Password');

    # UPLOAD_DIR
    input('phpmyadmin', 'UPLOAD_DIR', 'Upload Directory');

    # SAVE_DIR
    input('phpmyadmin', 'SAVE_DIR', 'Save Directory');

    # DOMAINS
    input('nginx', 'DOMAINS', 'Web Domains');

    # SSL
    input_boolean('nginx', 'IS_SSL', 'Use SSL (https)');
    
    # PORT
    input('nginx', 'PORT', 'Web Port');

    # SSL_CERT
    input('nginx', 'SSL_CERT', 'SSL Certificate Path');

    # SSL_KEY
    input('nginx', 'SSL_KEY', 'SSL Key Path');
    
    # REDIS_HOST
    input('redis', 'REDIS_HOST', 'Redis Host');
}

sub merge_defaults {

    if (!exists($cfg{phpmyadmin}{USER})) {
        $cfg{phpmyadmin}{USER} = $ENV{"LOGNAME"};
    }

        if (!exists($cfg{nginx}{USER})) {
        $cfg{nginx}{USER} = $ENV{"LOGNAME"};
    }

    if (!exists($cfg{nginx}{SESSION_SECRET})) {
        $cfg{nginx}{SESSION_SECRET} = $secret;
    }

    if (!exists($cfg{nginx}{LOG})) {
        $cfg{nginx}{LOG} = $errorLog;
    }

    if (!exists($cfg{nginx}{DIR})) {
        $cfg{nginx}{DIR} = $applicationRoot;
    }

    if (!exists($cfg{nginx}{VAR})) {
        $cfg{nginx}{VAR} = $varDir;
    }

    if (!exists($cfg{nginx}{ETC})) {
        $cfg{nginx}{ETC} = $etcDir;
    }

    if (!exists($cfg{nginx}{WEB})) {
        $cfg{nginx}{WEB} = $webDir;
    }

    if (!exists($cfg{nginx}{SSL})) {
        $cfg{nginx}{SSL} = '';
    }

    if (!exists($cfg{nginx}{SSL_CERT_LINE})) {
        $cfg{nginx}{SSL_CERT_LINE} = '';
    }

    if (!exists($cfg{nginx}{SSL_KEY_LINE})) {
        $cfg{nginx}{SSL_KEY_LINE} = '';
    }

    if (!exists($cfg{nginx}{INCLUDE_FORCE_SSL_LINE})) {
        $cfg{nginx}{INCLUDE_FORCE_SSL_LINE} = '';
    }
}

sub input {
    my ($varDomain, $varName, $promptText) = @_;
    my $default = $defaults{$varDomain}{$varName};

    if ($cfg{$varDomain}{$varName} ne '') {
        $default = $cfg{$varDomain}{$varName};
    }

    my $answer = prompt('x', "$promptText:", $varName, $default);

    # Translating the none response to an empty string.
    # This avoids the akward experience of showing the user a default of: ""
    # "default none" is a better user exerience for the cli.
    if ($answer eq 'none') {
        $answer = '';
    }

    $cfg{$varDomain}{$varName} = $answer;
}

sub input_boolean {
    my ($varDomain, $varName, $promptText) = @_;
    my $default = 'no';

    if ($cfg{$varDomain}{$varName} eq 'true') {
        $default = 'yes';
    } elsif ($defaults{$varDomain}{$varName} eq 'true') {
        $default = 'yes';
    }

    my $answer = prompt('y', "$promptText:", $varName, $default);

    if ($answer eq 'yes') {
        $cfg{$varDomain}{$varName} = 'true';
    } else {
        $cfg{$varDomain}{$varName} = 'false';
    }
}
