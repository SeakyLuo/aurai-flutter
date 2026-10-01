from __future__ import annotations

from datetime import datetime
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


ADB = Path.home() / "AppData/Local/Android/sdk/platform-tools/adb.exe"
DEVICE = "10AE3N1FS8000N2"
PACKAGE = "com.haiskynology.aurai"


def adb(*args: str, stdout=None) -> subprocess.CompletedProcess[bytes]:
    environment = os.environ.copy()
    environment["SystemRoot"] = r"C:\Windows"
    environment["windir"] = r"C:\Windows"
    return subprocess.run(
        [str(ADB), "-s", DEVICE, *args],
        env=environment,
        stdout=stdout,
        stderr=subprocess.PIPE,
        check=True,
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
desktop = Path.home() / "Desktop"
for previous in desktop.glob("Aurai数据备份_*"):
    if previous.is_dir() and not (previous / "manifest.json").exists():
        shutil.rmtree(previous)
destination = desktop / f"Aurai数据备份_{timestamp}"
(destination / "databases").mkdir(parents=True)

# SQLite's backup API produces one consistent database image even in WAL mode.
adb("shell", "run-as", PACKAGE, "rm", "-f", "cache/aurai-backup.sqlite")
adb(
    "shell",
    "run-as",
    PACKAGE,
    "sqlite3",
    "databases/aurai.sqlite",
    ".backup 'cache/aurai-backup.sqlite'",
)

database = destination / "databases" / "aurai.sqlite"
with database.open("wb") as output:
    adb(
        "exec-out",
        "run-as",
        PACKAGE,
        "cat",
        "cache/aurai-backup.sqlite",
        stdout=output,
    )

archive = destination / "files-and-preferences.tar.gz"
environment = os.environ.copy()
environment["SystemRoot"] = r"C:\Windows"
environment["windir"] = r"C:\Windows"
process = subprocess.Popen(
    [
        str(ADB),
        "-s",
        DEVICE,
        "exec-out",
        "run-as",
        PACKAGE,
        "tar",
        "-cf",
        "-",
        "files",
        "shared_prefs",
    ],
    env=environment,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
assert process.stdout is not None
with gzip.open(archive, "wb", compresslevel=6) as output:
    for chunk in iter(lambda: process.stdout.read(1024 * 1024), b""):
        output.write(chunk)
stderr = process.communicate()[1]
if process.returncode:
    raise RuntimeError(stderr.decode(errors="replace"))

adb("shell", "run-as", PACKAGE, "rm", "cache/aurai-backup.sqlite")

manifest = {
    "createdAt": datetime.now().astimezone().isoformat(),
    "device": DEVICE,
    "package": PACKAGE,
    "contents": [
        {
            "path": "databases/aurai.sqlite",
            "bytes": database.stat().st_size,
            "sha256": sha256(database),
            "kind": "SQLite consistent backup",
        },
        {
            "path": archive.name,
            "bytes": archive.stat().st_size,
            "sha256": sha256(archive),
            "kind": "files and shared preferences tar.gz",
        },
    ],
}
(destination / "manifest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
)

print(destination)
print(json.dumps(manifest, ensure_ascii=False, indent=2))
