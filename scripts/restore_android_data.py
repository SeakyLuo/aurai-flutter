"""Validate a desktop Aurai backup and queue it for the next app cold start."""
import argparse
import json
from pathlib import Path
import re
import shlex
import sqlite3
import subprocess
import time
from uuid import uuid4

from backup_android_data import (
    ARCHIVE, BACKUP_PREFIX, DB, MIB, PACKAGE, desktop_path, find_adb,
    select_device, verify,
)
from terminal_progress import TransferProgress, duration

BACKUP_NAME = re.compile(BACKUP_PREFIX + r"\d{8}_\d{6}_\d{6}")


def latest_backup():
    folders = [folder for folder in desktop_path().iterdir()
               if folder.is_dir() and BACKUP_NAME.fullmatch(folder.name)
               and (folder / "manifest.json").is_file()]
    if not folders:
        raise RuntimeError("桌面上没有带校验清单的 Aurai 数据备份。")
    return max(folders, key=lambda folder: folder.name)


def validate_backup(folder):
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    entries = {entry["path"]: entry for entry in manifest["contents"]}
    if (manifest["package"] != PACKAGE or not manifest.get("verifiedAt")
            or set(entries) != {DB, ARCHIVE} or len(manifest["contents"]) != 2):
        raise RuntimeError("备份清单未通过校验或文件范围不匹配。")
    roots = verify(folder, manifest)
    with sqlite3.connect((folder / DB).as_uri() + "?mode=ro&immutable=1",
                         uri=True) as database:
        version = database.execute("PRAGMA user_version").fetchone()[0]
        keys = {row[0] for row in database.execute(
            "SELECT key FROM app_state WHERE key IN (?, ?)",
            ("model_config_json", "encrypted_model_config"),
        )}
        if keys == {"encrypted_model_config"}:
            raise RuntimeError("备份仅含旧版设备加密模型设置，请在原应用打开模型设置后重新备份。")
    return entries, roots, version


def app_command(adb, script):
    return [*adb, "shell", "-T", shlex.join(["run-as", PACKAGE, "sh", "-c", script])]


def app_shell(adb, script, *, capture=False):
    return subprocess.run(app_command(adb, script), stdin=subprocess.DEVNULL,
                          stdout=subprocess.PIPE if capture else None,
                          text=True, check=True).stdout


def upload(adb, source, target, entry, label):
    command = app_command(adb, f"umask 077; cat > {target}")
    with TransferProgress(label, entry["bytes"]) as progress:
        with source.open("rb") as stream, subprocess.Popen(command, stdin=subprocess.PIPE) as process:
            try:
                with process.stdin:
                    while chunk := stream.read(MIB):
                        process.stdin.write(chunk)
                        progress.advance(len(chunk))
            except BrokenPipeError:
                code = process.wait()
                if code:
                    raise subprocess.CalledProcessError(code, command) from None
                raise
            progress.show(99, "已发送，等待手机写入…")
            code = process.wait()
            if code:
                raise subprocess.CalledProcessError(code, command)

    checksum = app_shell(adb, f"sha256sum {target}", capture=True).split()[0]
    if checksum != entry["sha256"]:
        raise RuntimeError(f"手机暂存文件 SHA-256 校验失败：{source.name}")


def stage_restore(adb, folder, entries, roots, version):
    installed_version = int(app_shell(
        adb, f"sqlite3 -readonly {DB} 'PRAGMA user_version;'",
        capture=True,
    ))
    if version > installed_version:
        raise RuntimeError("备份数据库版本高于手机当前数据库版本。")
    if "app_flutter" not in roots:
        # Older backups lacked app_flutter; only Flutter-generated files can be rebuilt.
        extra = app_shell(adb, """
            if [ -d app_flutter ]; then
                find app_flutter -mindepth 1 -maxdepth 1 \
                    ! -name flutter_assets ! -name 'res_timestamp-*'
            fi
        """, capture=True).strip()
        if extra:
            raise RuntimeError("备份缺少 app_flutter，而手机中含有该目录的应用数据。")

    stage = f".aurai-restore-{uuid4().hex}"
    archive = f"{stage}/{ARCHIVE}"
    app_shell(adb, f"""
        set -e
        if [ -e backup_import ] || [ -e backup_restore_journal.json ]; then
            echo '手机已有待处理的恢复，请先完成该操作。' >&2
            exit 1
        fi
        umask 077
        mkdir -p {stage}/databases
    """)
    try:
        upload(adb, folder / DB, f"{stage}/{DB}", entries[DB], "上传数据库")
        upload(adb, folder / ARCHIVE, archive, entries[ARCHIVE], "上传应用文件")
        print("传输校验通过，正在解包并校验手机暂存数据…", flush=True)
        app_shell(adb, f"""
            set -e
            tar -xzf {archive} -C {stage}
            rm {archive}
            test "$(sqlite3 -readonly {stage}/{DB} 'PRAGMA quick_check;')" = ok
            printf 1 > {stage}/READY
            mv -Tn {stage} backup_import
            if [ -e {stage} ]; then
                echo '手机已有待处理的恢复，请先完成该操作。' >&2
                exit 1
            fi
        """)
    finally:
        app_shell(adb, f"rm -rf {stage}")


def main():
    parser = argparse.ArgumentParser(description="将桌面上最新的 Aurai 备份暂存到 Android 手机")
    parser.add_argument("--backup", type=Path, help="指定备份文件夹")
    parser.add_argument("--adb", help="ADB 可执行文件路径")
    parser.add_argument("--device", help="多设备时指定 adb 序列号")
    parser.add_argument("--check", action="store_true", help="仅校验桌面备份")
    args = parser.parse_args()
    started = time.monotonic()
    folder = (args.backup.expanduser() if args.backup else latest_backup()).resolve()
    print(f"正在校验备份：{folder}", flush=True)
    entries, roots, version = validate_backup(folder)
    print("桌面备份校验通过。", flush=True)
    if args.check:
        return
    adb_path = args.adb or find_adb()
    device = select_device(adb_path, args.device)
    stage_restore([adb_path, "-s", device], folder, entries, roots, version)
    print(f"手机暂存完成 · 总用时 {duration(time.monotonic() - started)}。"
          "Aurai 将在下次冷启动时应用备份。", flush=True)


if __name__ == "__main__":
    main()
