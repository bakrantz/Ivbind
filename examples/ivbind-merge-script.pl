# Krantz Lab
# April 2014
# This script will merge bins in a series of directories.
# It is recommended to run this script from a new directory or it will overwrite existing bins.
#
# Usage:
# perl ivbind-merge-script.pl list/ of/ some/ directories/ to/ process/
#
use Ivbind;
my $iv = Ivbind -> new();
$iv -> delimiter(',');
$iv -> merge_bin_dirs( [ @ARGV ] ) -> save_bins -> hill_analysis;
