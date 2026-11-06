#!/usr/bin/env python3
"""Lossless opaque-file parts: pack SOURCE DIR; verify MANIFEST; restore MANIFEST OUTPUT.

No source interpretation or deletion. Pack uses 48 MiB parts; the callable
part_bytes argument permits smaller parts for bounded validation. All byte
reads/writes are at most 4 MiB. Outputs must be fresh. A manifest is published
last, after independent staged readback. Atomic no-clobber hardlinks require
a filesystem supporting hardlinks (staging is beside each destination).
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import tempfile

PART_BYTES = 48 * 1024**2
IO_BYTES = 4 * 1024**2
MANIFEST = "manifest.json"
SCHEMA = "opaque-byte-archive-v1"


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _name(value):
    _require(isinstance(value, str) and
             re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,239}", value) is not None,
             "Use a plain ASCII basename without paths or traversal.")
    return value


def _integer(value, minimum=0):
    return type(value) is int and value >= minimum


def _sha(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def _identity(info):
    return info.st_dev, info.st_ino


def _version(info):
    return (_identity(info), info.st_size, info.st_mtime_ns, info.st_ctime_ns)


@contextmanager
def _regular(path):
    """Reject symlinks and detect replacement between lstat and open."""
    before = path.lstat()
    _require(stat.S_ISREG(before.st_mode), f"Not a regular, non-symlink file: {path}")
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    with os.fdopen(fd, "rb") as stream:
        _require(_identity(os.fstat(stream.fileno())) == _identity(before),
                 f"File replaced while opening: {path}")
        yield stream


def _fresh(path):
    path = Path(path)
    _name(path.name)
    parent = path.parent.resolve(strict=True)
    _require(parent.is_dir(), "The output parent must be an existing directory.")
    result = parent / path.name
    if os.path.lexists(result):
        raise FileExistsError(f"Refusing existing output: {result}")
    return result


def _write(stream, data):
    view = memoryview(data)
    while view:
        count = stream.write(view)
        if not count:
            raise OSError("Short file write.")
        view = view[count:]


def _sync(stream):
    stream.flush()
    os.fsync(stream.fileno())


def _hash_file(path):
    digest = hashlib.sha256()
    count = 0
    with _regular(path) as stream:
        before = os.fstat(stream.fileno())
        while block := stream.read(IO_BYTES):
            digest.update(block)
            count += len(block)
        _require(_version(before) == _version(os.fstat(stream.fileno())),
                 f"File changed during read: {path}")
    return count, digest.hexdigest()


def _unlink_owned(path, identity):
    try:
        if _identity(path.lstat()) == identity:
            path.unlink()
    except FileNotFoundError:
        pass


def _remove_dir_owned(path, identity):
    if identity is None:
        return
    try:
        if _identity(path.lstat()) == identity:
            # Never recursively remove a directory with foreign additions.
            if not any(path.iterdir()):
                path.rmdir()
    except FileNotFoundError:
        pass


def _cleanup(files, directory, identity):
    for path, inode in reversed(list(files.items())):
        _unlink_owned(path, inode)
    _remove_dir_owned(directory, identity)


def _json_object(pairs):
    result = {}
    for key, value in pairs:
        _require(key not in result, f"Duplicate manifest key: {key}")
        result[key] = value
    return result


def _load_manifest(path):
    path = Path(path)
    _require(path.name == MANIFEST, f"Use the canonical {MANIFEST} filename.")
    path = path.parent.resolve(strict=True) / MANIFEST
    with _regular(path) as stream:
        data = stream.read(IO_BYTES)
        _require(not stream.read(1), "Manifest exceeds 4 MiB.")
    value = json.loads(data.decode("utf-8"), object_pairs_hook=_json_object)
    _require(type(value) is dict and set(value) ==
             {"schema", "original", "part_bytes", "parts"}, "Unknown manifest fields.")
    _require(value["schema"] == SCHEMA, "Unknown byte-archive schema.")
    original = value["original"]
    _require(type(original) is dict and set(original) == {"name", "bytes", "sha256"},
             "Invalid original-file record.")
    _name(original["name"])
    _require(_integer(original["bytes"]) and _sha(original["sha256"]),
             "Invalid original length/checksum.")
    size = value["part_bytes"]
    _require(_integer(size, 1) and size <= PART_BYTES, "Part size must be at most 48 MiB.")
    parts = value["parts"]
    _require(type(parts) is list and len(parts) == (original["bytes"] + size - 1) // size,
             "Part count does not match original length.")
    for index, part in enumerate(parts, 1):
        _require(type(part) is dict and set(part) == {"name", "bytes", "sha256"},
                 "Invalid part record.")
        _require(part["name"] == f"part-{index:06d}.bin", "Part names/order are not canonical.")
        expected = min(size, original["bytes"] - (index - 1) * size)
        _require(_integer(part["bytes"], 1) and part["bytes"] == expected and _sha(part["sha256"]),
                 "Invalid part length/checksum.")
    expected_names = {MANIFEST, *(part["name"] for part in parts)}
    _require({entry.name for entry in path.parent.iterdir() if entry.name != ".DS_Store"} == expected_names,
             "Archive directory contains missing or unlisted entries.")
    return path.parent, value


def _stream_archive(directory, value, output=None):
    whole = hashlib.sha256()
    total = 0
    for part in value["parts"]:
        digest = hashlib.sha256()
        count = 0
        with _regular(directory / part["name"]) as stream:
            before = os.fstat(stream.fileno())
            _require(before.st_size == part["bytes"], f"Part length changed: {part['name']}")
            while count < part["bytes"]:
                block = stream.read(min(IO_BYTES, part["bytes"] - count))
                _require(bool(block), f"Part shortened during read: {part['name']}")
                count += len(block)
                digest.update(block)
                whole.update(block)
                if output is not None:
                    _write(output, block)
            _require(not stream.read(1) and _version(before) == _version(os.fstat(stream.fileno())),
                     f"Part changed during read: {part['name']}")
        _require(count == part["bytes"] and digest.hexdigest() == part["sha256"],
                 f"Part checksum mismatch: {part['name']}")
        total += count
    original = value["original"]
    _require(total == original["bytes"] and whole.hexdigest() == original["sha256"],
             "Whole-file length/checksum mismatch.")
    return dict(original)


def verify(manifest_path):
    """Verify every ordered part and the reconstructed whole; return its record."""
    directory, value = _load_manifest(manifest_path)
    return _stream_archive(directory, value)


def pack(source, archive_dir, part_bytes=PART_BYTES):
    """Publish a fresh archive after full staged readback; never change source."""
    _require(_integer(part_bytes, 1) and part_bytes <= PART_BYTES,
             "part_bytes must be an integer from 1 through 48 MiB.")
    source = Path(source).absolute()
    original_name = _name(source.name)
    target = _fresh(archive_dir)
    stage = Path(tempfile.mkdtemp(prefix=f".{target.name}.pending-", dir=target.parent))
    stage_id = _identity(stage.stat())
    staged, linked = {}, {}
    target_id = None
    published = False
    try:
        whole = hashlib.sha256()
        parts = []
        with _regular(source) as stream:
            before = os.fstat(stream.fileno())
            total = 0
            while total < before.st_size:
                name = f"part-{len(parts) + 1:06d}.bin"
                path = stage / name
                limit = min(part_bytes, before.st_size - total)
                digest = hashlib.sha256()
                count = 0
                with path.open("xb") as output:
                    staged[path] = _identity(os.fstat(output.fileno()))
                    while count < limit:
                        block = stream.read(min(IO_BYTES, limit - count))
                        _require(bool(block), "Source shortened while packing.")
                        _write(output, block)
                        digest.update(block)
                        whole.update(block)
                        count += len(block)
                    _sync(output)
                parts.append({"name": name, "bytes": count, "sha256": digest.hexdigest()})
                total += count
            _require(not stream.read(1) and _version(before) == _version(os.fstat(stream.fileno())),
                     "Source changed while packing.")
        original = {"name": original_name, "bytes": total, "sha256": whole.hexdigest()}
        value = {"schema": SCHEMA, "original": original, "part_bytes": part_bytes, "parts": parts}
        encoded = (json.dumps(value, indent=2) + "\n").encode("utf-8")
        _require(len(encoded) <= IO_BYTES, "Manifest exceeds 4 MiB.")
        with (stage / MANIFEST).open("xb") as output:
            staged[stage / MANIFEST] = _identity(os.fstat(output.fileno()))
            _write(output, encoded)
            _sync(output)
        _require(verify(stage / MANIFEST) == original, "Staged archive readback changed.")
        _require(_hash_file(source) == (total, original["sha256"]), "Source changed after packing.")
        # mkdir claims the fresh destination atomically. Every hardlink is
        # also no-clobber; manifest-last makes a completed archive visible.
        target.mkdir()
        target_id = _identity(target.stat())
        for name in [part["name"] for part in parts] + [MANIFEST]:
            output = target / name
            os.link(stage / name, output, follow_symlinks=False)
            linked[output] = staged[stage / name]
            _require(_identity(output.lstat()) == linked[output], "Published part was replaced.")
        _load_manifest(target / MANIFEST)
        published = True
        return target / MANIFEST
    finally:
        if not published:
            _cleanup(linked, target, target_id)
        _cleanup(staged, stage, stage_id)


def restore(manifest_path, output_path):
    """Restore to an explicit fresh path, verify readback, then publish no-clobber."""
    target = _fresh(output_path)
    directory, value = _load_manifest(manifest_path)
    fd, name = tempfile.mkstemp(prefix=f".{target.name}.pending-", dir=target.parent)
    stage = Path(name)
    inode = _identity(os.fstat(fd))
    try:
        with os.fdopen(fd, "wb") as output:
            original = _stream_archive(directory, value, output)
            _sync(output)
        _require(_hash_file(stage) == (original["bytes"], original["sha256"]),
                 "Restored staging-file readback changed.")
        os.link(stage, target, follow_symlinks=False)
        return target
    finally:
        _unlink_owned(stage, inode)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    p = commands.add_parser("pack")
    p.add_argument("source")
    p.add_argument("archive_dir")
    p = commands.add_parser("verify")
    p.add_argument("manifest")
    p = commands.add_parser("restore")
    p.add_argument("manifest")
    p.add_argument("output")
    args = parser.parse_args(argv)
    try:
        if args.command == "pack":
            result = {"manifest": str(pack(args.source, args.archive_dir))}
        elif args.command == "verify":
            result = verify(args.manifest)
        else:
            result = {"restored": str(restore(args.manifest, args.output))}
    except (OSError, ValueError) as error:
        parser.exit(1, f"ByteArchive: {error}\n")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
