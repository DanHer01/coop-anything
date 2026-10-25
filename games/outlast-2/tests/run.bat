@echo off
setlocal
call "E:\Apps\Visual Studio IDE\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul || exit /b 1

set TESTS_DIR=%~dp0
set SRC_DIR=%~dp0..\src

echo [1/3] Generating kernel32.lib (freestanding import lib)...
lib /nologo /def:"%SRC_DIR%\kernel32.def" /machine:x64 /out:"%SRC_DIR%\kernel32.lib" || exit /b 1

echo [2/3] Compiling protocol_test.exe (freestanding, no CRT)...
cl /nologo /W3 /GS- /I"%SRC_DIR%" /Fd"%TESTS_DIR%protocol_test.pdb" "%TESTS_DIR%protocol_test.c" /link /NODEFAULTLIB /ENTRY:test_entry /SUBSYSTEM:CONSOLE "%SRC_DIR%\kernel32.lib" /OUT:"%TESTS_DIR%protocol_test.exe" || exit /b 1

echo [3/3] Running protocol tests...
"%TESTS_DIR%protocol_test.exe" || exit /b 1
