@echo off
setlocal
call "E:\Apps\Visual Studio IDE\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul || exit /b 1

set TESTS_DIR=%~dp0
set SRC_DIR=%~dp0..\src

echo [1/6] Generating import libs (kernel32, ws2_32)...
lib /nologo /def:"%SRC_DIR%\kernel32.def" /machine:x64 /out:"%SRC_DIR%\kernel32.lib" || exit /b 1
lib /nologo /def:"%SRC_DIR%\ws2_32.def" /machine:x64 /out:"%SRC_DIR%\ws2_32.lib" || exit /b 1

echo [2/6] Compiling protocol_test.exe (freestanding, no CRT)...
cl /nologo /W3 /GS- /I"%SRC_DIR%" /Fd"%TESTS_DIR%protocol_test.pdb" "%TESTS_DIR%protocol_test.c" /link /NODEFAULTLIB /ENTRY:test_entry /SUBSYSTEM:CONSOLE "%SRC_DIR%\kernel32.lib" /OUT:"%TESTS_DIR%protocol_test.exe" || exit /b 1

echo [3/6] Compiling net_loopback_test.exe (freestanding, no CRT)...
cl /nologo /W3 /GS- /I"%SRC_DIR%" /Fd"%TESTS_DIR%net_loopback_test.pdb" "%TESTS_DIR%net_loopback_test.c" "%SRC_DIR%\coop_net.c" /link /NODEFAULTLIB /ENTRY:test_entry /SUBSYSTEM:CONSOLE "%SRC_DIR%\kernel32.lib" "%SRC_DIR%\ws2_32.lib" /OUT:"%TESTS_DIR%net_loopback_test.exe" || exit /b 1

echo [4/6] Compiling session_test.exe (freestanding, no CRT)...
cl /nologo /W3 /GS- /I"%SRC_DIR%" /Fd"%TESTS_DIR%session_test.pdb" "%TESTS_DIR%session_test.c" "%SRC_DIR%\coop_session.c" "%SRC_DIR%\coop_net.c" /link /NODEFAULTLIB /ENTRY:test_entry /SUBSYSTEM:CONSOLE "%SRC_DIR%\kernel32.lib" "%SRC_DIR%\ws2_32.lib" /OUT:"%TESTS_DIR%session_test.exe" || exit /b 1

echo [5/6] Compiling relay_test.exe (freestanding, no CRT)...
cl /nologo /W3 /GS- /I"%SRC_DIR%" /Fd"%TESTS_DIR%relay_test.pdb" "%TESTS_DIR%relay_test.c" "%SRC_DIR%\coop_relay.c" "%SRC_DIR%\coop_session.c" "%SRC_DIR%\coop_net.c" /link /NODEFAULTLIB /ENTRY:test_entry /SUBSYSTEM:CONSOLE "%SRC_DIR%\kernel32.lib" "%SRC_DIR%\ws2_32.lib" /OUT:"%TESTS_DIR%relay_test.exe" || exit /b 1

echo [6/6] Running tests...
"%TESTS_DIR%protocol_test.exe" || exit /b 1
"%TESTS_DIR%net_loopback_test.exe" || exit /b 1
"%TESTS_DIR%session_test.exe" || exit /b 1
"%TESTS_DIR%relay_test.exe" || exit /b 1
