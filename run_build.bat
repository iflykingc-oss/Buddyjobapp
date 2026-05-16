@echo off
set DEVECO_SDK_HOME=E:\HuaweiSDK
"E:\DevEco Studio\tools\node\node.exe" "E:\DevEco Studio\tools\hvigor\bin\hvigorw.js" --mode module -p module=entry@default -p product=default assembleHap --analyze=normal --parallel > F:\build_out.txt 2>&1
echo Build finished, exit code: %errorlevel%
