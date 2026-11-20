#!/usr/bin/env python3
"""Installer/checker/reverter for the King Exit JoiPlay postload.rb patch."""

import argparse
import hashlib
import sys
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent
SRC_POSTLOAD = REPO_DIR / "postload.rb"

DEFAULT_GAME_DIRS = (
    Path("/storage/emulated/0/Download/kingexit"),
    Path.home() / "storage/shared/Download/kingexit",
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def resolve_game_dir(cli_dir: str | None) -> Path:
    if cli_dir:
        return Path(cli_dir).expanduser()
    for candidate in DEFAULT_GAME_DIRS:
        if candidate.is_dir():
            return candidate
    return DEFAULT_GAME_DIRS[0]


def cmd_check(game_dir: Path) -> int:
    if not SRC_POSTLOAD.is_file():
        print(f"ERROR: repo file missing: {SRC_POSTLOAD}", file=sys.stderr)
        return 2
    if not game_dir.is_dir():
        print(f"ERROR: game directory not found: {game_dir}", file=sys.stderr)
        return 2

    dst = game_dir / "postload.rb"
    if not dst.is_file():
        print(f"MISSING: {dst}")
        return 1

    src_hash = sha256_bytes(SRC_POSTLOAD.read_bytes())
    dst_hash = sha256_bytes(dst.read_bytes())
    if src_hash == dst_hash:
        print(f"OK: {dst} matches ({src_hash[:12]})")
        return 0

    print(f"MISMATCH: {dst} ({dst_hash[:12]} != {src_hash[:12]})")
    return 1


def cmd_apply(game_dir: Path) -> int:
    if not SRC_POSTLOAD.is_file():
        print(f"ERROR: repo file missing: {SRC_POSTLOAD}", file=sys.stderr)
        return 2
    if not game_dir.is_dir():
        print(f"ERROR: game directory not found: {game_dir}", file=sys.stderr)
        return 2

    src_bytes = SRC_POSTLOAD.read_bytes()
    src_hash = sha256_bytes(src_bytes)
    dst = game_dir / "postload.rb"
    bak = game_dir / "postload.rb.bak"

    if dst.is_file():
        dst_bytes = dst.read_bytes()
        if sha256_bytes(dst_bytes) == src_hash:
            print(f"OK: {dst} already up to date ({src_hash[:12]})")
            return 0
        if not bak.exists():
            bak.write_bytes(dst_bytes)
            print(f"BACKUP: {bak}")

    dst.write_bytes(src_bytes)
    print(f"APPLIED: {dst} ({src_hash[:12]})")
    return 0


def cmd_revert(game_dir: Path) -> int:
    if not game_dir.is_dir():
        print(f"ERROR: game directory not found: {game_dir}", file=sys.stderr)
        return 2

    dst = game_dir / "postload.rb"
    bak = game_dir / "postload.rb.bak"

    if bak.is_file():
        dst.write_bytes(bak.read_bytes())
        bak.unlink()
        print(f"REVERTED: restored {dst} from {bak.name}")
        return 0

    if dst.is_file():
        dst.unlink()
        print(f"REVERTED: removed {dst}")
        return 0

    print(f"OK: nothing to revert in {game_dir}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Install, verify, or revert King Exit's JoiPlay postload.rb patch."
    )
    parser.add_argument(
        "--game-dir",
        help="Path to the King Exit game folder (default: /storage/emulated/0/Download/kingexit)",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="Install postload.rb (default)")
    mode.add_argument("--check", action="store_true", help="Verify installed postload.rb")
    mode.add_argument("--revert", action="store_true", help="Remove postload.rb or restore backup")

    args = parser.parse_args()
    game_dir = resolve_game_dir(args.game_dir)

    if args.check:
        return cmd_check(game_dir)
    if args.revert:
        return cmd_revert(game_dir)
    return cmd_apply(game_dir)


if __name__ == "__main__":
    raise SystemExit(main())
