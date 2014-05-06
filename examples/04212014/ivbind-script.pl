########################################################################################
###################                   ivbind-script.pl                  ################
###################         use Hoh.pm    Krantz Lab Rev.  March 2014   ################
########################################################################################
########################################################################################
##############  Script to manipulate current-voltage binding experiments  ##############
########################################################################################
# Usage:
#    perl iv-bind-script.pl exp.txt
# 
# Parameters:
#    exp.txt is the name of the experiment file 
#
# Experiment file format example comma-delimited:
#     FILE,CONC
#     14303004.atf,0
#     14303005.atf,0
#     14303007.atf,10
#     14303008.atf,10
#     14303009.atf,30
#     14303010.atf,30
#     14303011.atf,100
#     14303012.atf,100
#     14303013.atf,300
#     14303014.atf,300
#     14303015.atf,1000
#     14303016.atf,1000
########################################################################################
# The following script will (1) open and process the list of atf files in the exp.txt file
# (2) normalize them and (3) do a hill analysis of the binding.
#
# The script will first average the input ATF files, save those as DATA[i].txt indexed files.
# Then the script will voltage bin the data into voltage bins, saving those bins BIN[i].txt.
# The default bins are -80 mV to +20 mV in 5 mV steps. That parameter can be changed. 
# See Ivbind.pm for these and other parameter settings. Then on each BIN[i].txt a Hill binding
# analysis is performed. The linear fits and residuals are saved as FIT[i].txt, and a 
# MASTER.txt file is created which contains the fit parameters.
#
# All files are saved in Hoh compatible formats, where the first line are the column names.
# No row keys are printed in the Hoh files. The file delimiter is comma. So the files are 
# compatible with Excel, Origin, etc.
#
########################################################################################
my $exp_file = $ARGV[0];
$exp_file = 'exp.txt' unless $exp_file; #default choice if no file is specified

use Ivbind;
my $ivbind =  Ivbind->new();
   $ivbind -> batch_average_atf_files($exp_file) -> normalize -> hill_analysis;
