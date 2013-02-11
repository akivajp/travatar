#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

# Directory options
my $WORK_DIR = ""; # The working directory to use
my $TRAVATAR_DIR = ""; # The directory of travatar
my $BIN_DIR = ""; # A directory for external bin files (mainly GIZA)

# Parallelization options
my $THREADS = "1"; # The number of threads to use

# Input/output options
my $SRC_FILE = ""; # The source file you want to train on
my $SRC_WORDS = ""; # A file of plain-text sentences from the source
my $SRC_FORMAT = "penn"; # The source file format (penn/egret)

my $TRG_FILE = ""; # The target file you want to train on
my $TRG_FORMAT = "word"; # The target file format (word/penn/egret)
my $TRG_WORDS = ""; # A file of plain-text sentences from the target

# Files containing lexical translation probabilities
my $LEX_SRCTRG = ""; # of the source word given the target P(f|e)
my $LEX_TRGSRC = ""; # of the target word given the source P(e|f)

# Alignment options
my $ALIGN_FILE = ""; # A file containing alignments
my $ALIGN = "giza"; # The type of alignment to use (giza)
my $SYMMETRIZE = "grow"; # The type of symmetrization to use (grow)

# Rule extraction options
my $NORMALIZE = "false"; # Normalize rule counts to probabilities
my $BINARIZE = "right"; # Binarize trees in a certain direction
my $COMPOSE = "4"; # The number of rules to compose
my $ATTACH = "top"; # Where to attach rules
my $NONTERM_LEN = "2"; # The maximum number of non-terminals in a rule
my $TERM_LEN = "10"; # The maximum number of terminals in a rule
my $NBEST_RULES = "20"; # The maximum number of rules for each source

# Model files
my $TM_FILE = "";
my $LM_FILE = "";
my $NO_LM = "false";
my $CONFIG_FILE = "";

GetOptions(
    "work_dir=s" => \$WORK_DIR,
    "travatar_dir=s" => \$TRAVATAR_DIR,
    "bin_dir=s" => \$BIN_DIR,
    "threads=s" => \$THREADS,
    "src_file=s" => \$SRC_FILE,
    "src_words=s" => \$SRC_WORDS,
    "src_format=s" => \$SRC_FORMAT,
    "trg_file=s" => \$TRG_FILE,
    "trg_words=s" => \$TRG_WORDS,
    "trg_format=s" => \$TRG_FORMAT,
    "lex_srctrg=s" => \$LEX_SRCTRG,
    "lex_trgsrc=s" => \$LEX_TRGSRC,
    "align_file=s" => \$ALIGN_FILE,
    "nbest_rules=s" => \$NBEST_RULES,
    "normalize=s" => \$NORMALIZE,
    "binarize=s" => \$BINARIZE,
    "compose=s" => \$COMPOSE,
    "attach=s" => \$ATTACH,
    "nonterm_len=s" => \$NONTERM_LEN,
    "term_len=s" => \$TERM_LEN,
    "tm_file=s" => \$TM_FILE,
    "lm_file=s" => \$LM_FILE,
    "config_file=s" => \$CONFIG_FILE,
    "no_lm=s" => \$NO_LM,
);
if(@ARGV != 0) {
    print STDERR "Usage: $0 --work-dir=work --src-file=src.txt --trg-file=trg.txt\n";
    exit 1;
}

# Sanity check!
((!$WORK_DIR) or (!$SRC_FILE) or (!$TRG_FILE) or (!$TRAVATAR_DIR) or (!$BIN_DIR)) and
    die "Must specify -work_dir ($WORK_DIR) -src_file ($SRC_FILE) -trg_file ($TRG_FILE) -travatar_dir ($TRAVATAR_DIR) -bin_dir ($BIN_DIR)";
for($SRC_FILE, $TRG_FILE, $TRAVATAR_DIR, $SRC_WORDS, $TRG_WORDS, $ALIGN_FILE, $LEX_SRCTRG, $LEX_TRGSRC, $LM_FILE) {
    die "File specified but not found: $_" if $_ and not -e $_;
}
((not $LM_FILE) and ($NO_LM ne "true")) and
    die "Must specify an LM file using -lm_file, or choose to not use an LM by setting -no_lm true";
((-e $WORK_DIR) or not safesystem("mkdir $WORK_DIR")) and
    die "Working directory $WORK_DIR already exists or could not be created";

# Steps:
# 1 -> Prepare Data
# 2 -> Create Alignments
# 3 -> Create lexical translation probabilities
# 4 -> Extract and Score Rule Table
# 5 -> Create 

# ******** 1: Prepare Data **********
print STDERR "(1) Preparing data @ ".`date`;

# Convert trees into plain text sentences
$TRG_WORDS = $TRG_FILE if((not $TRG_WORDS) and ($TRG_FORMAT eq "word"));
(safesystem("mkdir $WORK_DIR/data") or die) if ((not $SRC_WORDS) or (not $TRG_WORDS));
if(not $SRC_WORDS) {
    $SRC_WORDS = "$WORK_DIR/data/src.word";
    safesystem("$TRAVATAR_DIR/src/bin/tree-converter -input_format $SRC_FORMAT -output_format word < $SRC_FILE > $SRC_WORDS") or die;
}
if(not $TRG_WORDS) {
    $TRG_WORDS = "$WORK_DIR/data/trg.word";
    safesystem("$TRAVATAR_DIR/src/bin/tree-converter -input_format $TRG_FORMAT -output_format word < $TRG_FILE > $TRG_WORDS") or die;
}

# ****** 2: Create Alignments *******
print STDERR "(2) Creating alignments @ ".`date`;

# Alignment with GIZA++
if(not $ALIGN_FILE) {
    safesystem("mkdir $WORK_DIR/align") or die;
    $ALIGN_FILE = "$WORK_DIR/align/align.txt";
    if($ALIGN eq "giza") {
        my $GIZA = "$BIN_DIR/GIZA++";
        my $SNT2COOC = "$BIN_DIR/snt2cooc.out";
        my $PLAIN2SNT = "$BIN_DIR/plain2snt.out";
        my $MKCLS = "$BIN_DIR/mkcls";
        ((not -x $GIZA) or (not -x $SNT2COOC)) and
            die "Could not execute GIZA ($GIZA) or snt2cooc ($SNT2COOC)";
        # Make the classes with mkcls
        my $SRC_CLASSES = "$WORK_DIR/align/src.cls";
        my $TRG_CLASSES = "$WORK_DIR/align/trg.cls";
        my $SRC_MKCLS = "$MKCLS -c50 -n2 -p$SRC_WORDS -V$SRC_CLASSES opt";
        my $TRG_MKCLS = "$MKCLS -c50 -n2 -p$TRG_WORDS -V$TRG_CLASSES opt";
        run_two($SRC_MKCLS, $TRG_MKCLS);
        # Create the vcb files and maps
        my $SRC_VCB = "$WORK_DIR/align/src.vcb"; 
        my %src_vcb = create_vcb($SRC_WORDS, $SRC_VCB);
        my $TRG_VCB = "$WORK_DIR/align/trg.vcb";
        my %trg_vcb = create_vcb($TRG_WORDS, $TRG_VCB);
        # Convert GIZA++ into snt format
        my $STPREF = "$WORK_DIR/align/src-trg";
        my $TSPREF = "$WORK_DIR/align/trg-src";
        create_snt($SRC_WORDS, \%src_vcb, $TRG_WORDS, \%trg_vcb, "$STPREF.snt");
        create_snt($TRG_WORDS, \%trg_vcb, $SRC_WORDS, \%src_vcb, "$TSPREF.snt");
        # Prepare the data for GIZA with snt2cooc
        safesystem("$SNT2COOC $SRC_VCB $TRG_VCB $STPREF.snt > $STPREF.cooc") or die;
        safesystem("$SNT2COOC $TRG_VCB $SRC_VCB $TSPREF.snt > $TSPREF.cooc") or die;
        # Run GIZA (in parallel?)
        my $GIZA_SRCTRG_CMD = "$GIZA -CoocurrenceFile $STPREF.cooc -c $STPREF.snt -m1 5 -m2 0 -m3 3 -m4 3 -model1dumpfrequency 1 -model4smoothfactor 0.4 -nodumps 1 -nsmooth 4 -o $STPREF.giza -onlyaldumps 1 -p0 0.999 -s $SRC_VCB -t $TRG_VCB";
        my $GIZA_TRGSRC_CMD = "$GIZA -CoocurrenceFile $TSPREF.cooc -c $TSPREF.snt -m1 5 -m2 0 -m3 3 -m4 3 -model1dumpfrequency 1 -model4smoothfactor 0.4 -nodumps 1 -nsmooth 4 -o $TSPREF.giza -onlyaldumps 1 -p0 0.999 -s $TRG_VCB -t $SRC_VCB";
        run_two($GIZA_SRCTRG_CMD, $GIZA_TRGSRC_CMD);
        # Symmetrize the alignments
        safesystem("$TRAVATAR_DIR/script/train/symmetrize.pl $WORK_DIR/align/src-trg.giza.A3.final $WORK_DIR/align/trg-src.giza.A3.final > $ALIGN_FILE") or die;
    } else {
        die "Unknown alignment type $ALIGN";
    }
}

# ****** 3: Create Lexical Translation Probabilities *******
print STDERR "(3) Creating lexical translation probabilities @ ".`date`;

# Create the lexical translation probabilities
if(not ($LEX_SRCTRG and $LEX_TRGSRC)) {
    safesystem("mkdir $WORK_DIR/lex") or die;
    # Write only the non-specified values
    my $WRITE_SRCTRG = ($LEX_SRCTRG ? "/dev/null" : "$WORK_DIR/lex/src_given_trg.lex");
    $LEX_SRCTRG = $WRITE_SRCTRG if not $LEX_SRCTRG;
    my $WRITE_TRGSRC = ($LEX_TRGSRC ? "/dev/null" : "$WORK_DIR/lex/trg_given_src.lex");
    $LEX_TRGSRC = $WRITE_TRGSRC if not $LEX_TRGSRC;
    # Run the program
    safesystem("$TRAVATAR_DIR/script/train/align2lex.pl $SRC_WORDS $TRG_WORDS $ALIGN_FILE $WRITE_SRCTRG $WRITE_TRGSRC") or die;
}

# ****** 4: Create the model file *******
print STDERR "(4) Creating model @ ".`date`;

if(not $TM_FILE) {
    safesystem("mkdir $WORK_DIR/model") or die;
    # First extract the rules
    my $EXTRACT_FILE = "$WORK_DIR/model/extract.gz";
    my $EXTRACT_OPTIONS = "-normalize_probs $NORMALIZE -binarize $BINARIZE -compose $COMPOSE -attach $ATTACH -nonterm_len $NONTERM_LEN -term_len $TERM_LEN";
    safesystem("$TRAVATAR_DIR/src/bin/forest-extractor $EXTRACT_OPTIONS $SRC_FILE $TRG_FILE $ALIGN_FILE | gzip -c > $EXTRACT_FILE") or die;
    # Then, score the rules (in parallel?)
    my $RT_SRCTRG = "$WORK_DIR/model/rule-table.src-trg.gz"; 
    my $RT_TRGSRC = "$WORK_DIR/model/rule-table.trg-src.gz"; 
    my $RT_SRCTRG_CMD = "zcat $EXTRACT_FILE | LC_ALL=C sort | $TRAVATAR_DIR/script/train/score-t2s.pl --top-n=$NBEST_RULES --lex-prob-file=$LEX_TRGSRC | gzip > $RT_SRCTRG";
    my $RT_TRGSRC_CMD = "zcat $EXTRACT_FILE | $TRAVATAR_DIR/script/train/reverse-rt.pl | LC_ALL=C sort | $TRAVATAR_DIR/script/train/score-t2s.pl --top-n=0 --lex-prob-file=$LEX_SRCTRG --prefix=fge | $TRAVATAR_DIR/script/train/reverse-rt.pl | LC_ALL=C sort | gzip > $RT_TRGSRC";
    run_two($RT_SRCTRG_CMD, $RT_TRGSRC_CMD);
    # Finally, combine the table
    $TM_FILE = "$WORK_DIR/model/rule-table.gz";
    safesystem("$TRAVATAR_DIR/script/train/combine-rt.pl $RT_TRGSRC $RT_SRCTRG | gzip > $TM_FILE") or die;
}

# ******* 5: Create a configuration file ********
print STDERR "(5) Creating configuration @ ".`date`;

if(not $CONFIG_FILE) {
    (safesystem("mkdir $WORK_DIR/model") or die) if (not -e "$WORK_DIR/model");
    my $TINI_FILE = "$WORK_DIR/model/travatar.ini";
    open TINI, ">:utf8", $TINI_FILE or die "Couldn't open $TINI_FILE\n";
    print TINI "[tm_file]\n$TM_FILE\n\n";
    print TINI "[lm_file]\n$LM_FILE\n\n" if ($NO_LM ne "true");
    print TINI "[binarize]\n$BINARIZE\n\n"; 
    # Default values for the weights
    print TINI "[weight_vals]\negfp=0.05\negfl=0.05\nfgep=0.05\nfgel=0.05\nlm=0.3\nw=0.3\np=-0.15\nunk=0\nlfreq=0.05\n\n";
    close TINI;
    print "Finished training! You can find the configuation file in:\n$TINI_FILE\n";
}

# Finish training

################ Functions ##################

# Adapted from Moses's train-model.perl
sub safesystem {
  print STDERR "Executing: @_\n";
  system(@_);
  if ($? == -1) {
      print STDERR "ERROR: Failed to execute: @_\n  $!\n";
      exit(1);
  }
  elsif ($? & 127) {
      printf STDERR "ERROR: Execution of: @_\n  died with signal %d, %s coredump\n",
          ($? & 127),  ($? & 128) ? 'with' : 'without';
      exit(1);
  }
  else {
    my $exitcode = $? >> 8;
    print STDERR "Exit code: $exitcode\n" if $exitcode;
    return ! $exitcode;
  }
}

sub create_vcb {
    my ($words, $vcb) = @_;
    # Read and count the vcb
    open WORDS, "<:utf8", $words or die "Couldn't open $words\n";
    my %vals;
    while(<WORDS>) {
        chomp;
        for(split(/ +/)) { $vals{$_}++; }
    }
    close WORDS;
    delete $vals{""};
    # Write the vcb
    open VCB, ">:utf8", $vcb or die "Couldn't open $vcb\n";
    print VCB "1\tUNK\t0\n";
    my $id=2;
    for(sort keys %vals) {
        printf VCB "%d\t%s\t%d\n",$id,$_,$vals{$_};
        $vals{$_} = $id++;
    }
    close VCB;
    return %vals;
}

sub create_snt {
    my ($src_wrd, $src_vcb, $trg_wrd, $trg_vcb, $out_file) = @_;
    open SRC, "<:utf8", $src_wrd or die "Couldn't open $src_wrd\n";
    open TRG, "<:utf8", $trg_wrd or die "Couldn't open $trg_wrd\n";
    open OUT, ">:utf8", $out_file or die "Couldn't open $out_file\n";
    my ($s, $t);
    while(1) {
        $s = <SRC>; $t = <TRG>;
        die "Uneven sentences in input and output" if(defined($s) != defined($t));
        last if not defined($s);
        chomp $s; chomp $t;
        print OUT "1\n".
                  join(" ", map { $src_vcb->{$_} ? $src_vcb->{$_} : 1 } split(/ /, $s))."\n".
                  join(" ", map { $trg_vcb->{$_} ? $trg_vcb->{$_} : 1 } split(/ /, $t))."\n";
    }
    close SRC; close TRG; close OUT;
}

sub run_two {
    @_ == 2 or die "run_two handles two commands, got @_\n";
    my ($CMD1, $CMD2) = @_;
    if($THREADS > 1) {
	    my $pid = fork();
	    die "ERROR: couldn't fork" unless defined $pid;
        if(!$pid) {
            safesystem("$CMD1") or die;
            exit 0;
        } else {
            safesystem("$CMD2") or die;
            waitpid($pid, 0);
        }
    } else {
        safesystem("$CMD1") or die;
        safesystem("$CMD2") or die;
    }
}