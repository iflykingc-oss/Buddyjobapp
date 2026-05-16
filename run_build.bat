@echo off
set DEVECO_SDK_HOME=C:\Users\Administrator\AppData\Local\Huawei\Sdk
"E:\DevEco Studio\tools\node\node.exe" "E:\DevEco Studio\tools\hvigor\bin\hvigorw.js" --mode module -p module=entry@default -p product=default assembleHap --analyze=normal --parallel --stacktrace > F:\build_out.txt 2>&1
