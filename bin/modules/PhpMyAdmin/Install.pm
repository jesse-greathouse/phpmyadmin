#!/usr/bin/perl

package PhpMyAdmin::Install;
use strict;
use File::Basename;
use File::Copy;
use File::Path qw(rmtree);
use Getopt::Long;
use Cwd qw(getcwd abs_path);
use lib(dirname(abs_path(__FILE__))  . "/modules");
use PhpMyAdmin::Utility qw(
    str_replace_in_file
    get_operating_system
    command_result
);
use Exporter 'import';
our @EXPORT_OK = qw(install);

my $bin = abs_path(dirname(__FILE__) . '/../../');
my $applicationRoot = abs_path(dirname($bin));
my $os = get_operating_system();
my $osModule = 'PhpMyAdmin::Install::' . $os;

eval "use $osModule qw(install_system_dependencies install_php)";

my @perlModules = (
    'JSON',
    'Archive::Zip',
    'Bytes::Random::Secure',
    'Config::File',
    'LWP::Protocol::https',
    'LWP::UserAgent',
    'File::Slurper',
    'File::HomeDir',
    'File::Find::Rule',
    'Term::ANSIScreen',
    'Term::Menus',
    'Term::Prompt',
    'Term::ReadKey',
    'Text::Wrap',
    'YAML::XS',
);

1;

# ====================================
#    Subroutines below this point
# ====================================

# Performs the install routine.
sub install {
    printf "Installing phpmyadmin at: $applicationRoot\n",

    my %options = handle_options();

    if ($options{'system'}) {
        install_system_dependencies();
    }

    if ($options{'perl'}) {
        install_perl_modules();
    }

    if ($options{'openresty'}) {
        install_openresty($applicationRoot);
    }

    if ($options{'php'}) {
        configure_php($applicationRoot);
        install_php($applicationRoot);
    }

    if ($options{'phpmyadmin'}) {
        install_phpmyadmin($applicationRoot);
    }

    install_symlinks($applicationRoot);

    cleanup($applicationRoot);
}

sub handle_options {
    my $defaultInstall = 1;
    my @components =  ('system', 'perl', 'openresty', 'php', 'phpmyadmin');
    my %skips;
    my %installs;

    GetOptions ("skip-system"       => \$skips{'system'},
                "skip-openresty"    => \$skips{'openresty'},
                "skip-perl"         => \$skips{'perl'},
                "skip-php"          => \$skips{'php'},
                "skip-phpmyadmin"   => \$skips{'phpmyadmin'},
                "system"            => \$installs{'system'},
                "openresty"         => \$installs{'openresty'},
                "perl"              => \$installs{'perl'},
                "php"               => \$installs{'php'},
                "phpmyadmin"        => \$installs{'phpmyadmin'})
    or die("Error in command line arguments\n");

    # If any of the components are requested for install...
    # Flip the $defaultInstall flag to negative.
    foreach (@components) {
        if (defined $installs{$_}) {
            $defaultInstall = 0;
            last;
        }
    }

    # Set up an options hash with the default install flag.
    my  %options = (
        system      => $defaultInstall,
        openresty   => $defaultInstall,
        perl        => $defaultInstall,
        php         => $defaultInstall,
        phpmyadmin  => $defaultInstall
    );

    # If the component is listed on the command line...
    # Set the option for true.
    foreach (@components) {
        if (defined $installs{$_}) {
            $options{$_} = 1;
        }
    }

    # If the component is set to skip on the command line...
    # Set the option for false.
    foreach (@components) {
        if (defined $skips{$_}) {
            $options{$_} = 0;
        }
    }

    return %options;
}

# installs Openresty.
sub install_openresty {
    my ($dir) = @_;
    my @configureOpenresty = ('./configure');
    push @configureOpenresty, '--prefix=' . $dir . '/opt/openresty';
    push @configureOpenresty, '--with-pcre-jit';
    push @configureOpenresty, '--with-ipv6';
    push @configureOpenresty, '--with-http_iconv_module';
    push @configureOpenresty, '--with-http_realip_module';
    push @configureOpenresty, '--with-http_ssl_module';
    push @configureOpenresty, '-j2';

    my $originalDir = getcwd();

    # Unpack
    system(('bash', '-c', "tar -xzf $dir/opt/openresty-*.tar.gz -C $dir/opt/"));
    command_result($?, $!, 'Unpack Openresty Archive...', 'tar -xzf ' . $dir . '/opt/openresty-*.tar.gz -C ' . $dir . ' /opt/');
    
    chdir glob("$dir/opt/openresty-*/");

    # configure
    system(@configureOpenresty);
    command_result($?, $!, 'Configure Openresty...', \@configureOpenresty);

    # make
    system('make');
    command_result($?, $!, 'Make Openresty...', 'make');

    # install
    system(('make', 'install'));
    command_result($?, $!, 'Install Openresty...', 'make install');

    chdir $originalDir;
}

# configures PHP.
sub configure_php {
    my ($dir) = @_;
    my $etcDir = $dir . '/etc';
    my $optDir = $dir . '/opt';
    my $phpExecutable = "$optDir/php/bin/php";
    my $phpIniFile = "$etcDir/php/php.ini";
    my $phpIniDist = "$etcDir/php/php.dist.ini";
    my $phpFpmConfFile = "$etcDir/php-fpm.d/php-fpm.conf";
    my $phpFpmConfDist = "$etcDir/php-fpm.d/php-fpm.dist.conf";
    my $username = getlogin || getpwuid($<) or die "Copy failed: $!";

    copy($phpIniDist, $phpIniFile) or die "Copy $phpIniDist failed: $!";
    copy($phpFpmConfDist, $phpFpmConfFile) or die "Copy $phpFpmConfDist failed: $!";
    str_replace_in_file('__DIR__', $dir, $phpIniFile);
    str_replace_in_file('__DIR__', $dir, $phpFpmConfFile);
    str_replace_in_file('__USER__', $username, $phpFpmConfFile);
}

# installs symlinks.
sub install_symlinks {
    my ($dir) = @_;
    my $binDir = $dir . '/bin';
    my $optDir = $dir . '/opt';
    my $vendorDir = $dir . '/src/vendor';

    unlink "$binDir/php";
    symlink("$optDir/php/bin/php", "$binDir/php");

    unlink "$binDir/phpunit";
    symlink("$vendorDir/bin/phpunit", "$binDir/phpunit");
}

# installs Perl Modules.
sub install_perl_modules {
    foreach my $perlModule (@perlModules) {
        my @cmd = ('sudo');
        push @cmd, 'cpanm';
        push @cmd, $perlModule;
        system(@cmd);

        command_result($?, $!, "Shared library pass for: $_", \@cmd);
    }
}

# installs PhpMyAdmin
sub install_phpmyadmin {
    my ($dir) = @_;
    my $webDir = "$dir/web/";
    my $configFile = "$dir/etc/config.php";
    my $configSymLink = "$webDir/config.php";

    # If web/ exists, delete it.
    if (-d $webDir) {
        rmtree $webDir;
    }

    # Unpack
    system(('bash', '-c', "tar -xzf $dir/opt/phpMyAdmin-*.tar.gz -C $dir"));
    command_result($?, $!, 'Unpack PhpMyAdmin Archive...', 'tar -xzf ' . $dir . '/opt/phpMyAdmin-*.tar.gz -C ' . $dir);

    move(glob("$dir/phpMyAdmin-*/"), $webDir);

    # If etc/config.php exists, copy it to web/.
    if (-e $configFile) {
        unlink $configSymLink;
        symlink($configFile, $configSymLink);
    }
}

sub cleanup {
    my ($dir) = @_;
    my $phpBuildDir = glob("$dir/opt/php-*/");
    my $openrestyBuildDir = glob("$dir/opt/openresty-*/");
    system(('bash', '-c', "rm -rf $phpBuildDir"));
    command_result($?, $!, 'Remove PHP Build Dir...', "rm -rf $phpBuildDir");
    system(('bash', '-c', "rm -rf $openrestyBuildDir"));
    command_result($?, $!, 'Remove Openresty Build Dir...', "rm -rf $openrestyBuildDir");
}
