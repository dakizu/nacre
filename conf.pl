our $bin = 'test';

our $CXX = 'g++';
our $CC = 'gcc';

our @src_files = (
    'main.cpp',
    'util/print.cpp',
    'thirdparty/glad.c'
);

our $compdb = 1;

our @pch = (
    'buildpch.h'
);

our @src_freeze = (
    'thirdparty/glad.c'
);

our @flags = (
    '-DGLFW_DLL',
    '-Wall',
    '-g'
);

our @flags_compiler = (
#    '-H'
);

our @flags_linker;

our @include = (
    './include',
    './src'
);

our %platform_dep;
$platform_dep{'msys'} = sub {
    push @flags, '-isystem C:/msys64/mingw64/include';
};
$platform_dep{'MSWin32'} = sub {
    push @flags, '-isystem C:/msys64/mingw64/include';
};
$platform_dep{'linux'} = sub {
    push @flags_linker, '-ldl';
};

our %std;
$std{'CC'} = 'gnu11';
$std{'CXX'} = 'gnu++17';

# idea (not yet implemented)
# dll_copy should look for the named dlls in a folder called bin (may need to change executable name variable)
# and copy them to the build folder when building if they arent already there.
our @dll_copy = (
    'test.dll'
);