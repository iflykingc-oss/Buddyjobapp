@echo off
set DEVECO_SDK_HOME=E:\DevEco Studio\sdk\default
"E:\DevEco Studio\tools\node\node.exe" "E:\DevEco Studio\tools\hvigor\bin\hvigorw.js" --mode module -p module=entry@default -p product=default assembleHap --analyze=normal --parallel > F:\build_out.txt 2>&1
echo exit:%errorlevel% >> F:\build_out.txt
