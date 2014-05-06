# Krantz Lab
# April 2014
# This script will open the bins in a directory, and it will remove points of
# listed concentrations.
#
# It is recommended to run this script from a new directory or it will overwrite existing bins.
#
# Manually, edit the list of concentrations at the 'remove' method.
#
# Usage:
# perl ivbind-remove-script.pl directory/
#
use Ivbind;
my $iv = Ivbind -> new();
$iv -> delimiter(',');
$iv -> open_bin_dir( $ARGV[0] ) -> remove('CONC', [0, 20]) -> save_bins -> hill_analysis;
