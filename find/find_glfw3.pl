our @f_flags;
our @f_flags_compiler;
our @f_flags_linker;
our @f_include;
our @f_req = ('gl x11');

# the following links statically
push @f_flags_linker, ('-lglfw', '-lrt', '-lm', '-lpthread', '-lxcb', '-lXau', '-lXrandr', '-lXfixes', '-lXdmcp');
push @f_flags_compiler, ('-I/usr/include/GLFW', '-D_REENTRANT');

return 1;
