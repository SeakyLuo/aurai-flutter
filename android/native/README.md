# Local VPN forwarding

Aurai uses [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) to forward IPv4/IPv6 TCP and UDP packets to an authenticated loopback SOCKS5 relay. Upstream sockets are protected from the VPN. Aurai itself is excluded from capture. Connection metadata is bounded and held only in memory; this is not an HTTPS interception proxy.

`vendor/sources.json` pins the upstream commit and each recursive dependency, SHA-256 of the original GitHub source archive, and archive symlinks. The archives are included for reproducible offline native builds (1.2 MB); source code and license notices are preserved. Gradle expands them into the build directory and resolves header symlinks there. No upstream source is patched. License notices are also distributed in the application's `assets/licenses` directory.

`app/tunnel.gradle` invokes the installed Android NDK for arm64-v8a, armeabi-v7a and x86_64, independently of Flutter's own CMake project. `Android.mk` links the upstream sources and the JNI bridge in one library. The linker wraps `hev_socks5_tunnel_run` to acknowledge successful initialization before reporting capture as running. Failure, stop, revocation and timeout release the TUN and relay sockets. Start/stop are serialized by the service worker.

When upgrading, replace archives from pinned upstream commits, update SHA-256 values and symlink maps in `sources.json`, refresh packaged licenses, and build `:app:buildTunnel` plus the APK. The native bridge uses upstream initialization and cleanup without a separate IP/TCP stack implementation.
