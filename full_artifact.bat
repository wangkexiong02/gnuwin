@ECHO off

FOR %%i IN (*.7z) DO (
  CALL common :UNPACK %%i %INSTALL_DIR%
)

CALL common :PACK gnuwin%VCVARS_PLATFORM%.7z %INSTALL_DIR%

