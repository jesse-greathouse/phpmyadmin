#!/usr/bin/perl

use strict;
use File::Basename;
use Scalar::Util qw(looks_like_number);
use Cwd qw(getcwd abs_path);
use lib(dirname(abs_path(__FILE__))  . "/modules");
use PhpMyAdmin::Utility qw(command_result);

my $etc = $ENV{'ETC'};
my $certDir = "$etc/ssl/certs";
my $dhparamFile = "$certDir/dhparam.pem";
my $overwrite = 0;
my $bitDepth = 2048;
my $argnum;

# Sort out the command line args
foreach $argnum (0 .. $#ARGV) {

    if ($ARGV[$argnum] eq "--etc") {
      $etc = $ARGV[$argnum + 1];
      $certDir = "$etc/ssl/certs";
      $dhparamFile = "$certDir/dhparam.pem";
    };

    if ($ARGV[$argnum] eq "--overwrite") {
      $overwrite = 1;
    };

    if ($ARGV[$argnum] eq "--bitdepth") {
      my $newBitDepth = $ARGV[$argnum + 1];
      if (looks_like_number($newBitDepth)) {
        $bitDepth = $newBitDepth;
      } else {
        printf "bitdepth was specified but illegal value was given: %s\n", $newBitDepth;
        exit 1;
      }
    };
}

# If the overwrite arg was given, delete the existing file
if ($overwrite) {
  if (-e $dhparamFile) {
    unlink($dhparamFile)
  }
}

# Generate the DH params if it doesnt exist
unless (-e $dhparamFile) {
  my @cmd = ('openssl');
  push @cmd, 'dhparam';
  push @cmd, '-out';
  push @cmd, $dhparamFile;
  push @cmd, $bitDepth;

  system(@cmd);

  command_result($?, $!, "openssl dhparam", \@cmd);
} else {
  printf "%s already exist.\n", $dhparamFile;
  exit 0;
}
