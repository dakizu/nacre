our @f_flags;
our @f_flags_compiler;
our @f_flags_linker;
our @f_include;
our @f_req = ('gl x11');

push @f_flags_linker, `sdl2-config --libs`;
push @f_flags_compiler, `sdl2-config --cflags`;

return 1;
