$bin = 'test.exe';

@src_files = (
    'main.cpp',
    'util/print.cpp',
    'thirdparty/glad.c'
);

@src_freeze = (
    'thirdparty/glad.c'
);

@flags = (
    '-DGLFW_DLL',
    '-Wall',
    '-g'
);

@include = (
    './include',
    './src'
);

$platform_dep{'msys'} = sub {
    push @flags, '-isystem C:/msys64/mingw64/include';
};

$std{'CC'} = 'gnu17';
$std{'CXX'} = 'gnu++17';

#idea (not yet implemented)
# dll_copy should look for the named dlls in a folder called bin (may need to change executable name variable)
# and copy them to the build folder when building if they arent already there.
@dll_copy = (
    'test.dll'
);

#important! - add support for precompiled headers (ideally with both gcc and clang)


#another thing: add compiler_commands.json generation