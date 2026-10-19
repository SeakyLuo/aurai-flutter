from __future__ import annotations

import argparse
from datetime import datetime
import gzip
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import tempfile


PACKAGE = "com.haiskynology.aurai"


def find_adb() -> str:
    executable = shutil.which("adb")
    if executable:
        return executable
    name = "adb.exe" if sys.platform == "win32" else "adb"
    sdk_roots = [Path(os.environ[key]) for key in ("ANDROID_HOME", "ANDROID_SDK_ROOT")
                 if os.environ.get(key)]
    if sys.platform == "darwin":
        sdk_roots.append(Path.home() / "Library/Android/sdk")
    elif sys.platform == "win32":
        sdk_roots.append(Path(os.environ["LOCALAPPDATA"]) / "Android/sdk")
    else:
        sdk_roots.append(Path.home() / "Android/Sdk")
    for root in sdk_roots:
        candidate = root / "platform-tools" / name
        if candidate.is_file():
            return str(candidate)
    raise FileNotFoundError("找不到 adb，请安装 Android SDK platform-tools 或指定 --adb 路径")


def select_device(adb_path: str, requested: str | None) -> str:
    result = subprocess.run([adb_path, "devices"], stdout=subprocess.PIPE, check=True)
    devices = dict(line.split() for line in result.stdout.decode().splitlines()[1:]
                   if line.strip())
    if requested:
        if devices.get(requested) != "device":
            raise RuntimeError(f"设备 {requested} 不可用：{devices.get(requested, '未连接')}")
        return requested
    if len(devices) != 1 or next(iter(devices.values())) != "device":
        raise RuntimeError(f"需要一台已授权设备；当前设备：{devices}。多台设备请用 --device 指定")
    return next(iter(devices))


def desktop_path() -> Path:
    if sys.platform == "win32":
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                            r"Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders") as key:
            value, _ = winreg.QueryValueEx(key, "Desktop")
        return Path(os.path.expandvars(value))
    return Path.home() / "Desktop"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify(destination: Path, manifest: dict) -> None:
    database = destination / "databases/aurai.sqlite"
    connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
    try:
        result = connection.execute("PRAGMA quick_check").fetchall()
        if result != [("ok",)]:
            raise RuntimeError(f"SQLite quick_check: {result}")
    finally:
        connection.close()
    archive = destination / "files-and-preferences.tar.gz"
    with tarfile.open(archive, "r:gz") as source:
        roots = {entry.name.split('/')[0] for entry in source}
    if not {"files", "shared_prefs"} <= roots:
        raise RuntimeError(f"归档缺少必要目录：{roots}")
    with gzip.open(archive, "rb") as source:
        for _ in iter(lambda: source.read(1024 * 1024), b""):
            pass
    for entry in manifest["contents"]:
        path = destination / entry["path"]
        if path.stat().st_size != entry["bytes"] or sha256(path) != entry["sha256"]:
            raise RuntimeError(f"文件大小或 SHA-256 校验失败：{path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="将 Aurai 真机数据备份到桌面并校验")
    parser.add_argument("--adb", help="ADB 可执行文件路径")
    parser.add_argument("--device", help="多设备时指定 adb 序列号")
    parser.add_argument("--output", type=Path, help="备份父目录，默认为桌面")
    args = parser.parse_args()
    adb_path = args.adb or find_adb()
    device = select_device(adb_path, args.device)

    def adb(*arguments: str, stdout=None) -> None:
        if arguments[0] == "shell":
            arguments = ("shell", shlex.join(arguments[1:]))
        # Inherit the host environment and expose ADB's original stderr.
        subprocess.run([adb_path, "-s", device, *arguments], stdout=stdout, check=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    parent = args.output if args.output is not None else desktop_path()
    destination = (parent / f"Aurai数据备份_{timestamp}").resolve()
    (destination / "databases").mkdir(parents=True)
    print(f"备份目录：{destination}", flush=True)
    snapshot = f"cache/aurai-backup-{timestamp}.sqlite"

    # SQLite's backup API produces one consistent database image even in WAL mode.
    print("正在创建数据库一致性快照…", flush=True)
    adb("shell", "run-as", PACKAGE, "sqlite3", "databases/aurai.sqlite",
        f".backup '{snapshot}'")
    database = destination / "databases/aurai.sqlite"
    with database.open("wb") as output:
        adb("exec-out", "run-as", PACKAGE, "cat", snapshot, stdout=output)

    print("正在备份文件和偏好设置…", flush=True)
    archive = destination / "files-and-preferences.tar.gz"
    # A temporary stderr file avoids pipe backpressure while streaming large archives.
    with tempfile.TemporaryFile() as errors:
        with subprocess.Popen(
            [adb_path, "-s", device, "exec-out", "run-as", PACKAGE,
             "tar", "-cf", "-", "files", "shared_prefs"],
            stdout=subprocess.PIPE, stderr=errors,
        ) as process:
            with gzip.open(archive, "wb", compresslevel=6) as output:
                shutil.copyfileobj(process.stdout, output, 1024 * 1024)
            returncode = process.wait()
            errors.seek(0)
            stderr = errors.read()
            if stderr:
                sys.stderr.buffer.write(stderr)
            if returncode:
                raise subprocess.CalledProcessError(returncode, process.args, stderr=stderr)
    adb("shell", "run-as", PACKAGE, "rm", snapshot)

    manifest = {
        "createdAt": datetime.now().astimezone().isoformat(),
        "device": device,
        "package": PACKAGE,
        "contents": [
            {"path": str(path.relative_to(destination)).replace("\\", "/"),
             "bytes": path.stat().st_size, "sha256": sha256(path), "kind": kind}
            for path, kind in (
                (database, "SQLite consistent backup"),
                (archive, "files and shared preferences tar.gz"),
            )
        ],
    }
    print("正在校验数据库、压缩包及 SHA-256…", flush=True)
    verify(destination, manifest)
    manifest["verifiedAt"] = datetime.now().astimezone().isoformat()
    (destination / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    total = sum(entry["bytes"] for entry in manifest["contents"])
    print(f"备份完成，全部校验通过（{total / 1024 / 1024:.1f} MiB）：{destination}")


if __name__ == "__main__":
    main()
