#!/usr/bin/env python3

# Copyright 2026 Princeton Ferro <princetonferro@gmail.com>
# SPDX-License-Identifier: LGPL-2.1-or-later

from pathlib import Path
import shutil
import sys


def copy_tree(source, destination):
    if not source.is_dir():
        raise RuntimeError(f"documentation directory does not exist: {source}")
    shutil.copytree(source, destination)


def prepare_pages(landing, gi_docs, vala_docs, output):
    if output.exists():
        shutil.rmtree(output)

    copy_tree(landing, output)
    copy_tree(gi_docs, output / "gi")
    copy_tree(vala_docs, output / "vala")

    expected_files = (
        output / "index.html",
        output / "gi" / "index.html",
        output / "vala" / "index.html",
    )
    for filename in expected_files:
        if not filename.is_file():
            raise RuntimeError(f"documentation entry point does not exist: {filename}")

    symlinks = [path for path in output.rglob("*") if path.is_symlink()]
    if symlinks:
        names = ", ".join(str(path.relative_to(output)) for path in symlinks)
        raise RuntimeError(f"Pages output contains symbolic links: {names}")


def main(argv):
    if len(argv) != 5:
        print(
            "usage: prepare-pages.py LANDING GI_DOCS VALA_DOCS OUTPUT",
            file=sys.stderr,
        )
        return 2

    paths = [Path(argument).resolve() for argument in argv[1:]]
    try:
        prepare_pages(*paths)
    except (OSError, RuntimeError) as error:
        print(f"prepare-pages.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
