# Krantz Lab
# April 2014
# This script will merge bins in a series of directories, and it will remove points of the listed
# concentrations.
#
# It is recommended to run this script from a new directory or it will overwrite existing bins.
#
# Manually, edit the list of concentrations at the 'remove' method.
#
# Usage:
# perl ivbind-merge-remove-script.pl list/ of/ some/ directories/ to/ process/
#
use Ivbind;
my $iv = Ivbind -> new();
$iv -> delimiter(',');
$iv -> merge_bin_dirs( [ @ARGV ] ) -> remove('CONC', [0, 20]) -> save_bins -> hill_analysis;
