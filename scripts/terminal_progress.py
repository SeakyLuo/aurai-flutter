"""In-place byte progress for Android backup and restore commands."""
import sys
import time


def duration(seconds):
    minutes, seconds = divmod(round(seconds), 60)
    return f"{minutes} 分 {seconds:02d} 秒" if minutes else f"{seconds} 秒"


def estimate_tar_bytes(entries):
    # Every tar member has a header, and file contents are padded to 512 bytes.
    return 1024 + sum(512 + (int(size) + 511) // 512 * 512
                      for size in entries.splitlines())


class TransferProgress:
    def __init__(self, label, total):
        self.label = label
        self.total = total
        self.transferred = 0
        self.terminal = sys.stderr.isatty()

    def __enter__(self):
        self.started = self.last_report = time.monotonic()
        self.show(0, "开始传输")
        return self

    def advance(self, count):
        self.transferred += count
        now = time.monotonic()
        if now - self.last_report < (0.2 if self.terminal else 3):
            return
        self.last_report = now
        percent = min(99, 100 * self.transferred // max(1, self.total))
        remaining = max(0, self.total - self.transferred)
        speed = self.transferred / (now - self.started)
        detail = f"剩约 {duration(remaining / speed)}" if remaining else "收尾中"
        self.show(percent, detail)

    def show(self, percent, detail, *, final=False):
        width = 18
        filled = percent * width // 100
        bar = "#" * filled + "-" * (width - filled)
        print(("\r\x1b[2K" if self.terminal else "")
              + f"{self.label} [{bar}] {percent:3d}%  {detail}",
              file=sys.stderr, end="\n" if final or not self.terminal else "", flush=True)

    def __exit__(self, error_type, error, traceback):
        elapsed = duration(time.monotonic() - self.started)
        if error_type is None:
            self.show(100, f"用时 {elapsed}", final=True)
        elif self.terminal:
            print(file=sys.stderr, flush=True)
