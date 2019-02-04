#!/usr/bin/env perl
use strict;
use warnings;
use Term::ANSIColor qw(:constants);
use File::Path;
use File::Stat;

my $arch;
for (`perl -V:archname`) {
    $arch = (/x86_64/) ? 64 : 32;
}

my $conf_file = './conf.pl';

unless (-f $conf_file) {
    print RED, "Could not find conf.pl!\n", RESET;
    exit;
}

our @src_files; # source files to be compiled and linked
our @src_freeze; # frozen files to only compile once and always link
our @flags; # flags for both compilation and linkin
our @flags_compiler; # flags for only the compilation
our @flags_linker; # flags for only the linking
our @include; # directories to be included in compilation (preprocessor)
our $bin = 'out'; # the binary (executable) to be produced
our $CC = 'clang'; # the C compiler
our $CXX = 'clang++'; # the C++ compiler (this will also be used for linking)
our %platform_dep; # a map of function pointers for platform dependent operations
our %arch_dep; # a map of function pointers for architecture dependent operations
our %std; # a map of standards to use for C and C++ compilation

require "./$conf_file";

my $std_flag_cc = '';
my $std_flag_cxx = '';

my @obj_files;
sub clean {
    my $dirty = 0;
    if (-d 'build') {
        rmtree('build');
        print GREEN, "Cleaned build files!\n", RESET;
        $dirty = $dirty + 1;
    }
    if (-f 'compile_commands.json') {
        unlink 'compile_commands.json';
        print GREEN, "Removed compile commands file!\n", RESET;
        $dirty = $dirty + 1;
    }
    if ($dirty == 0)
    {
        print GREEN, "Project already clean!\n", RESET;
    }
    mkdir 'build';
    return;
}

sub run {
    unless (-f "build/$bin") {
        print RED, "Executable not found!\n", RESET;
        return;
    }
    print GREEN, "Running program...\n", RESET;
    exec "./build/$bin";
}

sub build {
    unless (-d "./build") { mkdir "./build"; }
    unless (-d "./build/obj") { mkdir "./build/obj"; }
    unless (-d "./build/meta") { mkdir "./build/meta"; }

    handle_std();

    my $include_str = '';

    if (scalar @include != 0) { # include directories were given by conf.pl
        foreach (@include) {
            $include_str = "$include_str -I $_";
        }
    }

    print YELLOW, "[$^O] Compiling...\n", RESET;


    keys %platform_dep;
    while(my($k, $v) = each %platform_dep) {
        if ($^O eq $k) {
            print CYAN, "(conf.pl) Executing custom platform code for $^O...\n", RESET;
            $v->();
        }
    }

    if ($arch == 64) {
        if (exists $arch_dep{64}) {
            print CYAN, "(conf.pl) Executing custom architecture code for x86_64...\n", RESET;
            $arch_dep{64}->();
        }
    }
    elsif ($arch == 32) {
        if (exists $arch_dep{32}) {
            print CYAN, "(conf.pl) Executing custom architecture code for i386...\n", RESET;
            $arch_dep{32}->();
        }
    }


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
        print YELLOW, "Non-standard file extension.", RESET;
        
        my $final = "build/obj/$_";

        if ($frozen == 1) {
            if (-f $final ) {
                print YELLOW, "($comp) $file -> $final", CYAN, " (frozen)\n", RESET;
                next;
            }
        }

        print YELLOW, "($comp) $file -> $final", RESET;

        my $std_flag = ($comp eq $CXX) ? $std_flag_cxx : $std_flag_cc;

        my $in_build_str = "$comp $std_flag $include_str @flags @flags_compiler -c $file -o $final";
        if (system($in_build_str)) {
            print RED, " (fail)\n", RESET;
            print RED, "Compilation failed!\n", RESET;
            return;
        }
        push @obj_files, $final;
        ($frozen == 1) ? print GREEN, " (success, freeze bypassed)\n", RESET : print GREEN, " (success)\n", RESET;
        
    }
    my $obj_string = '';
    foreach (@obj_files) {
        $obj_string = "$obj_string $_";
    }
    print YELLOW, "Linking...\n", RESET;
    my $build_str = "$CXX $std_flag_cxx @flags @flags_linker $obj_string -o build/$bin";
    system($build_str);
    print GREEN, "Building finished!\n", RESET;
    return;
}


my $arg = (@ARGV < 1) ? "" : $ARGV[0];
($arg eq 'build') ? build :
($arg eq 'run') ? run :
($arg eq 'clean') ? clean :
build;





# hell below

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
        if ($a eq 'c9x') { print RED, "(std: cxx) c9x is deprecated! Use c90 instead.\n", RESET; $std_flag_cc = '-std=c90'; }
        elsif ($a eq 'iso9899:199x') { print RED, "(std: cxx) iso9899:199x is deprecated! Use iso9899:1990 instead.\n", RESET; $std_flag_cc = '-std=iso9899:1990'; }
        elsif ($a eq 'c1x') { print RED, "(std: cxx) c1x is deprecated! Use c11 instead.\n", RESET; $std_flag_cc = '-std=c11'; }
        elsif ($a eq 'gnu9x') { print RED, "(std: cxx) gnu9x is deprecated! Use gnu99 instead.\n", RESET; $std_flag_cc = '-std=gnu99'; }
        elsif ($a eq 'gnu1x') { print RED, "(std: cxx) gnu1x is deprecated! Use gnu11 instead.\n", RESET; $std_flag_cc = '-std=gnu11'; }
        elsif ($a eq 'c2x') { print RED, "(std: cxx) c9x is experimental and incomplete!\n", RESET; $std_flag_cc = '-std=c2x'; }
        elsif ($a eq 'gnu2x') { print RED, "(std: cxx) gnu2x is experimental and incomplete!\n", RESET; $std_flag_cc = '-std=gnu2x'; }
        if ($std_flag_cc eq '') {
            print RED, "(std: cc) $a is not a valid C standard.\n", RESET;
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
        if ($a eq 'c++0x') { print RED, "(std: cc) c++0x is deprecated! Use c++11 instead.\n", RESET; $std_flag_cxx = '-std=c++11'; }
        elsif ($a eq 'gnu++0x') { print RED, "(std: cc) gnu++0x is deprecated! Use gnu++11 instead.\n", RESET; $std_flag_cxx = '-std=gnu++11'; }
        elsif ($a eq 'c++1y') { print RED, "(std: cc) c++1y is deprecated! Use c++14 instead.\n", RESET; $std_flag_cxx = '-std=c++14'; }
        elsif ($a eq 'gnu++1y') { print RED, "(std: cc) gnu++1y is deprecated! Use gnu++14 instead.\n", RESET; $std_flag_cxx = '-std=gnu++14'; }
        elsif ($a eq 'c++1z') { print RED, "(std: cc) c++1z is deprecated! Use c++17 instead.\n", RESET; $std_flag_cxx = '-std=c++17'; }
        elsif ($a eq 'gnu++1z') { print RED, "(std: cc) gnu++1z is deprecated! Use gnu++17 instead.\n", RESET; $std_flag_cxx = '-std=gnu++17'; }
        elsif ($a eq 'c++2a') { print RED, "(std: cc) c++2a is experimental and incomplete!\n", RESET; $std_flag_cxx = '-std=c++2a'; }
        elsif ($a eq 'gnu++2a') { print RED, "(std: cc) gnu++2a is experimental and incomplete!\n", RESET; $std_flag_cxx = '-std=gnu++2a'; }
        if ($std_flag_cxx eq '') {
            print RED, "(std: cxx) $a is not a valid C++ standard.\n", RESET;
        }
    }
}