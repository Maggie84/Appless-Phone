#include <cstdio>
#include <cstring>
#include <cerrno>
#include <string>
#include <unistd.h>
#include "napi/native_api.h"

static napi_value Ping(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_string_utf8(env, "pong", 4, &result);
    return result;
}

static napi_value ExecuteSync(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    char cmdStr[4096] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, argv[0], cmdStr, sizeof(cmdStr), &len);

    // Wrap with sh -c to redirect stderr to stdout for capture
    std::string wrappedCmd = "/system/bin/sh -c '";
    wrappedCmd += cmdStr;
    wrappedCmd += " 2>&1'";

    FILE* fp = popen(wrappedCmd.c_str(), "r");
    std::string output;
    int exitCode = -1;
    std::string errorMsg;
    if (fp) {
        char buf[4096];
        while (fgets(buf, sizeof(buf), fp)) {
            output += buf;
        }
        exitCode = pclose(fp);
    } else {
        int err = errno;
        char buf[128];
        snprintf(buf, sizeof(buf), "popen failed errno=%d: %s", err, strerror(err));
        errorMsg = buf;
    }

    napi_value obj;
    napi_create_object(env, &obj);

    napi_value stdoutVal;
    napi_create_string_utf8(env, output.c_str(), output.size(), &stdoutVal);
    napi_set_named_property(env, obj, "stdout", stdoutVal);

    napi_value exitCodeVal;
    napi_create_int32(env, exitCode, &exitCodeVal);
    napi_set_named_property(env, obj, "exitCode", exitCodeVal);

    if (!errorMsg.empty()) {
        napi_value errVal;
        napi_create_string_utf8(env, errorMsg.c_str(), errorMsg.size(), &errVal);
        napi_set_named_property(env, obj, "error", errVal);
    }

    return obj;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_value pingFn;
    napi_create_function(env, "ping", 4, Ping, nullptr, &pingFn);
    napi_set_named_property(env, exports, "ping", pingFn);

    napi_value executeFn;
    napi_create_function(env, "execute", 7, ExecuteSync, nullptr, &executeFn);
    napi_set_named_property(env, exports, "execute", executeFn);

    return exports;
}
EXTERN_C_END

static napi_module nativeModule = {
    1,
    0,
    nullptr,
    Init,
    "cli_bridge",
    nullptr,
    { 0 },
};

extern "C" void napi_onLoad() {
    napi_module_register(&nativeModule);
}
