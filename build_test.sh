#!/bin/bash
"E:\DevEco Studio\tools\node\node.exe" "E:\DevEco Studio\tools\hvigor\bin\hvigorw.js" --mode module -p module=entry@default -p product=default assembleHap --analyze=normal --parallel --incremental --daemon 2>&1 | grep -A 5 "ERROR:"
