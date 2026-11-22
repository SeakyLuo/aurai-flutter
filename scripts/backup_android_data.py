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
import time

from terminal_progress import TransferProgress, duration, estimate_tar_bytes


PACKAGE = "com.haiskynology.aurai"
DB = "databases/aurai.sqlite"
ARCHIVE = "files-and-preferences.tar.gz"
BACKUP_PREFIX = "Aurai数据备份_"
MIB = 1024 * 1024


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


def verify(destination: Path, manifest: dict) -> set[str]:
    database = destination / DB
    connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
    try:
        result = connection.execute("PRAGMA quick_check").fetchall()
        if result != [("ok",)]:
            raise RuntimeError(f"SQLite quick_check: {result}")
    finally:
        connection.close()
    archive = destination / ARCHIVE
    with tarfile.open(archive, "r:gz") as source:
        roots = set()
        for entry in source:
            parts = entry.name.split("/")
            if (parts[0] not in {"files", "shared_prefs", "app_flutter"}
                    or any(part in {"", ".", ".."} for part in parts)
                    or not (entry.isfile() or entry.isdir())
                    or (len(parts) == 1 and not entry.isdir())):
                raise RuntimeError(f"归档包含不支持的条目：{entry.name}")
            roots.add(parts[0])
    if not {"files", "shared_prefs"} <= roots:
        raise RuntimeError(f"归档缺少必要目录：{roots}")
    with gzip.open(archive, "rb") as source:
        for _ in iter(lambda: source.read(1024 * 1024), b""):
            pass
    for entry in manifest["contents"]:
        path = destination / entry["path"]
        if path.stat().st_size != entry["bytes"] or sha256(path) != entry["sha256"]:
            raise RuntimeError(f"文件大小或 SHA-256 校验失败：{path}")
    return roots


def download(adb, arguments, output, size, label):
    command = [*adb, "shell", "-T", shlex.join(["run-as", PACKAGE, *arguments])]
    with TransferProgress(label, size) as progress:
        # Shell v2 keeps Android diagnostics out of the binary stream.
        with subprocess.Popen(command, stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE) as process:
            while chunk := process.stdout.read1(MIB):
                output.write(chunk)
                progress.advance(len(chunk))
            code = process.wait()
            if code:
                raise subprocess.CalledProcessError(code, command)


def main() -> None:
    parser = argparse.ArgumentParser(description="将 Aurai 真机数据备份到桌面并校验")
    parser.add_argument("--adb", help="ADB 可执行文件路径")
    parser.add_argument("--device", help="多设备时指定 adb 序列号")
    parser.add_argument("--output", type=Path, help="备份父目录，默认为桌面")
    args = parser.parse_args()
    started = time.monotonic()
    adb_path = args.adb or find_adb()
    device = select_device(adb_path, args.device)

    command = [adb_path, "-s", device]

    def app_shell(*arguments: str, capture=False):
        return subprocess.run(
            [*command, "shell", "-T", shlex.join(["run-as", PACKAGE, *arguments])],
            stdout=subprocess.PIPE if capture else None, text=True, check=True,
        ).stdout

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    parent = args.output if args.output is not None else desktop_path()
    destination = (parent / f"{BACKUP_PREFIX}{timestamp}").resolve()
    (destination / "databases").mkdir(parents=True)
    print(f"备份目录：{destination}", flush=True)
    snapshot = f"cache/aurai-backup-{timestamp}.sqlite"

    # SQLite's backup API produces one consistent database image even in WAL mode.
    print("正在创建数据库一致性快照…", flush=True)
    app_shell("sqlite3", DB, f".backup '{snapshot}'")
    database = destination / DB
    try:
        size = int(app_shell("stat", "-c", "%s", snapshot, capture=True))
        with database.open("wb") as output:
            download(command, ("cat", snapshot), output, size, "下载数据库快照")
    finally:
        app_shell("rm", snapshot)

    print("正在统计需要归档的文件…", flush=True)
    directories = ["files", "shared_prefs"]
    if "app_flutter" in app_shell("ls", "-a", capture=True).splitlines():
        directories.append("app_flutter")
    sizes = app_shell("find", *directories, "-exec", "stat", "-c", "%s", "{}", "+",
                      capture=True)
    archive = destination / ARCHIVE
    with gzip.open(archive, "wb", compresslevel=6) as output:
        download(command, ("tar", "-cf", "-", *directories), output,
                 estimate_tar_bytes(sizes), "下载并压缩应用文件")

    print("正在校验数据库、压缩包及 SHA-256…", flush=True)
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
    verify(destination, manifest)
    manifest["verifiedAt"] = datetime.now().astimezone().isoformat()
    (destination / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    total = sum(entry["bytes"] for entry in manifest["contents"])
    print(f"备份完成，全部校验通过（{total / MIB:.1f} MiB）"
          f" · 总用时 {duration(time.monotonic() - started)}：{destination}")


if __name__ == "__main__":
    main()
