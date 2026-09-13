package com.haiskynology.aurai;
import android.os.Bundle;
interface IPrivilegedShell {
    Bundle execute(String command, int timeoutSeconds) = 0;
    void cancel() = 1;
    void destroy() = 16777114;
}
