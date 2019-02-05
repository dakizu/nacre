use strict;
use warnings;
use JSON::MaybeXS ':all';
use Cwd qw(cwd);
use Term::ANSIColor qw(:constants);

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
        #print "\n", GREEN;
        #print "directory: $directory[$n]\n";
        #print "file: $file[$n]\n";
        #print "command: $command[$n]\n";
        #print "output: $output[$n]\n";
        #print "\n";
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

1;