# nacre
## An adaptable C++ build script written in Perl

### Usage Guide
To use nacre, create a conf.pl file in the root of your project. This is the main configuration file. Nacre builds are configured by setting various variables in the configuration file that are then used by the main script to build your project. Since the variables are acquired by including the configuration file in the main script at runtime via the use of the **require** command, the configuration file is evaluated in it's entirety. As such, it can be used to run any Perl code and well as run any other scripts. Although declaring the configuration variables as **our** is considered the correct thing to do it is optional and not using it results in shorter (if less readable) configuration files.
### Variables
**Note:** All mandatory variables have default values and as such building can work without setting any variables at all. If you wish to use the default configuration, provide a conf.pl file with a single line reading "1;".

- **src_files**
	- Source files to be compiled and linked.
- **src_freeze**
	- Frozen files to only compile once and always link. For use if system timestamps are not functioning correctly, causing files to always recompile.
- **flags**
	- Flags for both compilation and linking.
- **flags_compiler**
	- Flags for only the compilation.
- **flags_linker**
	- Flags for only the linking.
- **include**
	- Directories to be included during compilation.
- **pch**
	- Header files to be precompiled.
	- Precompiled headers are currently only supported when compiling with GCC.
- **pch_flags**
	- Flags for header compilation.
- **find**
	- Libraries to include and link using the find system.
- **find_dir**
	- Default: **/usr/share/nacre**
	- Directory containing find_*.pl files for the find system.
	- Convenience feature for local find files.
- **pch_warn**
	- Default: **0**
	- Flag that enables warnings for header compilation.
- **bin**
	- Default: **out**
	- The name of the binary (executable) to be produced.
- **CC**
	- Default: **gcc**
	- The compiler used for C source code.
- **CXX**
	- Default: **g++**
	- The compiler used for C++ source code and linker invocation.
- **dlink**
	- Default: **0**
	- Flag that enables linking all dynamic library files in **bin** folder to the executable at runtime.
- **compdb**
	- Default: **0**
	- Flag that enables the generation of the compilation database (compile_commands.json).
- **src_index**
	- Default: **2**
	- Automatically index source files.
	- 0 does not index source files, 1 indexes source files, and 2 indexes source files only if no source files were explicitly provided via src_files.
- **dep**
	- Platform and architecture dependent code.
	- Usage information below.
- **std**
	- Standards to use for C and C++ compilation.
- **color**
	- Defaults:
		- **head**: BRIGHT_MAGENTA
		- **body**: WHITE
		- **success**: BRIGHT_GREEN
		- **failure**: BRIGHT_RED
		- **special**: BRIGHT_CYAN.
	- Colors to use for build output.
	- Values to set are head, body, success, failure, and special.

### Find system

### Platform and architecture dependent code
