my $p_headers = 0;
my $p_x11 = 0;
my $p_wayland = 0;

foreach (@_) {
	if ($_ eq 'h' || $_ eq 'header' || $_ eq 'headers') { $p_headers = 1; }
	elsif ($_ eq 'x11' || $_ eq 'xorg') { $p_x11 = 1; }
	elsif ($_ eq 'wayland') { $p_wayland = 1; }
}

if ($p_x11 == 0 and $p_wayland == 0) { $p_x11 = 1; }
if ($p_x11 == 1 and $p_wayland == 1) { $p_wayland = 0; }

our @f_flags_linker;
our @f_flags_compiler;

if ($p_headers == 1) { push @f_flags_compiler, '-I/usr/include/GL'; }

push @f_flags_linker, ('-lGL');
if ($p_x11 == 1) { push @f_flags_linker, '-lX11'; }
if ($_wayland == 1) { exit 2; } # not supported!

return 1;
