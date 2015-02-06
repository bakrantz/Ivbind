#######################################################################################
###################                     Ivbind.pm                       ###############
###################         use Hoh.pm    Krantz Lab Rev.  Feb 2015     ###############
#######################################################################################
#######################################################################################
##############   Module to process current-voltage binding experiments     ############
#######################################################################################
package Ivbind;
$VERSION = "0.21";
################################### THE CONSTRUCTOR ###################################
sub new {
  my $proto                                 = shift;
  my $package                               = ref($proto) || $proto;
  my $self                                  = {};        #the anon hash
     $self -> {EXPERIMENT_FILE}             = 'exp.txt'; #filename of experiment batch file
     $self -> {MASTER_FILE}                 = 'MASTER.txt'; #filename of the master summary of fit data
     $self -> {DELIMITER}                   = ',';       #file delimiter default comma
     $self -> {FILE_INDEX_START}            = 1;         #file index for output files default = 1
     $self -> {FILE_PREFIX}                 = 'DATA';    #Default is DATA
     $self -> {FILE_EXTENSION}              = '.txt';    #Default is '.txt'
     $self -> {BIN_FILE_EXTENSION}          = '.txt';    #Default BIN extension is '.txt
     $self -> {FIT_FILE_EXTENSION}          = '.txt';    #Default FIT extension is '.txt
     $self -> {CURRENT_FILE}                = undef;     #Current file in batch job
     $self -> {CURRENT_FILE_INDEX}          = undef;
     $self -> {TOLERANCE}                   = 0.5;       #voltage tolerance default 0.5 mV
     $self -> {BIN_LOW}                     = -80;       #Bin lower limit in mV, default -80 mV
     $self -> {BIN_HIGH}                    = 20;        #Bin upper limit in mV, default 20 mV
     $self -> {BIN_INCREMENT}               = 5;         #Bin increment in mV, default 5 mV

     $self -> {EXPERIMENT_DATA}             = {};        #input batch file instructions (list of files and [peptides] )
     $self -> {MASTER_DATA}                 = {};        #hoh of the master worksheet keeping track of everything
     $self -> {JOINED_DATA}                 = {};        #Joined statistics from Hoh module - (See Hoh.pm: complex hash structure)
     $self -> {BIN_DATA}                    = {};        #hash of hohs for all the voltage bin datasets
     $self -> {FIT_DATA}                    = {};        #hash of hohs for all the fit datasets

     $self -> {EXPERIMENT_KEYS}             = [];        #Key list of hoh made in the order of appearance from the experiment file
     $self -> {VOLTAGE_BINS}                = [];        #List of voltages used in the IV voltage scan
     $self -> {ATF_COLUMNS}                 = [qw(V I CONC)];  #Some column constants used to process Axon Text File (ATF) derived Hohs

     my %args = @_; #Dump arguments into hash if provided
     while (my ($attribute, $value) = each %args) { $self -> {uc($attribute)} = $value };

  return bless($self, $package);                         #return thy self
}
############################### METHOD SUBS ########################################
# Experiment file format example comma-delimited:
#
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
#
#Open experiment file, e.g., exp.txt, to get table of ATF files and peptide concentrations for batch processing
#Each ATF file is recorded as a strip chart where the voltages are scanned per analyte concentration
sub open_experiment_file {
  use Hoh;
  my ($self, $exp_file, $delimiter) = @_;  
  $delimiter = delimiter($self) unless $delimiter;
  die "No delimiter set in open_experiment_file, aborting $! $0" unless $delimiter;
  $exp_file = experiment_file($self) unless $exp_file;
  die "No experiment file set in open_experiment_file, aborting $! $0" unless $exp_file;
  my $exp_hoh =  Hoh->new(); #open exp file as hoh
     $exp_hoh -> delimiter(delimiter($self, $delimiter));
     $exp_hoh -> case_sensitive(1); #since there are file names in the file
     $exp_hoh -> generate_keys(1);
     $exp_hoh -> load(experiment_file($self, $exp_file));
  experiment_keys($self, $exp_hoh -> original_keys);
  my %hoh = $exp_hoh -> hoh;
  experiment_data($self, %hoh);
  return $self
}

#Used to process Episodic Style data acquisition in pClamp
#Allows the data to feed back into the processing pipeline 
#iv_file is cut and pasted text from Excel spreadsheet which is tab delimited
#   cols are: voltage curr1 currerr1 curr2 currerr2 etc. 
#conc_file is space/tab delimited file: first col is concentrations, second
#    col is file names
#Exracts the data from the iv_table and transposes into the series of voltage bins
#Saves the bins and enters the bins into the module's bin_data hash for further 
#    processing by the module
sub open_iv_table {
 my ($self, $iv_file, $conc_file) = @_;
 die "No iv table file specified as first argument of open_iv_table method.\n" unless $iv_file;      
 die "No concentration list file specified as second argument of open_iv_table method.\n" unless $conc_file;
 my ($cr, $t, $cm, $bin_index, $bins) = (chr(13).chr(10), chr(9), chr(44), 0, {});
 my $concs = []; #open conc data into array
 open(FH, "<$conc_file") or die; 
   while (<FH>) { $_  =~ s/\s+$//; push @$concs, [ split("$t",$_) ] }; 
 close(FH);
 my $data = []; # Dump iv data into array of arrays
 open(FH, "<$iv_file") or die; 
   while (<FH>) { $_  =~ s/\s+$//; push @$data, [ split(/\s+/,$_) ] }; 
 close(FH);
 #Transpose and dump data into bins
 foreach my $datarow (@$data) {
   my $bin_key  = 'BIN'.$bin_index++;
   my $bin_file = $bin_key.'.txt';
   open(FHBIN, ">$bin_file") or die; 
   print FHBIN 'CONC'.$cm.'I'.$cm.'IERR'.$cm.'V'.$cr;
   my $voltage = $datarow -> [0];
   my $ii = 0; 
   while ($ii < @$concs) {
     my $row_key = 'ROW'.$ii;
     my $conc          = $concs   -> [$ii] -> [0]; #first column is concentrations 
     my $current       = $datarow -> [2 * ($ii + 1) - 1];
     my $current_error = $datarow -> [2 * ($ii + 1)];
     $bins -> {$bin_key} -> {'ROW'.$ii}   -> {'V'}    = $voltage;
     $bins -> {$bin_key} -> {'ROW'.$ii}   -> {'I'}    = $current;
     $bins -> {$bin_key} -> {'ROW'.$ii}   -> {'IERR'} = $current_error;
     $bins -> {$bin_key} -> {'ROW'.$ii++} -> {'CONC'} = $conc;
     print FHBIN $conc.$cm.$current.$cm.$current_error.$cm.$voltage.$cr;
   };
   close(FHBIN);
 };
 bin_data($self, %$bins);
 return $self
}

#requires a list of directories where the bins reside
#merges different experiments together effectively
sub merge_bin_dirs {
 my ($self, $dirs, $delimiter) = @_;
 die "No directories given in merge_bins, aborting $! $0" unless scalar(@$dirs);
 $delimiter = delimiter($self) unless $delimiter;
 die "No delimiter set in merge_bins, aborting $! $0" unless $delimiter;
 my ($all_bins, $merged, $i, $dir_num) = ([], {}, 0, 0);
 foreach my $dir (@$dirs) { 
   open_bin_dir($self, $dir, $delimiter);
   $all_bins -> [ $i++ ] = +{ bin_data($self) };
 };
 foreach my $bins (@$all_bins) {
   foreach my $bin (keys(%$bins)) {
     my $row = 0;     
     foreach my $key (keys(%{ $bins -> {$bin} })) {
       #to avoid key collisions
       $merged -> {$bin} -> {'DIR'.$dir_num.'ROW'.$row++} = $bins -> {$bin} -> {$key};
     };
   };
   $dir_num++;
 };
 bin_data($self, %$merged);
 return $self
}

sub open_bin_dir {
  use Hoh;
  my ($self, $dir, $delimiter) = @_; 
  $delimiter = delimiter($self) unless $delimiter;
  die "No delimiter set in open_bins, aborting $! $0" unless $delimiter;
  my $bin_data = {}; #hohoh to stuff all the bins
  $dir =~ s!/*$!/! unless ($dir eq ''); #be sure single trailing slash is in place
  my @files;
  opendir (DIR, $dir) or die $!;
    while (my $file = readdir(DIR)) { push @files, $file if ($file =~ /^BIN\d+\./) };
  closedir(DIR);
  foreach my $file (@files) {
    my ($i) = $file =~ m/^BIN(\d+)\./; #get the BIN index from the filename
    my $bin_hoh  =  Hoh->new(); #open exp file as hoh
       $bin_hoh  -> delimiter(delimiter($self, $delimiter));
       $bin_hoh  -> generate_keys(1);
       $bin_hoh  -> load($dir.$file);
       $bin_data -> { 'BIN'.$i } = +{ $bin_hoh -> hoh }; #Key does not have extension
  };
  bin_data($self, %$bin_data);
  return $self
}

sub batch_average_atf_files {
  use Hoh;
  my ($self, $exp_file, $delimiter, $bins, $tol, $start_index, $prefix, $ext) = @_;
  $delimiter = delimiter($self) unless $delimiter;
  $exp_file = experiment_file($self) unless $exp_file;
  open_experiment_file($self, experiment_file($self, $exp_file), delimiter($self, $delimiter));
  $bins  = [ voltage_bins($self) ] unless scalar(@$bins);
  unless (scalar(@$bins)) { compute_voltage_bins_from_limits($self); $bins = [voltage_bins($self)] };
  die "No voltage bins specified in batch_average_atf_files, aborting $! $0" unless scalar(@$bins);
  $tol = tolerance($self) unless $tol;
  print "Tolerance not given in batch_average_atf_files; setting to 0.5 mV.\n" unless $tol;
  $tol = tolerance($self,0.5) unless $tol;
  $start_index = file_index_start($self) unless $start_index;
  print "No start index given in batch_average_atf_files; setting to 1.\n" unless $start_index;
  $start_index = file_index_start($self,1) unless $start_index;
  $prefix = file_prefix($self) unless $prefix; 
  print "No file prefix given in batch_average_atf_files; setting to DATA.\n" unless $prefix;
  $prefix = file_prefix($self,'DATA') unless $prefix; 
  $ext = file_extension($self) unless $ext;
  print "No file extension given in batch_average_atf_files; setting to .txt.\n" unless $ext;
  $ext = file_extension($self,'.txt') unless $ext;
  my $file_index = file_index_start($self, $start_index) - 1;
  my $exp_hash = +{ experiment_data($self) };
  foreach my $key (@{[experiment_keys($self)]}) {
    current_file_index($self, ++$file_index);
    my $atf_hoh =  Hoh->new(); #open atf file as hoh
       $atf_hoh -> load(current_file($self, $exp_hash->{$key}->{'FILE'})); 
       $atf_hoh -> add_scalar_column('CONC', $exp_hash->{$key}->{'CONC'}); #add concentration column
       $atf_hoh -> filekeys(0);
       $atf_hoh -> delimiter(delimiter($self, $delimiter));
       $atf_hoh -> statistics_bin_tolerance('V', [voltage_bins($self, @$bins)], tolerance($self, $tol), [atf_columns($self)]) 
                -> save_statistics(file_prefix($self, $prefix).$file_index.file_extension($self, $ext), [atf_columns($self)]);
    my %data = $atf_hoh -> statistics_data;
    join_statistics_data($self, current_file($self), %data); #key prefix as filename
  }; 
  extract_bin_data($self, $bins, $tol, $cols);
  return $self
}

sub extract_bin_data {
  use Hoh;
  my ($self, $bins, $tol) = @_;
  $bins  = [ voltage_bins($self) ] unless scalar(@$bins);
  die "No voltage bins defined, aborted $! $0" unless scalar(@$bins);
  $tol = tolerance($self) unless $tol;
  $tol = 0.5 unless $tol;
  print "No tolerance set, forcing to 0.5...\n" unless $tol;
  my $bin_hoh =  Hoh->new();
     $bin_hoh -> hoh(joined_data($self));
     $bin_hoh -> delimiter(delimiter($self));
     $bin_hoh -> statistics_bin_tolerance('V', [voltage_bins($self, @$bins)], tolerance($self, $tol), [atf_columns($self)]);
     $bin_hoh -> print_order('V','VERR','I','IERR','CONC','CONCERR');
     $bin_hoh -> save_binned_datasets;
  bin_data($self, ($bin_hoh -> bin_data));
  return $self
}

# Remove numerical data in the bins satisfying $col with $values criteria 
# where $col is a scalar and $values is an array ref.
# The $bin_list are the list of bins (keys to bin hash of hohs) that will be purged
# If no bin_list is given, then all bins are purged of matches to $col and $values. 
# Example bin_list: [ qw(BIN0 BIN1 BIN2) ]
sub remove {
  my ($self, $col, $values, $bin_list) = @_; 
  my $bins = +{ bin_data($self) };
  @$bin_list = keys(%$bins) unless scalar(@$bin_list);
  foreach my $binkey (@$bin_list) {
    my $bin = $bins ->{ $binkey };
    foreach my $rowkey (keys(%$bin)) {
      my $row = $bin -> { $rowkey };
      VALUEMATCH: foreach my $value (@$values) {
        if ($row -> { $col } == $value) { 
          delete $bins -> { $binkey } -> { $rowkey }; 
          last VALUEMATCH;
        };
      };
    };
  };
  bin_data($self,%$bins);
  return $self
}

sub normalize {
  my $self = shift();
  my $bins = +{ bin_data($self) }; 
  die "No bin data to normalize, aborting $! $0" unless scalar(keys(%$bins));
  #Roll through the data to compute Fopen, Fopenerr, theta, and thetaerr
  foreach my $bin_key (keys(%$bins)) {
   my %data =  %{ $bins -> {$bin_key} };
   my ($i_zero, $i_zero_err) = find_i_zero(%data); 
   foreach my $key (@{[keys(%data)]}) {
     my $conc      = $data{$key}{'CONC'};
     my $i         = $data{$key}{'I'};
     my $ierr      = $data{$key}{'IERR'};
     my $logconc   = undef; 
     if ($conc > 0) { $logconc = log($conc)/log(10) } else { $logconc = '--' };
     my $fopen     = $i/$i_zero;
     my $fopen_err = sqrt(($ierr**2)*(1/($i_zero**2)) + ($i_zero_err**2)*(($i**2)/($i_zero**4)));
     my $theta     = undef;
     if ($fopen == 1) { $theta = '--' } else { $theta = $fopen/(1-$fopen) };
     my $theta_err = undef;
     if ($fopen == 1) { $theta_err = '--' } else { $theta_err = sqrt(((1/(1-$fopen) + $fopen/((1-$fopen)**2))**2) * ($fopen_err**2)) };
     my $logq_err  = undef;
     if ($theta != 0) { $logq_err = sqrt( ($theta_err**2) / (($theta**2) * (log(10)**2)) ) } else { $logq_err = '--' };
     my $logq = undef;
     if ($theta > 0) { $logq = log($theta)/log(10) } else { $logq = '--' };
     $data{$key}{'LOGCONC'}  = $logconc;
     $data{$key}{'FOPEN'}    = $fopen;
     $data{$key}{'FOPENERR'} = $fopen_err;
     $data{$key}{'THETA'}    = $theta;
     $data{$key}{'THETAERR'} = $theta_err;
     $data{$key}{'LOGQ'}     = $logq;
     $data{$key}{'LOGQERR'}  = $logq_err;
   };
   $bins -> {$bin_key} = \%data;
 };
 bin_data($self,%$bins);
 save_bins($self);
 return $self
}

sub save_fits {
 my ($self, $fits, $ext) = @_;
 $fits = +{ fit_data($self) } unless scalar(keys(%$fits));
 die "No fit data to save at save_fits, aborting $! $0" unless scalar(keys(%$fits));
 $ext = fit_file_extension($self) unless $ext;
 print "No extension defined in save_fits, trying to use default extension from file_extension.\n" unless $ext;
 $ext = file_extension($self) unless $ext;
 print "No extension defined in save_fits, making extension .txt.\n" unless $ext;
 $ext = '.txt' unless $ext;
 my $dummy = fit_file_extension($self, $ext);
 save_fit($self, $_.fit_file_extension($self), %{ $fits->{$_} }) for keys(%$fits); #saves the files as $key.$ext filenames
 return $self
}

sub save_fit {
 use Hoh;
 my ($self, $file, %fit) = @_;
 die "No file name specified in save_bin, aborting $! $0" unless $file;
 die "No hash of hashes (hoh) fit data given in save_fit. Nothing to save. Aborted $! $0" unless scalar(keys(%fit));
   my $fit_hoh = Hoh->new();
      $fit_hoh -> delimiter(delimiter($self));
      $fit_hoh -> filekeys(0);
      $fit_hoh -> hoh(%fit);
      $fit_hoh -> print_order('LOGCONC','LOGQ','LOGQERR','FIT','RESIDUE');
      $fit_hoh -> save($file);
 return $self
}

sub save_bins {
 my ($self, $bins, $ext) = @_;
 $bins = +{ bin_data($self) } unless scalar(keys(%$bins));
 die "No bin data to save at save_bins, aborting $! $0" unless scalar(keys(%$bins));
 $ext = bin_file_extension($self) unless $ext;
 print "No extension defined in save_bins, trying to use default extension from file_extension.\n" unless $ext;
 $ext = file_extension($self) unless $ext;
 print "No extension defined in save_bins, making extension .txt.\n" unless $ext;
 $ext = '.txt' unless $ext;
 save_bin($self, $_.bin_file_extension($self, $ext), %{ $bins->{$_} }) for keys(%$bins);  #saves the files as $key.$ext filenames
 return $self
}

sub save_bin {
 use Hoh;
 my ($self, $file, %bin) = @_;
 die "No file name specified in save_bin, aborting $! $0" unless $file;
 die "No hash of hashes (hoh) bin data given in save_bin. Nothing to save. Aborted $! $0" unless scalar(keys(%bin));
 my $data_hoh =  Hoh->new();
    $data_hoh -> delimiter(delimiter($self));
    $data_hoh -> filekeys(0);
    $data_hoh -> hoh(%bin);
    $data_hoh -> print_order('LOGCONC','CONC','I','IERR','FOPEN','FOPENERR','THETA','THETAERR','LOGQ','LOGQERR','V');
    $data_hoh -> save($file); #overwrite file with the new columns
 return $self;
}

sub save_master {
 my ($self, $file, %master) = @_; 
 $file = master_file($self) unless $file;
 print "No file name specified in save_master, setting to MASTER.txt" unless $file;
 $file = master_file($self,'MASTER.txt');
 %master = master_data($self) unless scalar(keys(%master));
 die "No hash of hashes (hoh) master data given in save_master. Nothing to save. Aborted $! $0" unless scalar(keys(%master));
 my $hoh = Hoh -> new();
    $hoh -> delimiter(delimiter($self));
    $hoh -> filekeys(0);
    $hoh -> hoh(%master);
    $hoh -> print_order('V','FILE','SLOPE','SLOPEERR','INT','INTERR','RSQUARED','SIGMA','DURBINWATSON');
    $hoh -> save(master_file($self, $file));
 return $self
}

sub hill_analysis {
 use Hoh;
 use Statistics::LineFit;
 my ($self, $bins, $master_file) = @_;
   $master_file = master_file($self) unless $master_file;
   print "No master filename given in hill_analysis; setting as master.txt \n" unless $master_file;
   $master_file = master_file($self,'MASTER.txt') unless $master_file;
   $bins   = +{ bin_data($self) } unless scalar(keys(%$bins)); #bins data sets for experiment are used in the fitting
 die "No bin_data provided to do Hill analysis in hill_analysis" unless scalar(keys(%$bins));
 my $master = {}; #Master Hoh to contain fit summary for the entire experiment
 my $fits   = {}; #Hoh with all the fit hohs for the entire experiment
 #Fit and Save fit; Run a linear regression analysis of y = LOGQ versus x = LOGCONC
 foreach my $bin_key (keys(%$bins)) {  
   my %data = %{ $bins->{$bin_key} };
   my ($fit_index) = $bin_key =~ /BIN(\d+)/; #Extract trailing digits
   my $fit_key = "FIT$fit_index"; #make new fit hash key  
   #NOTE WELL: if other fits are added to module then these Keys may want to be called HILLFIT for example
   #They may be stored in module under HILLFIT_DATA and new methods for saving should be added as needed
   my $fit = Statistics::LineFit->new();
   my @x; my @y; my @yerr; my @v;  #First get the @x and @y arrays together
   foreach my $key (@{[keys(%data)]}) {      #Grab x and y but do not include null '--' xy values
     my ($xx, $yy, $yyerr, $vv) = ($data{$key}{'LOGCONC'}, $data{$key}{'LOGQ'}, $data{$key}{'LOGQERR'}, $data{$key}{'V'});
     if (($xx ne '--') && ($yy ne '--')) { push @x, $xx; push @y, $yy; push @yerr, $yyerr; push @v, $vv };
   };
   $fit->setData(\@x, \@y) or die "Invalid data.\n";
   my ($int, $slope)           = $fit->coefficients;
   defined $int or die "Can't fit line if x values are all equal.\n";
   my ($t_int, $t_slope)       = $fit->tStatistics;
   my @best_fit                = $fit->predictedYs;
   my @residuals               = $fit->residuals;
   my ($var_int, $var_slope)   = $fit->varianceOfEstimates;
   unless (fit_file_extension($self)) { fit_file_extension($self,'.txt') };
   my $fit_filename            = $fit_key.fit_file_extension($self);  #### <===== $i_file need bin filename
   #Place fit parameters, filename, and voltage for each bin in the $master hash using filename as key
   $master -> {$fit_filename} -> {'V'}             = vector_mean(\@v);
   $master -> {$fit_filename} -> {'FILE'}          = $fit_filename;
   $master -> {$fit_filename} -> {'ANALYSIS'}      = 'HILL';
   $master -> {$fit_filename} -> {'SLOPE'}         = $slope;
   $master -> {$fit_filename} -> {'SLOPEERR'}      = sqrt($var_slope);
   $master -> {$fit_filename} -> {'INT'}           = $int;
   $master -> {$fit_filename} -> {'INTERR'}        = sqrt($var_int);
   $master -> {$fit_filename} -> {'RSQUARED'}      = $fit->rSquared;
   $master -> {$fit_filename} -> {'SIGMA'}         = $fit->sigma;
   $master -> {$fit_filename} -> {'DURBINWATSON'}  = $fit->durbinWatson;
   my ($fit_hash, $fit_row_key) = ({},0); #make hoh for the fit vectors
   while (defined($x[0])) {
    $fit_hash -> {$fit_row_key}   -> {'LOGCONC'} = shift(@x); 
    $fit_hash -> {$fit_row_key}   -> {'LOGQ'}    = shift(@y);
    $fit_hash -> {$fit_row_key}   -> {'LOGQERR'} = shift(@yerr);
    $fit_hash -> {$fit_row_key}   -> {'FIT'}     = shift(@best_fit); 
    $fit_hash -> {$fit_row_key++} -> {'RESIDUE'} = shift(@residuals);
   };
   $fits -> {$fit_key} = $fit_hash; #Add the fit_hash to the fits hohoh (hash of hash of hashes)
 };
 fit_data($self,%$fits);
 save_fits($self);
 save_master($self,master_file($self,$master_file),master_data($self,%$master));
 return $self;
}

sub join_statistics_data { 
  my ($self, $key_prefix, %data) = @_;
  print "No key prefix given in join_statistics_data, making a random string.\n" unless $key_prefix;
  $key_prefix = random_string(32) unless $key_prefix;
  print "No hash data given in join_statistics_data. Nothing to join but continuing on $! $0" unless scalar(keys(%data));
  my %j = joined_data($self);
  $j{$key_prefix.$_} = $data{$_} for keys(%data);
  joined_data($self,%j);
  return $self
}

#given low limit and high limit and an increment compute the bins in between
sub compute_voltage_bins_from_limits {
  my ($self,$low,$high,$inc) = @_;
  my $bins = [];
  $low  = bin_low($self) unless defined($low);
  $high = bin_high($self) unless defined($high);
  $inc  = bin_increment($self) unless $inc;
  print "No low bin voltage given in compute_voltage_bins_from_limits, setting to -100 mV.\n" unless $low;
  print "No high bin voltage given in compute_voltage_bins_from_limits, setting to +100 mV.\n" unless $high;
  print "No increment bin value given in compute_voltage_bins_from_limits, setting to 5 mV.\n" unless $inc;
  $low  = -100 unless defined($low);
  $high = 100 unless defined($high);
  $inc  = 5 unless $inc;
  for (my $bin = $low; $bin <= $high; $bin += $inc) { push @$bins, $bin };
  bin_low($self,$low); 
  bin_high($self,$high);
  bin_increment($self,$inc);
  voltage_bins($self,@$bins);
  return $self
}

#computes i_zero and i_zero_err from a data bin hoh
sub find_i_zero {
 my %data = @_;
   my @i_vals; my @ierr_vals;
   foreach my $key (@{[keys(%data)]}) {
     my ($conc, $i, $ierr) = ($data{$key}{'CONC'}, $data{$key}{'I'}, $data{$key}{'IERR'});
     if ((0+$conc) == 0) { push @i_vals, $i; push @ierr_vals, $ierr };
   };
 return (vector_mean(\@i_vals), vector_mean(\@ierr_vals))
}

#computes mean of reference to one-dimensional array
# returns undef for a vector that has zero values to avoid division by zero
sub vector_mean { my ($a, $s, $c, $v) = (shift(), undef, undef, undef); $c = @$a; $s += $_ for @$a; $v = $s/$c if $c; return $v }

#compute random alphanumerical string of $length as only argument
sub random_string { my $length = shift; my $string = join'', map +(0..9,'a'..'z','A'..'Z')[rand(10+26*2)], 1..$length; return $string }

############################# PROPERTY SETS/GETS ###################################

###ALL HASHES

sub experiment_data {
  my $self = shift;
  if (@_) { %{ $self->{EXPERIMENT_DATA} } = @_ };
  return %{ $self->{EXPERIMENT_DATA} };
}

sub master_data {
  my $self = shift;
  if (@_) { %{ $self->{MASTER_DATA} } = @_ };
  return %{ $self->{MASTER_DATA} };
}

sub joined_data {
  my $self = shift;
  if (@_) { %{ $self->{JOINED_DATA} } = @_ };
  return %{ $self->{JOINED_DATA} };
}

sub bin_data {
  my $self = shift;
  if (@_) { %{ $self->{BIN_DATA} } = @_ };
  return %{ $self->{BIN_DATA} };
}

sub fit_data {
  my $self = shift;
  if (@_) { %{ $self->{FIT_DATA} } = @_ };
  return %{ $self->{FIT_DATA} };
}

sub current_fit_data {
  my $self = shift;
  if (@_) { %{ $self->{CURRENT_FIT_DATA} } = @_ };
  return %{ $self->{CURRENT_FIT_DATA} };
}
#### ALL ARRAYS ####

sub experiment_keys {
 my $self = shift;
 if (@_) { @{ $self->{EXPERIMENT_KEYS} } = @_ };
 return @{ $self->{EXPERIMENT_KEYS} };
}

sub voltage_bins {
 my $self = shift;
 if (@_) { @{ $self->{VOLTAGE_BINS} } = @_ };
 return @{ $self->{VOLTAGE_BINS} };
}

sub atf_columns {
 my $self = shift;
 if (@_) { @{ $self->{ATF_COLUMNS} } = @_ };
 return @{ $self->{ATF_COLUMNS} };
}

###ALL SCALARS

sub experiment_file {
 my $self = shift;
 $self->{EXPERIMENT_FILE} = shift if @_;
 return $self->{EXPERIMENT_FILE};
}

sub master_file {
 my $self = shift;
 $self->{MASTER_FILE} = shift if @_;
 return $self->{MASTER_FILE};
}

sub delimiter {
 my $self = shift;
 $self->{DELIMITER} = shift if @_;
 return $self->{DELIMITER};
}

sub file_index_start {
 my $self = shift;
 $self->{FILE_INDEX_START} = shift if @_;
 return $self->{FILE_INDEX_START};
}

sub file_prefix {
 my $self = shift;
 $self->{FILE_PREFIX} = shift if @_;
 return $self->{FILE_PREFIX};
}

sub file_extension {
 my $self = shift;
 $self->{FILE_EXTENSION} = shift if @_;
 return $self->{FILE_EXTENSION};
}

sub bin_file_extension {
 my $self = shift;
 $self->{BIN_FILE_EXTENSION} = shift if @_;
 return $self->{BIN_FILE_EXTENSION};
}

sub fit_file_extension {
 my $self = shift;
 $self->{FIT_FILE_EXTENSION} = shift if @_;
 return $self->{FIT_FILE_EXTENSION};
}

sub current_file {
 my $self = shift;
 $self->{CURRENT_FILE} = shift if @_;
 return $self->{CURRENT_FILE};
}

sub current_file_index {
 my $self = shift;
 $self->{CURRENT_FILE_INDEX} = shift if @_;
 return $self->{CURRENT_FILE_INDEX};
}

sub tolerance {
 my $self =shift;
 $self->{TOLERANCE} = shift if @_;
 return $self->{TOLERANCE};
}

sub bin_low {
 my $self =shift;
 $self->{BIN_LOW} = shift if @_;
 return $self->{BIN_LOW};
}

sub bin_high {
 my $self =shift;
 $self->{BIN_HIGH} = shift if @_;
 return $self->{BIN_HIGH};
}

sub bin_increment {
 my $self =shift;
 $self->{BIN_INCREMENT} = shift if @_;
 return $self->{BIN_INCREMENT};
}

return 1; #always return 1 at the end of the module
