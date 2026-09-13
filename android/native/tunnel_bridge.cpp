#include <jni.h>
#include <chrono>
#include <condition_variable>
#include <mutex>
#include <string>
#include <thread>
#include "hev-main.h"

static std::mutex state_mutex;
static std::condition_variable changed;
static std::thread worker;
static bool ready = false, finished = true, stopping = false;

// Signal readiness after the upstream engine has initialized its TUN and event loop.
extern "C" void __real_hev_socks5_tunnel_run(void);
extern "C" void __wrap_hev_socks5_tunnel_run(void) {
    {
        std::lock_guard<std::mutex> lock(state_mutex);
        ready = true;
        if (stopping) hev_socks5_tunnel_quit();
        changed.notify_all();
    }
    __real_hev_socks5_tunnel_run();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_haiskynology_aurai_TunnelEngine_start(JNIEnv *env, jobject, jstring config, jint fd) {
    const char *chars = env->GetStringUTFChars(config, nullptr);
    std::string text(chars);
    env->ReleaseStringUTFChars(config, chars);
    std::unique_lock<std::mutex> lock(state_mutex);
    if (worker.joinable()) return false;
    ready = false; finished = false; stopping = false;
    worker = std::thread([text, fd] {
        hev_socks5_tunnel_main_from_str(
            reinterpret_cast<const unsigned char *>(text.data()), text.size(), fd);
        std::lock_guard<std::mutex> done(state_mutex);
        finished = true;
        changed.notify_all();
    });
    changed.wait_for(lock, std::chrono::seconds(5), [] { return ready || finished; });
    return ready && !finished;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_haiskynology_aurai_TunnelEngine_isRunning(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(state_mutex);
    return ready && !finished && !stopping;
}

extern "C" JNIEXPORT void JNICALL
Java_com_haiskynology_aurai_TunnelEngine_stop(JNIEnv *, jobject) {
    {
        std::lock_guard<std::mutex> lock(state_mutex);
        stopping = true;
        if (ready && !finished) hev_socks5_tunnel_quit();
    }
    if (worker.joinable()) worker.join();
}
