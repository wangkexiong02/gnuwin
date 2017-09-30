@ECHO off

IF "%DEFAULT_PREFIX%"=="" SET "DEFAULT_PREFIX=C:\build"

SET ERR_DOWNLOAD=1001
SET ERR_UNTAR=1002
SET ERR_PACKED=2001

CALL %*
GOTO :EOF

:BUILD_ENV
  @REM Add already build artifacts to be working with VC compilers ------{{{{
  @REM

  IF NOT "%VCVARS_PLATFORM%"=="64" (
    SET VCVARS_PLATFORM=32
    SET VCVARS_ARCH=x86
  ) ELSE (
    SET VCVARS_ARCH=amd64
  )

  IF NOT "%LINK_TYPE%"=="static" (
    SET LINK_TYPE=shared
  )

  IF "%PREFIX%"=="" (
    SET PREFIX=%DEFAULT_PREFIX%
  )

  SET "INSTALL_DIR=%PREFIX%%VCVARS_PLATFORM%"
  SET "INCLUDE=%INSTALL_DIR%\include;%INCLUDE%"
  SET "LIB=%INSTALL_DIR%\lib;%LIB%"
  SET "LIBPATH=%INSTALL_DIR%\lib;%LIBPATH%"

  @ECHO *****************************************
  @ECHO VC Building ENV settings:
  @ECHO PATH:    "%PATH%"
  @ECHO INCLUDE: "%INCLUDE%"
  @ECHO LIB:     "%LIB%"
  @ECHO *****************************************

  GOTO :EOF
  @REM }}}

:BUILD_GETSOURCE
  @REM Get Source TAR BALL from NET to be prepared for compiling --------{{{{
  @REM

  SET TAR_TYPE=tar
  IF "%~2" NEQ "" SET "TAR_TYPE=%~2"

  curl -fsSL -o download~temp "%~1" --connect-timeout 5

  IF EXIST download~temp (
    7z x download~temp -so | 7z x -si -t%TAR_TYPE% 1>nul
  ) ELSE (
    CALL :ERROR_MARKER
    @ECHO %~1 downloaded failed ...
    CALL :ERROR_MARKER

    EXIT /B %ERR_DOWNLOAD%
  )

  IF %ERRORLEVEL% NEQ 0 (
    CALL :ERROR_MARKER
    @ECHO Extract downloaded from %~1 failed...
    CALL :ERROR_MARKER

    DEL /F/Q download~temp
    EXIT /B %ERR_UNTAR%
  )

  DEL /F/Q download~temp
  GOTO :EOF
  @REM }}}}

:BUILD_CHAIN
  @REM Build Artifacts according to its defined building chain ----------{{{{
  @REM

  IF "%VCVARS_PLATFORM%"=="" (
    SET VCVARS_PLATFORM=32
    SET VCVARS_ARCH=x86
  )

  IF "%LINK_TYPE%"=="" (
    SET LINK_TYPE=shared
  )

  IF "%PREFIX%"=="" (
    SET "PREFIX=%DEFAULT_PREFIX%"
  )

  IF "%INSTALL_DIR%"=="" (
    SET "INSTALL_DIR=%PREFIX%%VCVARS_PLATFORM%"
  )

  IF "%1"=="" GOTO :EOF
  SETLOCAL enabledelayedexpansion
    IF "!%1_VER!"=="" (
      @ECHO "**** SKIP BUILDING %1 w/o VERSION DEFINED, MAY LEAD BUILD ERROR ****"
      GOTO :EOF
    )
  ENDLOCAL

  :PARSE_CHAIN
    SHIFT
    IF "%1"=="" GOTO :PARSE_OK

    @REM
    @REM If there is already artifact (Github/Build),
    @REM NEVER call its build script any more ......
    @REM

    SETLOCAL enabledelayedexpansion
      IF NOT "!%1_VER!"=="" (
        SET "BUILD_ARTIFACT=%1-!%1_VER!.%VCVARS_ARCH%-%LINK_TYPE%.7z"
        IF EXIST !BUILD_ARTIFACT! GOTO :PARSE_CHAIN
      )
    ENDLOCAL

    IF EXIST %1.bat CALL %1
    GOTO :PARSE_CHAIN

  :PARSE_OK
    SET BUILD_TARGET=
    CALL :BUILD_CLEANARTIFACTS %INSTALL_DIR%

    SETLOCAL enabledelayedexpansion
      FOR %%i in (%*) DO (
        SET BUILD_ARTIFACT=%%i-!%%i_VER!.%VCVARS_ARCH%-%LINK_TYPE%.7z

        IF NOT DEFINED BUILD_TARGET (
          IF EXIST !BUILD_ARTIFACT! GOTO :EOF
          SET BUILD_TARGET=%%i
        ) ELSE (
          IF NOT "!%%i_VER!"=="" CALL :UNPACK !BUILD_ARTIFACT! %INSTALL_DIR%
          IF EXIST REBUILD-%%i (
            CALL :TOUCH REBUILD-!BUILD_TARGET!
          )
        )
      )

      IF EXIST REBUILD-!BUILD_TARGET! GOTO :EOF

      IF NOT "!%BUILD_TARGET%_FORCEBUILD!"=="yes" (
        SET BUILD_ARTIFACT=%BUILD_TARGET%-!%BUILD_TARGET%_VER!.%VCVARS_ARCH%-%LINK_TYPE%.7z
        IF NOT EXIST !BUILD_ARTIFACT! CALL :BUILD_GETFROMGITHUB !BUILD_ARTIFACT!
        IF EXIST !BUILD_ARTIFACT! (
          CALL :BUILD_CLEANARTIFACTS %INSTALL_DIR%
          GOTO :EOF
        )
      )

      @ECHO "Create REBUILD FLAG FOR !BUILD_TARGET! ..."
      CALL :TOUCH REBUILD-!BUILD_TARGET!
    ENDLOCAL

  GOTO :EOF
  @REM }}}}

:BUILD_GETFROMGITHUB
  @REM Try to get already build package from Github ---------------------{{{{
  @REM

  IF NOT "%APPVEYOR_REPO_NAME%"=="" (
    IF "%~1"=="" (
      @ECHO "Nothing to download from github..."
      GOTO :EOF
    ) ELSE (
      @ECHO "Download https://github.com/%APPVEYOR_REPO_NAME%/releases/download/vc%VSVER%.%PLATTYPE%-%LINK_TYPE%/%~1"
      curl -fsSL -o "%~1" "https://github.com/%APPVEYOR_REPO_NAME%/releases/download/vc%VSVER%.%PLATTYPE%-%LINK_TYPE%/%~1"
    )
  ) ELSE (
    @ECHO "NO REPO information from github ..."
  )

  GOTO :EOF
  @REM }}}}

:BUILD_CLEANARTIFACTS
  @REM Clean build destination DIR for clean package --------------------{{{{
  @REM

  IF EXIST "%~1" RD /S/Q "%~1"

  GOTO :EOF
  @REM }}}}

:BUILD_PACK
  @REM Pack artifacts according to naming rule --------------------------{{{{
  @REM

  IF "%~1" NEQ "" (
    SETLOCAL enabledelayedexpansion
      IF "!%1_VER!" NEQ "" (
        CALL :PACK %~1-!%~1_VER!.%VCVARS_ARCH%-%LINK_TYPE%.7z %INSTALL_DIR%
      ) ELSE (
        CALL :ERROR_MARKER
        @ECHO "%1_VER is NOT DEFINED, BUILD_PACK FAILED..."
        CALL :ERROR_MARKER
      )
    ENDLOCAL
  )

  GOTO :EOF
  @REM  }}}}

:ERROR_MARKER
  @REM Highlight the ERROR message --------------------------------------{{{{
  @REM

  @ECHO *+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+*+
  GOTO :EOF
  @REM }}}}

:PACK
  @REM Pack already build GNU artifacts into 7z package -----------------{{{{
  @REM

  SETLOCAL
    SET /A ARGS_COUNT=0
    FOR %%A in (%*) DO SET /A ARGS_COUNT+=1

    IF %ARGS_COUNT% LSS 2 GOTO :EOF
  ENDLOCAL

  IF NOT "%APPVEYOR_BUILD_FOLDER%"=="" (
    CD "%APPVEYOR_BUILD_FOLDER%"
  )

  IF EXIST "%~2" (
    7z a "%~1" "%~2\*" > nul
    RD /S/Q "%~2"
  ) ELSE (
    CALL :ERROR_MARKER
    @ECHO "%~2 not existed, %~1 NOT PACKED..."
    CALL :ERROR_MARKER

    EXIT /B %ERR_PACKED%
  )
  GOTO :EOF
  @REM }}}}

:UNPACK
  @REM UnPack artifacts -------------------------------------------------{{{{
  @REM

  SETLOCAL
    SET /A ARGS_COUNT=0
    FOR %%A in (%*) DO SET /A ARGS_COUNT+=1

    IF %ARGS_COUNT% LSS 2 GOTO :EOF
  ENDLOCAL

  IF EXIST "%~1" (
    7z x -y "%~1" -o"%~2" > nul
  )
  GOTO :EOF
  @REM }}}}

:TOUCH
  @REM DOS version of Unix Command touch --------------------------------{{{{
  @REM 1. Support multiple files.
  @REM 2. Update file Modified Timestamp if file already exists.
  @REM    Otherwise, create a NEW empty file
  @REM

  FOR %%a IN (%*) DO (
    IF EXIST "%%~a" (
      PUSHD "%%~dpa" && ( COPY /b "%%~nxa"+,, & POPD )
    ) ELSE (
      IF NOT EXIST "%%~dpa" MD "%%~dpa"
      TYPE nul > "%%~fa"
    )
  ) >nul 2>&1

  GOTO :EOF
  @REM }}}}

:SPLIT
  @REM Splits <string> at the first <delim> into <prefix> and <postfix> -{{{{
  @REM
  @REM Parameters: "<string>" "<delim>" <prefixResultVar> <postfixResultVar>
  @REM The first 2 parameters should be quoted always...
  @REM

  SETLOCAL
    SET /A ARGS_COUNT=0
    FOR %%A in (%*) DO SET /A ARGS_COUNT+=1

    IF %ARGS_COUNT% LSS 3 GOTO :EOF

    SET "VAR1=%~1"
    CALL SET "DELETE=%%VAR1:*%~2=%%"
    CALL SET "PREFIX=%%VAR1:%~2%DELETE%=%%"
    CALL SET "POSTFIX=%DELETE%"
(
  ENDLOCAL
  IF %ARGS_COUNT% gtr 2 CALL SET "%~3=%PREFIX%"
  IF %ARGS_COUNT% gtr 3 CALL SET "%~4=%POSTFIX%"
)

  GOTO :EOF
  @REM }}}}

:STRLEN
  @REM Returns the length of a string -----------------------------------{{{{
  @REM     -- string [in]  - variable name containing the string being measured
  @REM     -- len    [out] - variable to be used to return the string length
  @REM

  SETLOCAL ENABLEDELAYEDEXPANSION
    SET "str=A!%~1!"
    SET len=0
    FOR /L %%A in (12,-1,0) DO (
        SET /A "len|=1<<%%A"
        FOR %%B in (!len!) DO IF "!str:~%%B,1!"=="" SET /A "len&=~1<<%%A"
    )
(
  ENDLOCAL
  IF "%~2" NEQ "" SET /A %~2=%len%
)
  GOTO :EOF
  @REM }}}}

