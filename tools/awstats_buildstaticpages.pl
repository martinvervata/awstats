#!/usr/bin/perl
# With some other Unix Os, first line may be
#!/usr/local/bin/perl
# With Apache for Windows and ActiverPerl, first line may be
#!C:/Program Files/ActiveState/bin/perl
#-Description-------------------------------------------
# Launch awstats with -staticlinks option to build all static pages.
# See COPYING.TXT file about AWStats GNU General Public License.
#-------------------------------------------------------
# $Revision$ - $Author$ - $Date$

# use strict is commented to make AWStats working with old perl.
use strict;no strict "refs";
#use warnings;		# Must be used in test mode only. This reduce a little process speed
#use diagnostics;	# Must be used in test mode only. This reduce a lot of process speed
#use Thread;


#-------------------------------------------------------
# Defines
#-------------------------------------------------------
my $REVISION='$Revision$'; $REVISION =~ /\s(.*)\s/; $REVISION=$1;
my $VERSION="1.2 (build $REVISION)";

# ---------- Init variables --------
my $Debug=0;
my $DIR;
my $PROG;
my $Extension;
my $SiteConfig;
my $Update=0;
my $BuildPDF=0;
my $Date=0;
my $Lang;
my $YearRequired;
my $MonthRequired;
my $Awstats='awstats.pl';
my $AwstatsDir='';
my $HtmlDoc='htmldoc';		# ghtmldoc.exe
my $StaticExt='html';
my $DirIcons='';
my $OutputDir='';
my $OutputSuffix;
my $OutputFile;
my @pages=();
my @OutputList=();
my $FileConfig;
my $FileSuffix;
my $SiteConfig;
use vars qw/
$ShowDomainsStats $ShowHostsStats $ShowAuthenticatedUsers $ShowRobotsStats
$ShowEMailSenders $ShowEMailReceivers $ShowSessionsStats $ShowPagesStats $ShowFileTypesStats
$ShowOSStats $ShowBrowsersStats $ShowScreenSizeStats $ShowOriginStats $ShowKeyphrasesStats
$ShowKeywordsStats $ShowMiscStats $ShowHTTPErrorsStats $ShowSMTPErrorsStats
/;


#-------------------------------------------------------
# Functions
#-------------------------------------------------------

#------------------------------------------------------------------------------
# Function:		Write error message and exit
# Parameters:	$message
# Input:		None
# Output:		None
# Return:		None
#------------------------------------------------------------------------------
sub error {
	print "Error: $_[0].\n";
    exit 1;
}

#------------------------------------------------------------------------------
# Function:		Write a warning message
# Parameters:	$message
# Input:		$WarningMessage %HTMLOutput
# Output:		None
# Return:		None
#------------------------------------------------------------------------------
sub warning {
	my $messagestring=shift;
	debug("$messagestring",1);
#	if ($WarningMessages) {
#    	if ($HTMLOutput) {
#    		$messagestring =~ s/\n/\<br\>/g;
#    		print "$messagestring<br>\n";
#    	}
#    	else {
	    	print "$messagestring\n";
#    	}
#	}
}

#------------------------------------------------------------------------------
# Function:     Write debug message and exit
# Parameters:   $string $level
# Input:        %HTMLOutput  $Debug=required level  $DEBUGFORCED=required level forced
# Output:		None
# Return:		None
#------------------------------------------------------------------------------
sub debug {
	my $level = $_[1] || 1;
	if ($Debug >= $level) {
		my $debugstring = $_[0];
		if ($ENV{"GATEWAY_INTERFACE"}) { $debugstring =~ s/^ /&nbsp&nbsp /; $debugstring .= "<br>"; }
		print localtime(time)." - DEBUG $level - $debugstring\n";
	}
}

#------------------------------------------------------------------------------
# Function:     Read config file
# Parameters:	-
# Input:        $DIR $PROG $SiteConfig
# Output:		Global variables
# Return:		-
#------------------------------------------------------------------------------
sub Read_Config {
	# Check config file in common possible directories :
	# Windows :                   	"$DIR" (same dir than awstats.pl)
	# Mandrake and Debian package :	"/etc/awstats"
	# FHS standard, Suse package : 	"/etc/opt/awstats"
	# Other possible directories :	"/etc", "/usr/local/etc/awstats"
	my @PossibleConfigDir=("$AwstatsDir","$DIR","/etc/awstats","/etc/opt/awstats","/etc","/usr/local/etc/awstats");

	# Open config file
	$FileConfig=$FileSuffix='';
	foreach my $dir (@PossibleConfigDir) {
		my $searchdir=$dir;
		if ($searchdir && $searchdir !~ /[\\\/]$/) { $searchdir .= "/"; }
		if (open(CONFIG,"${searchdir}awstats.$SiteConfig.conf")) 	{ $FileConfig="${searchdir}awstats.$SiteConfig.conf"; $FileSuffix=".$SiteConfig"; last; }
		if (open(CONFIG,"${searchdir}awstats.conf"))  				{ $FileConfig="${searchdir}awstats.conf"; $FileSuffix=''; last; }
	}
	if (! $FileConfig) { error("Couldn't open config file \"awstats.$SiteConfig.conf\" nor \"awstats.conf\" : $!"); }

	# Analyze config file content and close it
	&Parse_Config( *CONFIG , 1 , $FileConfig);
	close CONFIG;
}

#------------------------------------------------------------------------------
# Function:     Parse content of a config file
# Parameters:	opened file handle, depth level, file name
# Input:        -
# Output:		Global variables
# Return:		-
#------------------------------------------------------------------------------
sub Parse_Config {
    my ( $confighandle ) = $_[0];
	my $level = $_[1];
	my $configFile = $_[2];
	my $versionnum=0;
	my $conflinenb=0;
	
	if ($level > 10) { error("$PROG can't read down more than 10 level of includes. Check that no 'included' config files include their parent config file (this cause infinite loop)."); }

   	while (<$confighandle>) {
		chomp $_; s/\r//;
		$conflinenb++;

		# Extract version from first line
		if (! $versionnum && $_ =~ /^# AWSTATS CONFIGURE FILE (\d+).(\d+)/i) {
			$versionnum=($1*1000)+$2;
			#if ($Debug) { debug(" Configure file version is $versionnum",1); }
			next;
		}

		if ($_ =~ /^\s*$/) { next; }

		# Check includes
		if ($_ =~ /^Include "([^\"]+)"/ || $_ =~ /^#include "([^\"]+)"/) {	# #include kept for backward compatibility
		    my $includeFile = $1;
			if ($Debug) { debug("Found an include : $includeFile",2); }
		    if ( $includeFile !~ /^[\\\/]/ ) {
			    # Correct relative include files
				if ($FileConfig =~ /^(.*[\\\/])[^\\\/]*$/) { $includeFile = "$1$includeFile"; }
			}
			if ($level > 1) {
				warning("Warning: Perl versions before 5.6 cannot handle nested includes");
				next;
			}
		    if ( open( CONFIG_INCLUDE, $includeFile ) ) {
				&Parse_Config( *CONFIG_INCLUDE , $level+1, $includeFile);
				close( CONFIG_INCLUDE );
		    }
		    else {
				error("Could not open include file: $includeFile" );
		    }
			next;
		}

		# Remove comments
		if ($_ =~ /^#/) { next; }
		$_ =~ s/\s#.*$//;

		# Extract param and value
		my ($param,$value)=split(/=/,$_,2);
		$param =~ s/^\s+//; $param =~ s/\s+$//;

		# If not a param=value, try with next line
		if (! $param) { warning("Warning: Syntax error line $conflinenb in file '$configFile'. Config line is ignored."); next; }
		if (! defined $value) { warning("Warning: Syntax error line $conflinenb in file '$configFile'. Config line is ignored."); next; }

		if ($value) {
			$value =~ s/^\s+//; $value =~ s/\s+$//;
			$value =~ s/^\"//; $value =~ s/\";?$//;
			# Replace __MONENV__ with value of environnement variable MONENV
			while ($value =~ /__(\w+)__/) {	my $var=$1;	$value =~ s/__${var}__/$ENV{$var}/g; }
		}

		# If parameters was not found previously, defined variable with name of param to value
		$$param=$value;
	}

	if ($Debug) { debug("Config file read was \"$configFile\" (level $level)"); }
}




#-------------------------------------------------------
# MAIN
#-------------------------------------------------------
($DIR=$0) =~ s/([^\/\\]*)$//; ($PROG=$1) =~ s/\.([^\.]*)$//; $Extension=$1;

my $QueryString=''; for (0..@ARGV-1) { $QueryString .= "$ARGV[$_]&"; }

if ($QueryString =~ /(^|-|&)month=(year)/i) { error("month=year is a deprecated option. Use month=all instead."); }

if ($QueryString =~ /(^|-|&)debug=(\d+)/i)			{ $Debug=$2; }
if ($QueryString =~ /(^|-|&)config=([^&]+)/i)		{ $SiteConfig="$2"; }
if ($QueryString =~ /(^|-|&)awstatsprog=([^&]+)/i)	{ $Awstats="$2"; }
if ($QueryString =~ /(^|-|&)buildpdf=([^&]+)/i)		{ $HtmlDoc="$2"; $BuildPDF=1; }
if ($QueryString =~ /(^|-|&)staticlinksext=([^&]+)/i)	{ $StaticExt="$2"; }
if ($QueryString =~ /(^|-|&)dir=([^&]+)/i)			{ $OutputDir="$2"; }
if ($QueryString =~ /(^|-|&)diricons=([^&]+)/i)		{ $DirIcons="$2"; }
if ($QueryString =~ /(^|-|&)update/i)				{ $Update=1; }
if ($QueryString =~ /(^|-|&)date/i)					{ $Date=1; }
if ($QueryString =~ /(^|-|&)year=(\d\d\d\d)/i) 		{ $YearRequired="$2"; }
if ($QueryString =~ /(^|-|&)month=(\d\d)/i || $QueryString =~ /(^|-|&)month=(all)/i) { $MonthRequired="$2"; }
if ($QueryString =~ /(^|-|&)lang=([^&]+)/i)			{ $Lang="$2"; }

if ($OutputDir) { if ($OutputDir !~ /[\\\/]$/) { $OutputDir.="/"; } }

if (! $SiteConfig) {
	print "----- $PROG $VERSION (c) Laurent Destailleur -----\n";
	print "$PROG allows you to launch AWStats with -staticlinks option\n";
	print "to build all possible pages allowed by AWStats -output option.\n";
	print "\n";
	print "Usage:\n";
	print "$PROG.$Extension (awstats_options) [awstatsbuildstaticpages_options]\n";
	print "\n";
	print "  where awstats_options are any option known by AWStats\n";
	print "   -config=configvalue is value for -config parameter (REQUIRED)\n";
	print "   -update             option used to update statistics before to generate pages\n";
	print "   -lang=LL            to output a HTML report in language LL (en,de,es,fr,...)\n";
	print "   -month=MM           to output a HTML report for an old month=MM\n";
	print "   -year=YYYY          to output a HTML report for an old year=YYYY\n";
	print "\n";
	print "  and awstatsbuildstaticpages_options can be\n";
	print "   -awstatsprog=pathtoawstatspl AWStats software (awstats.pl) path\n";
	print "   -dir=outputdir               Output directory for generated pages\n";
	print "   -date                        Used to add build date in built pages file name\n";
	print "   -staticlinksext=xxx          For pages with .xxx extension instead of .html\n";
	print "   -buildpdf[=pathtohtmldoc]    Build a PDF file after building HTML pages.\n";
	print "                                 Output directory must contains icon directory\n";
	print "                                 when this option is used (need 'htmldoc').\n";
	print "\n";
	print "New versions and FAQ at http://awstats.sourceforge.net\n";
	exit 0;
}


my $retour;

# Check if AWSTATS prog is found
my $AwstatsFound=0;
if (-s "$Awstats") { $AwstatsFound=1; }
elsif (-s "/usr/local/awstats/wwwroot/cgi-bin/awstats.pl") {
	$Awstats="/usr/local/awstats/wwwroot/cgi-bin/awstats.pl";
	$AwstatsFound=1;
}
if (! $AwstatsFound) {
	error("Can't find AWStats program ('$Awstats').\nUse -awstatsprog option to solve this");
	exit 1;
}
$AwstatsDir=$Awstats; $AwstatsDir =~ s/[\\\/][^\\\/]*$//;
debug("AwstatsDir=$AwstatsDir");

# Check if HTMLDOC prog is found
if ($BuildPDF) {
	my $HtmlDocFound=0;
	if (-s "$HtmlDoc") { $HtmlDocFound=1; }
	elsif (-s "/usr/bin/htmldoc") {
		$HtmlDoc='/usr/bin/htmldoc';
		$HtmlDocFound=1;
	}
	if (! $HtmlDocFound) {
		error("Can't find htmldoc program ('$HtmlDoc').\nUse -buildpdf=htmldocprog option to solve this");
		exit 1;
	}
}

# Read config file (here SiteConfig is defined)
&Read_Config;

# Define list of output files
if ($ShowDomainsStats) { push @OutputList,'alldomains'; }
if ($ShowHostsStats) { push @OutputList,'allhosts'; push @OutputList,'lasthosts'; push @OutputList,'unknownip'; }
if ($ShowAuthenticatedUsers) { push @OutputList,'alllogins'; push @OutputList,'lastlogins'; }
if ($ShowRobotsStats) { push @OutputList,'allrobots'; push @OutputList,'lastrobots'; }
if ($ShowEMailSenders) { push @OutputList,'allemails'; push @OutputList,'lastemails'; }
if ($ShowEMailReceivers) { push @OutputList,'allemailr'; push @OutputList,'lastemailr'; }
if ($ShowSessionsStats) { push @OutputList,'session'; }
if ($ShowPagesStats) { push @OutputList,'urldetail'; push @OutputList,'urlentry'; push @OutputList,'urlexit'; }
if ($ShowFileTypesStats) { push @OutputList,'filetypes'; }
#if ($ShowFileSizesStats) { push @OutputList,'filesize'; }
if ($ShowOSStats) { push @OutputList,'osdetail'; push @OutputList,'unknownos'; }
if ($ShowBrowsersStats) { push @OutputList,'browserdetail'; push @OutputList,'unknownbrowser'; }
if ($ShowScreenSizeStats) { push @OutputList,'screensize'; }
if ($ShowOriginStats) { push @OutputList,'refererse'; push @OutputList,'refererpages'; }
if ($ShowKeyphrasesStats) { push @OutputList,'keyphrases'; }
if ($ShowKeywordsStats) { push @OutputList,'keywords'; }
if ($ShowMiscStats) { push @OutputList,'misc'; }
if ($ShowHTTPErrorsStats) { push @OutputList,'errors'; push @OutputList,'errors404'; }
if ($ShowSMTPErrorsStats) { push @OutputList,'errors'; }

# Launch awstats update
if ($Update) {
	my $command="\"$Awstats\" -config=$SiteConfig -update";
	print "Launch update process : $command\n";
	$retour=`$command  2>&1`;
}

# Built the OutputSuffix value (used later to build page name)
$OutputSuffix=$SiteConfig;
if ($Date) {
	my ($nowsec,$nowmin,$nowhour,$nowday,$nowmonth,$nowyear,$nowwday) = localtime(time);
	if ($nowyear < 100) { $nowyear+=2000; } else { $nowyear+=1900; }
	++$nowmonth;
	$OutputSuffix.=".".sprintf("%04s%02s%02s",$nowyear,$nowmonth,$nowday);
}


my $cpt=0;
my $smallcommand="\"$Awstats\" -config=$SiteConfig".($BuildPDF?" -noloadplugin=tooltips":"")." -staticlinks".($OutputSuffix ne $SiteConfig?"=$OutputSuffix":"");
if ($StaticExt && $StaticExt ne 'html')     { $smallcommand.=" -staticlinksext=$StaticExt"; }
if ($DirIcons)      { $smallcommand.=" -diricons=$DirIcons"; }
if ($Lang)          { $smallcommand.=" -lang=$Lang"; }
if ($MonthRequired) { $smallcommand.=" -month=$MonthRequired"; }
if ($YearRequired)  { $smallcommand.=" -year=$YearRequired"; }

# Launch main awstats output
my $command="$smallcommand -output";
print "Build main page: $command\n";
$retour=`$command  2>&1`;
$OutputFile=($OutputDir?$OutputDir:"")."awstats.$OutputSuffix.$StaticExt";
open("OUTPUT",">$OutputFile") || error("Couldn't open log file \"$OutputFile\" for writing : $!");
print OUTPUT $retour;
close("OUTPUT");
$cpt++;
push @pages, $OutputFile;	# Add page to @page for PDF build

# Launch all other awstats output
for my $output (@OutputList) {
	my $command="$smallcommand -output=$output";
	print "Build $output page: $command\n";
	$retour=`$command  2>&1`;
	$OutputFile=($OutputDir?$OutputDir:"")."awstats.$OutputSuffix.$output.$StaticExt";
	open("OUTPUT",">$OutputFile") || error("Couldn't open log file \"$OutputFile\" for writing : $!");
	print OUTPUT $retour;
	close("OUTPUT");
	$cpt++;
	push @pages, $OutputFile;	# Add page to @page for PDF build
}

# Build pdf file
if ($QueryString =~ /(^|-|&)buildpdf/i) {
#	my $pdffile=$pages[0]; $pdffile=~s/\.\w+$/\.pdf/;
	my $command="\"$HtmlDoc\" -t pdf --webpage --quiet --no-title --textfont helvetica --left 16 --bottom 8 --top 8 --browserwidth 800 --headfootsize 8.0 --fontsize 7.0 --outfile awstats.$OutputSuffix.pdf @pages\n";
	print "Build PDF file : $command\n";
	$retour=`$command  2>&1`;
	my $signal_num=$? & 127;
	my $dumped_core=$? & 128;
	my $exit_value=$? >> 8;
	if ($? || $retour =~ /error/) {
		if ($retour) { error("Failed to build PDF file with following error: $retour"); }
		else { error("Failed to launch htmldoc process with exit: Return code=$exit_value, Killer signal num=$signal_num, Core dump=$dumped_core"); }
	}
	$cpt++;
}


print "$cpt files built.\n";
print "Main HTML page is 'awstats.$OutputSuffix.$StaticExt'.\n";
if ($QueryString =~ /(^|-|&)buildpdf/i) { print "PDF file is 'awstats.$OutputSuffix.pdf'.\n"; }

0;	# Do not remove this line
