#!/usr/bin/env perl

############################################################
#################### NACRE BUILD SYSTEM ####################
############################################################

#############################################################
#################### START: Dependencies ####################
#############################################################

use strict;
use warnings;
use Term::ANSIColor qw(:constants); # output colors
use File::Path;
use File::Path qw/make_path/; # path generation (used for gcc pch)
use File::Basename; # path generation (used for gcc pch)
use File::Find;
use File::Spec;
use JSON::MaybeXS ':all'; # json conversion (used for compilation database generation)
use Cwd qw(cwd); # get execution directory (used for compilation database generation)
use Config; # get machine configuration (used for architecture detection)
use FindBin qw($RealScript $RealBin);

###########################################################
#################### END: Dependencies ####################
###########################################################

#######################################################################
#################### START: Architecture detection ####################
#######################################################################

my $arch;
for ($Config{archname}) {
	$arch = (/x86_64|x64/) ? 64 : 32;
}
my $platform = $^O;

#####################################################################
#################### END: Architecture detection ####################
#####################################################################

#################################################################
#################### START: Config variables ####################
#################################################################

my $conf_file = 'conf.pl'; # name of user config file
unless (-f $conf_file) {
	print RED, "Could not find $conf_file!\n", RESET;
	exit;
}

our @src_files; # source files to be compiled and linked
our @src_dirs; # directories to use for src_files searching and automatic indexing
our @src_freeze; # frozen files to only compile once and always link
our @flags; # flags for both compilation and linking
our @flags_compiler; # flags for only the compilation
our @flags_linker; # flags for only the linking
our @include; # directories to be included in compilation (preprocessor)
our @pch; # header files to be precompiled /// NOTE: Precompiled headers currently only work in GCC. TODO: Clang implementation
our @pch_flags; # flags for pch compilation
our @find; # library names for packages with find_*.pl files
our $find_dir = '/usr/share/nacre'; # directory containing find_*.pl files
our $pch_warn = 0; # flag that enables warnings for header compilation
our $bin = 'out'; # the binary (executable) to be produced
our $CC = 'gcc'; # the C compiler
our $CXX = 'g++'; # the C++ compiler (this will also be used for linking)
our $dlink = 0; # flag that enables linking all dynamic library files in bin folder to the exec at runtime (only supports linux environments)
our $compdb = 0; # flag that enables the generation of a compilation database (compile_commands.json)
our $src_index = 2; # automatically index source files
our $link_dl; # flag that links to the dynamic linking library
our $include_src = 1; # flag that sets whether or not to include the source directory during compilation
our %dep; # platform and architecture dependent code
our %std; # a map of standards to use for C and C++ compilation
our %color; # colors to use for build system output
$color{'head'} = BRIGHT_MAGENTA;
$color{'body'} = WHITE;
$color{'success'} = BRIGHT_GREEN;
$color{'failure'} = BRIGHT_RED;
$color{'special'} = BRIGHT_CYAN;

if ($platform eq 'linux') {
	$link_dl = 1;
} else {
	$link_dl = 0;
}

if (-d 'src') {
	push @src_dirs, './src';
}

require "./$conf_file"; # user config file

if (scalar @src_dirs == 0) {
	push @src_dirs, '.';
}

if (scalar @src_files != 0 and $src_index == 2) {
	$src_index = 0;
}

if ($link_dl == 1) {
	push @flags_linker, '-ldl';
}

if ($include_src == 1) {
	push @include, 'src';
}

###############################################################
#################### END: Config variables ####################
###############################################################

#################################################################
#################### START: Global variables ####################
#################################################################

my $std_flag_cc = '';
my $std_flag_cxx = '';
my @obj_files;
my $script_path = "$RealBin/$RealScript";

###############################################################
#################### END: Global variables ####################
###############################################################

#################################################################
#################### START: Helper functions ####################
#################################################################

sub create_path {
	my $dir = dirname("$_[0]");
	make_path ($dir);
}

sub get_mtime {
	return `stat $_[0] -c "%Z"`;
}

sub file_new_mod {
	if (get_mtime($_[0]) > get_mtime('./build/meta/stamp')) {
		return 1;
	} else {
		return 0;
	}
}

sub touch_stamp {
	system "touch ./build/meta/stamp";
}

sub reset_stamp {
	#system "touch -t 0 ./build/meta/stamp";
	# workaround for now
	if (-d './build/obj') {
		system "rm -rf ./build/obj";
		mkdir './build/obj';
	}
	if (-d './build/pchi') {
		system "rm -rf ./build/pchi";
		mkdir './build/pchi';
	}
}

sub touch_file {
	system("touch $_");
}

sub unique_arr {
	my %unique = ();
	foreach my $item (@_) {
		$unique{$item}++;
	}
	my @result = keys %unique;
	return @result;
}

###############################################################
#################### END: Helper functions ####################
###############################################################

####################################################################
#################### START: Build file cleaning ####################
####################################################################

sub clean {
	my $dirty = 0;
	if (-d 'build') {
		rmtree('build');
		print GREEN, "Cleaned build files!\n", RESET;
		$dirty = $dirty + 1;
	}
	if (-f 'compile_commands.json') {
		unlink 'compile_commands.json';
		$dirty = $dirty + 1;
	}
	if ($dirty == 0)
	{
	print $color{'success'}, "Project already clean!\n", RESET;
	}
	#mkdir 'build';
	return;
}

##################################################################
#################### END: Build file cleaning ####################
##################################################################

####################################################################
#################### START: Executable shortcut ####################
####################################################################

sub run {
    my $exstr = '';
    if (-f "build/$bin") {
	$exstr = "./build/$bin";
    }
    elsif (-f "build/$bin.exe") {

	$exstr = "./build/$bin.exe";
    }
    if ($exstr eq '') {
	print $color{'failure'}, "Executable not found!\n", RESET;
	return;
    }
    if ($dlink == 1) {
	if ($platform eq 'linux' || $platform eq 'msys') {
	    my @extok = ('export PATH="$PATH:', cwd(), '/bin";', "$exstr");
	    $exstr = "(@extok)";
	    $exstr =~ s/ \/bin/\/bin/;
	    $exstr =~ s/PATH: /PATH:/;
	}
    }

    print $color{'success'}, "Running program...\n", RESET;
    exec "$exstr";
}

##################################################################
#################### END: Executable shortcut ####################
##################################################################

##############################################################
#################### START: Build process ####################
##############################################################

sub build {

	my @head = ($color{'head'}, "[$platform x$arch]", RESET);

	unless (-d "./build") { mkdir "./build"; }
	unless (-d "./build/obj") { mkdir "./build/obj"; }
	unless (-d "./build/meta") { mkdir "./build/meta"; }
	unless (-d "./build/pchi") { mkdir "./build/pchi"; }
	unless (-f "./build/meta/stamp") { system "touch ./build/meta/stamp"; }

	print @head, $color{'body'}, " Building project...\n", RESET;

	my @head_custom = ($color{'head'}, "($conf_file)", RESET);
	
	keys %dep;
	while(my($k, $v) = each %dep) {
	    if ($platform eq $k) {
		print @head_custom, $color{'special'}, " Executing custom platform code for $platform...\n", RESET;
		$v->();
	    }
	}

	if ($arch == 64) {
	    if (exists $dep{64}) {
		print @head_custom, $color{'special'}, " Executing custom architecture code for x86_64...\n", RESET;
		$dep{64}->();
	    }
	}
	elsif ($arch == 32) {
	    if (exists $dep{32}) {
		print @head_custom, $color{'special'}, " Executing custom architecture code for i386...\n", RESET;
		$dep{32}->();
	    }
	}

	while (my($k, $v) = each %dep) {
	    if ($k eq "${platform}_x$arch") {
		print @head_custom, $color{'special'}, " Executing custom platform/arch code for ${platform}_x$arch...\n", RESET;
		$v->();
	    }
	}

	find_lib();

	index_src_files();

	@src_files = unique_arr(@src_files);

	if (scalar @pch != 0) {
	    unshift @include, "./build/pchi"; # DO NOT INCLUDE THIS IN compile_commands.json
	}

	handle_std();

	my $include_str = '';

	if (scalar @include != 0) { # include directories were given by conf.pl
		foreach (@include) {
			$include_str = "$include_str -I $_";
		}
	}

	########## SECTION: Precompile headers ##########
	if (scalar @pch != 0) {
		print @head, $color{'body'}, " Precompiling headers...\n", RESET;

		my @head_pch = ($color{'head'}, "($CXX pch)", RESET);

		my $gcc = 0;
		my $clang = 0;

		my @clang_out;
		
		foreach (@pch) {
			my $comp = $CXX;
			my $input = "src/$_";
			my $output = "build/pchi/$_";
			my $fake_out = "build/pchi/$_"; # only required by GCC, consider putting inside GCC specific code
			if ($CXX eq 'g++' || $CXX eq 'gcc') {
				$output = "$output.gch";
				$gcc = 1;
			}
			elsif ($CXX eq 'clang' || $CXX eq 'clang++') {
				$output = "$output.pch";
				$clang = 1;
			}
			if ($output !~ /.h/) {
				print @head_pch, $color{'body'}, " Non-standard file extension! ($_)\n", RESET;
			}

			# freeze header precompilation if in frozen list?
			print @head_pch, $color{'body'}, " $input -> $output", RESET;

			#if (-f $output) {
			#	print $color{'special'}, " (good)\n", RESET;
			#	next;
			#}

			if (file_new_mod($input) == 0) {
				if (-f $output ) {
					print $color{'special'}, " (good)\n", RESET;
					next;
				}
			}
			create_path "$output";
			
			if ($gcc == 1) {
				open my $fh, '>', "$fake_out";
				print $fh "// Fake header for $output\n// Required for GCC compatibility\n#error \"fake header executed: <$fake_out>\"\n";
				close $fh;
			}

			if ($clang == 1) {
				push @pch_flags, ('-emit-pch');
				#push @flags_compiler, ('-cc1');
				push @clang_out, $output;
			}
			
			my $in_build_str = "$comp @pch_flags $std_flag_cxx $include_str @flags @flags_compiler -o $output $input";
			my $build_out = `$in_build_str 2>&1`;

			if ($? == 0) {
				print $color{'success'}, " (success)\n", RESET;
				if ($build_out ne "") {
					if ($pch_warn == 1) {
						print "$build_out";
					}
				}
			}
			else {
				print $color{'failure'}, " (fail)\n", RESET;
				print @head_pch, $color{'failure'}, " Header compilation failed!\n", RESET;
				print "$build_out\n";
				return; # move on to the next header/skip to the compilation?
			}
		}

		if ($clang == 1) {
			# doesnt work for some reason
			for my $out_file (@clang_out) {
				push @flags_compiler, ("-include-pch $out_file");
			}
		}
		
	}


	compdb_reset();

	########## SECTION: Compile source ##########
	print @head, $color{'body'}, " Compiling source...\n", RESET;
	foreach (@src_files) {
		my $frozen = 0;

		if (scalar @src_freeze != 0) {
			my $file_name = $_;
			foreach (@src_freeze) {
				if ($_ eq $file_name) {
					$frozen = 1;
					goto BREAK_FROZEN_CHECK;
				}
			}
		}
		BREAK_FROZEN_CHECK:

		my $comp =
		($_ =~ /.cpp/) ? $CXX :
		($_ =~ /.c/) ? $CC :
		$CXX;
		my $file = "src/$_";
		$_ =~ s.\/._.;
		($comp eq $CXX) ? $_ =~ s!.cpp!.obj! :
		($comp eq $CC) ? $_ =~ s!.c!.obj! :
		print $color{'body'}, "Non-standard file extension.", RESET;

		my @head_comp = ($color{'head'}, "($comp)", RESET);

		my $final = "build/obj/$_";

		my $std_flag = ($comp eq $CXX) ? $std_flag_cxx : $std_flag_cc;
		my $in_build_str = "$comp $std_flag $include_str @flags @flags_compiler -c -o $final $file";
		$in_build_str =~ s.\n. .g;
		
		if (file_new_mod($file) == 0) {
			if (-f $final ) {
				print @head_comp, $color{'body'}, " $file -> $final", $color{'special'}, " (good)\n", RESET;
				compdb_add ($in_build_str);
				push @obj_files, $final;
				next;
			}
		}

		if ($frozen == 1) {
			if (-f $final ) {
				print @head_comp, $color{'body'}, " $file -> $final", $color{'special'}, " (frozen)\n", RESET;
				compdb_add ($in_build_str);
				push @obj_files, $final;
				next;
			}
		}

		print @head_comp, $color{'body'}, " $file -> $final", RESET;
		my $build_out = `$in_build_str 2>&1`;

		if ($? == 0) {
			($frozen == 1) ? print $color{'success'}, " (success, freeze bypassed)\n", RESET : print $color{'success'}, " (success)\n", RESET;
			if ($build_out ne "") {
				print "$build_out";
			}
		}
		else {
			print $color{'failure'}, " (fail)\n", RESET;
			print @head, $color{'failure'}, "Compilation failed!\n", RESET;
			print $color{'failure'}, "----------------------- $comp output -----------------------\n", RESET;
			print "$build_out\n";
			return;
		}
		$in_build_str =~ s/ -I \.\/build\/pchi//;
		compdb_add ($in_build_str);

		push @obj_files, $final;
	}

	########## SECTION: Link object files ##########
	my $obj_string = '';
	foreach (@obj_files) {
		$obj_string = "$obj_string $_";
	}
	print @head, $color{'body'}, " Linking...", RESET;
	my $build_str = "$CXX $std_flag_cxx @flags @flags_linker $obj_string -o build/$bin";
	$build_str =~ s.\n. .g;
	my $build_out = `$build_str 2>&1`;
	if ($? == 0) {
		print $color{'success'}, " (success)\n", RESET;
		if ($build_out ne "") {
			print "$build_out";
		}
	}
	else {
		print $color{'failure'}, " (fail)\n", RESET;
		print @head, $color{'failure'}, " Linking failed!\n", RESET;
		print "$build_out\n";
		return;
	}

	if ($compdb == 1) {
		compdb_serialize();
		my $cdb = compdb_export();
		open my $cdbfh, '>', './compile_commands.json';
		print $cdbfh $cdb;
		close $cdbfh;
	}

	print @head, $color{'success'}, " Building completed!\n", RESET;

	touch_stamp();

	return;
}

sub rebuild {
	reset_stamp();
	build();
}

############################################################
#################### END: Build process ####################
############################################################

##############################################################
#################### START: Program entry ####################
##############################################################

my $arg = (@ARGV < 1) ? "" : $ARGV[0];
($arg eq 'build') ? build :
($arg eq 'rebuild') ? rebuild :
($arg eq 'run') ? run :
($arg eq 'clean') ? clean :
build;

############################################################
#################### END: Program entry ####################
############################################################

##################################################################
#################### START: Standard handling ####################
##################################################################

sub handle_std {
	if (exists $std{'CC'}) {
		my $a = $std{'CC'};
		$std_flag_cc =
		($a eq 'ANSI') ? '-std=ansi' :
		($a eq 'c90') ? '-std=c90' :
		($a eq 'c89') ? '-std=c89' :
		($a eq 'iso9899:1990') ? '-std=iso9899:1990' :
		($a eq 'iso9899:199409') ? '-std=iso9899:199409' :
		($a eq 'c99') ? '-std=c99' :
		($a eq 'iso9899:1999') ? '-std=iso9899:1999' :
		($a eq 'c11') ? '-std=c11' :
		($a eq 'c99') ? '-std=c99' :
		($a eq 'iso9899:2011') ? '-std=iso9899:2011' :
		($a eq 'c17') ? '-std=c17' :
		($a eq 'c18') ? '-std=c18' :
		($a eq 'iso9899:2017') ? '-std=iso9899:2017' :
		($a eq 'iso9899:2018') ? '-std=iso9899:2018' :
		($a eq 'gnu90') ? '-std=gnu90' :
		($a eq 'gnu89') ? '-std=gnu89' :
		($a eq 'gnu99') ? '-std=gnu99' :
		($a eq 'gnu11') ? '-std=gnu11' :
		($a eq 'gnu17') ? '-std=gnu17' : # default
		($a eq 'gnu18') ? '-std=gnu18' :
		'';
		if ($a eq 'c9x') { print $color{'failure'}, "(std: cxx) c9x is deprecated! Use c90 instead.\n", RESET; $std_flag_cc = '-std=c90'; }
		elsif ($a eq 'iso9899:199x') { print $color{'failure'}, "(std: cxx) iso9899:199x is deprecated! Use iso9899:1990 instead.\n", RESET; $std_flag_cc = '-std=iso9899:1990'; }
		elsif ($a eq 'c1x') { print $color{'failure'}, "(std: cxx) c1x is deprecated! Use c11 instead.\n", RESET; $std_flag_cc = '-std=c11'; }
		elsif ($a eq 'gnu9x') { print $color{'failure'}, "(std: cxx) gnu9x is deprecated! Use gnu99 instead.\n", RESET; $std_flag_cc = '-std=gnu99'; }
		elsif ($a eq 'gnu1x') { print $color{'failure'}, "(std: cxx) gnu1x is deprecated! Use gnu11 instead.\n", RESET; $std_flag_cc = '-std=gnu11'; }
		elsif ($a eq 'c2x') { print $color{'failure'}, "(std: cxx) c9x is experimental and incomplete!\n", RESET; $std_flag_cc = '-std=c2x'; }
		elsif ($a eq 'gnu2x') { print $color{'failure'}, "(std: cxx) gnu2x is experimental and incomplete!\n", RESET; $std_flag_cc = '-std=gnu2x'; }
		if ($std_flag_cc eq '') {
			print $color{'failure'}, "(std: cc) $a is not a valid C standard.\n", RESET;
		}
	}
	if (exists $std{'CXX'}) {
		my $a = $std{'CXX'};
		$std_flag_cxx =
			($a eq 'ANSI') ? '-std=ansi' :
			($a eq 'c++98') ? '-std=c++98' :
			($a eq 'c++03') ? '-std=c++03' :
			($a eq 'gnu++98') ? '-std=gnu++98' :
			($a eq 'gnu++03') ? '-std=gnu++03' :
			($a eq 'c++11') ? '-std=c++11' :
			($a eq 'gnu++11') ? '-std=gnu++11' :
			($a eq 'c++14') ? '-std=c++14' :
			($a eq 'gnu++14') ? '-std=gnu++14' :
			($a eq 'c++17') ? '-std=c++17' :
			($a eq 'gnu++17') ? '-std=gnu++17' :
			'';
		if ($a eq 'c++0x') { print $color{'failure'}, "(std: cc) c++0x is deprecated! Use c++11 instead.\n", RESET; $std_flag_cxx = '-std=c++11'; }
		elsif ($a eq 'gnu++0x') { print $color{'failure'}, "(std: cc) gnu++0x is deprecated! Use gnu++11 instead.\n", RESET; $std_flag_cxx = '-std=gnu++11'; }
		elsif ($a eq 'c++1y') { print $color{'failure'}, "(std: cc) c++1y is deprecated! Use c++14 instead.\n", RESET; $std_flag_cxx = '-std=c++14'; }
		elsif ($a eq 'gnu++1y') { print $color{'failure'}, "(std: cc) gnu++1y is deprecated! Use gnu++14 instead.\n", RESET; $std_flag_cxx = '-std=gnu++14'; }
		elsif ($a eq 'c++1z') { print $color{'failure'}, "(std: cc) c++1z is deprecated! Use c++17 instead.\n", RESET; $std_flag_cxx = '-std=c++17'; }
		elsif ($a eq 'gnu++1z') { print $color{'failure'}, "(std: cc) gnu++1z is deprecated! Use gnu++17 instead.\n", RESET; $std_flag_cxx = '-std=gnu++17'; }
		elsif ($a eq 'c++2a') { print $color{'failure'}, "(std: cc) c++2a is experimental and incomplete!\n", RESET; $std_flag_cxx = '-std=c++2a'; }
		elsif ($a eq 'gnu++2a') { print $color{'failure'}, "(std: cc) gnu++2a is experimental and incomplete!\n", RESET; $std_flag_cxx = '-std=gnu++2a'; }
		if ($std_flag_cxx eq '') {
			print $color{'failure'}, "(std: cxx) $a is not a valid C++ standard.\n", RESET;
		}
	}
}

################################################################
#################### END: Standard handling ####################
################################################################

################################################################################
#################### START: Compilation database generation ####################
################################################################################

my @db; # json object (data)
my $json; # json object (text)

# all compile_commands.json entries
# the below should all be of identical size
my @directory;
my @file;
my @command;
#my @arguments; # command used instead
my @output;

# doesn't take input
sub compdb_export {
	$json = encode_json \@db;
	#$json =~ s.\\\/.\/.g;
	return $json;
}

# takes the compile command string
sub compdb_add {
	my $string = $_[0];
	my @tokens = split ' ', $string;

	# build directory string
	push @directory, cwd;

	# build file string
	push @file, $tokens[-1];

	# build command string
	push @command, $string;

	# build output string
	foreach my $n (0 .. scalar @tokens) {
		if ($tokens[$n] eq '-o') {
			push @output, $tokens[$n+1];
			last;
		}
	}
	return;
}

# doesn't take input
sub compdb_serialize {
	foreach my $n (0 .. scalar @directory - 1) {
		my %entry = (
			directory => $directory[$n],
			file => $file[$n],
			command => $command[$n],
			output => $output[$n]
		);
		push @db, \%entry;
	}
	compdb_reset();
	return;
}

# doesn't take input
sub compdb_reset {
	@directory = ();
	@file = ();
	@command = ();
	@output = ();
	return;
}

##############################################################################
#################### END: Compilation database generation ####################
##############################################################################

####################################################################
#################### START: Find library system ####################
####################################################################

sub find_lib {
	if (scalar @find == 0) { return; }
	foreach (@find) {
		#print "\n\n$_\n\n";
		find_lib_search ($_);
	}
}

sub find_lib_search {

	my @f_file_tokens = split ' ', $_;
	(my $f_file_name, my @f_file_args) = @f_file_tokens;

	#print "\n\nname: $f_file_name\nargs: @f_file_args\n";
	
	my $f_file = "$find_dir/find_$f_file_name.pl";
	unless (-f $f_file) {
		print $color{head}, "(find) ", $color{failure}, "Find-file for library $f_file_name not found!\n",RESET;
		exit;
	}
	
	local our @f_flags;
	local our @f_flags_compiler;
	local our @f_flags_linker;
	local our @f_include;
	local our %f_dep;
	local our @f_req;

	{
		local @_ = @f_file_args;
		require $f_file;
	}
	#print "\n\n" + scalar @f_req + "\n\n";

	# TODO: execute f_dep dependency code here

	if (scalar @f_req != 0) {
		foreach (@f_req) {
			find_lib_search($_);
		}	
	}

	print $color{head}, "(find) ", $color{special}, "Finding $f_file_name...";
	
	push @flags, @f_flags;
	push @flags_compiler, @f_flags_compiler;
	push @flags_linker, @f_flags_linker;
	push @include, @f_include;
	print $color{success}, " (success)\n", RESET;
}

##################################################################
#################### END: Find library system ####################
##################################################################

#####################################################################
#################### START: Source file indexing ####################
#####################################################################

sub index_src_files {
	if ($src_index != 0) {
		foreach my $dir (@src_dirs) {
			find(\&index_src_files_handle, "$dir");
		}
	}
}

sub index_src_files_handle {
	if ($_ =~ /\.cpp/ or $_ =~ /\.c/) {
		my $r_path = File::Spec->abs2rel($File::Find::name, 'src');
		push @src_files, $r_path;
	}
}

###################################################################
#################### END: Source file indexing ####################
###################################################################
