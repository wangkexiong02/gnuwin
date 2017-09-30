@ECHO off

FOR %%i in (*.bat) DO CALL :PROC %%i
GOTO :EOF

:PROC
  IF /I %~1==common.bat        GOTO :EOF
  IF /I %~1==vcvars32all.bat   GOTO :EOF
  IF /I %~1==vcvars64all.bat   GOTO :EOF
  IF /I %~1==start_build.bat   GOTO :EOF
  IF /I %~1==clean_github.bat  GOTO :EOF
  IF /I %~1==full_artifact.bat GOTO :EOF

  CALL %~1
)

GOTO :EOF
