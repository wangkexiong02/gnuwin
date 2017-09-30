@ECHO off

SET ZLIB_VER=1.2.11
CALL common :BUILD_CHAIN zlib

IF NOT EXIST REBUILD-zlib GOTO :EOF

:ZLIB_BUILD
  CALL common :BUILD_GETSOURCE https://zlib.net/zlib-%ZLIB_VER%.tar.gz
  PUSHD zlib-%ZLIB_VER%

  IF "%VCVARS_PLATFORM%"=="64" (
    nmake -f win32/Makefile.msc AS=ml64 LOC="-DASMV -DASMINF -I." OBJA="inffasx64.obj gvmat64.obj inffas8664.obj"
  ) ELSE (
    nmake -f win32/Makefile.msc LOC="-DASMV -DASMINF" OBJA="inffas32.obj match686.obj"
  )

  MD %INSTALL_DIR%\bin %INSTALL_DIR%\include %INSTALL_DIR%\lib

  COPY zconf.h %INSTALL_DIR%\include
  COPY zlib.h  %INSTALL_DIR%\include

  IF /I "%LINK_TYPE%"=="static" (
    COPY zlib.lib %INSTALL_DIR%\lib
    COPY zlib.lib %INSTALL_DIR%\lib\zlib1.lib
  ) ELSE (
    COPY zlib1.dll %INSTALL_DIR%\bin

    COPY zdll.lib %INSTALL_DIR%\lib\zlib.lib
    COPY zdll.lib %INSTALL_DIR%\lib\zlib1.lib
  )

  POPD
  CALL common :BUILD_PACK %~n0

