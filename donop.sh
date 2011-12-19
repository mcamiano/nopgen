cd e:/nopgen
PATH="C:/OS2;C:/OS2/SYSTEM;C:/OS2/MDOS/WINOS2;C:/OS2/INSTALL;C:/;C:/OS2/MDOS;C:/OS2/APPS;c:/bin;d:/pmbin;d:/bin;d:/public/os2/dev/gcc/bin;d:/public/os2/dev/gawk;d:/public/os2/dev/rcs56/exe;d:/public/os2/dev/yacc;d:/public/os2/dev/dmake"
export PATH
./nop patternfile 2>debug.out >nopgen.out
vi nopgen.out debug.out
