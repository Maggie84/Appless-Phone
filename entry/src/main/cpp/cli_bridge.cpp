#include <cstdio>
#include <cstring>
#include <cerrno>
#include <string>
#include <unistd.h>
#include <sys/wait.h>
#include <dlfcn.h>
#include "napi/native_api.h"

// sqlite3 forward declarations (linked at build time via -lsqlite)
struct sqlite3;
struct sqlite3_stmt;
typedef int (*sqlite3_callback)(void*, int, char**, char**);

static struct SqliteApi {
    void* handle;
    int (*open)(const char*, sqlite3**);
    int (*close)(sqlite3*);
    int (*exec)(sqlite3*, const char*, sqlite3_callback, void*, char**);
    const char* (*errmsg)(sqlite3*);
    void (*free)(void*);
} g_sql;

static bool ensureSqliteLoaded() {
    if (g_sql.open != nullptr) return true;
    // Library is already loaded in process; use RTLD_DEFAULT to find symbols
    g_sql.open = (int(*)(const char*, sqlite3**))dlsym(RTLD_DEFAULT, "sqlite3_open");
    g_sql.close = (int(*)(sqlite3*))dlsym(RTLD_DEFAULT, "sqlite3_close");
    g_sql.exec = (int(*)(sqlite3*, const char*, sqlite3_callback, void*, char**))dlsym(RTLD_DEFAULT, "sqlite3_exec");
    g_sql.errmsg = (const char*(*)(sqlite3*))dlsym(RTLD_DEFAULT, "sqlite3_errmsg");
    g_sql.free = (void(*)(void*))dlsym(RTLD_DEFAULT, "sqlite3_free");
    if (g_sql.open == nullptr || g_sql.exec == nullptr || g_sql.close == nullptr) {
        fprintf(stderr, "cli_bridge: dlsym(RTLD_DEFAULT) failed: open=%p exec=%p close=%p\n",
            g_sql.open, g_sql.exec, g_sql.close);
        return false;
    }
    return true;
}

struct ExecResult {
    std::string output;
    bool ok;
    std::string error;
};

static ExecResult execSql(const char* dbPath, const char* sql) {
    ExecResult result = {"", false, ""};
    if (!ensureSqliteLoaded()) {
        result.error = "failed to load libsqlite";
        return result;
    }
    sqlite3* db = nullptr;
    int rc = g_sql.open(dbPath, &db);
    if (rc != 0 || db == nullptr) {
        result.error = db ? g_sql.errmsg(db) : "open failed";
        if (db) g_sql.close(db);
        return result;
    }
    char* errMsg = nullptr;
    rc = g_sql.exec(db, sql, nullptr, nullptr, &errMsg);
    if (rc != 0) {
        result.error = errMsg ? errMsg : "exec failed";
        result.ok = false;
    } else {
        result.ok = true;
    }
    if (errMsg && g_sql.free) g_sql.free(errMsg);
    g_sql.close(db);
    return result;
}

struct CallbackData {
    std::string output;
};

static int queryCallback(void* data, int argc, char** argv, char** colNames) {
    CallbackData* cd = (CallbackData*)data;
    for (int i = 0; i < argc; i++) {
        if (i > 0) cd->output += "|";
        cd->output += (argv[i] ? argv[i] : "");
    }
    cd->output += "\n";
    return 0;
}

static ExecResult querySql(const char* dbPath, const char* sql) {
    ExecResult result = {"", false, ""};
    if (!ensureSqliteLoaded()) {
        result.error = "failed to load libsqlite";
        return result;
    }
    sqlite3* db = nullptr;
    int rc = g_sql.open(dbPath, &db);
    if (rc != 0 || db == nullptr) {
        result.error = db ? g_sql.errmsg(db) : "open failed";
        if (db) g_sql.close(db);
        return result;
    }
    CallbackData cd = {""};
    char* errMsg = nullptr;
    rc = g_sql.exec(db, sql, queryCallback, &cd, &errMsg);
    if (rc != 0) {
        result.error = errMsg ? errMsg : "query failed";
        result.ok = false;
    } else {
        result.output = cd.output;
        result.ok = true;
    }
    if (errMsg && g_sql.free) g_sql.free(errMsg);
    g_sql.close(db);
    return result;
}

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
        if (WIFEXITED(exitCode)) {
            exitCode = WEXITSTATUS(exitCode);
        } else if (WIFSIGNALED(exitCode)) {
            exitCode = -WTERMSIG(exitCode);
        }
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

static napi_value DbExec(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    char dbPath[1024] = {0};
    char sql[4096] = {0};
    size_t len1 = 0, len2 = 0;
    napi_get_value_string_utf8(env, argv[0], dbPath, sizeof(dbPath), &len1);
    napi_get_value_string_utf8(env, argv[1], sql, sizeof(sql), &len2);

    ExecResult result = execSql(dbPath, sql);

    napi_value obj;
    napi_create_object(env, &obj);
    napi_value okVal;
    napi_get_boolean(env, result.ok, &okVal);
    napi_set_named_property(env, obj, "ok", okVal);
    napi_value errVal;
    napi_create_string_utf8(env, result.error.c_str(), result.error.size(), &errVal);
    napi_set_named_property(env, obj, "error", errVal);
    return obj;
}

static napi_value DbQuery(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    char dbPath[1024] = {0};
    char sql[4096] = {0};
    size_t len1 = 0, len2 = 0;
    napi_get_value_string_utf8(env, argv[0], dbPath, sizeof(dbPath), &len1);
    napi_get_value_string_utf8(env, argv[1], sql, sizeof(sql), &len2);

    ExecResult result = querySql(dbPath, sql);

    napi_value obj;
    napi_create_object(env, &obj);
    napi_value okVal;
    napi_get_boolean(env, result.ok, &okVal);
    napi_set_named_property(env, obj, "ok", okVal);
    napi_value outVal;
    napi_create_string_utf8(env, result.output.c_str(), result.output.size(), &outVal);
    napi_set_named_property(env, obj, "stdout", outVal);
    napi_value errVal;
    napi_create_string_utf8(env, result.error.c_str(), result.error.size(), &errVal);
    napi_set_named_property(env, obj, "error", errVal);
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

    napi_value dbExecFn;
    napi_create_function(env, "dbExec", 6, DbExec, nullptr, &dbExecFn);
    napi_set_named_property(env, exports, "dbExec", dbExecFn);

    napi_value dbQueryFn;
    napi_create_function(env, "dbQuery", 7, DbQuery, nullptr, &dbQueryFn);
    napi_set_named_property(env, exports, "dbQuery", dbQueryFn);

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
