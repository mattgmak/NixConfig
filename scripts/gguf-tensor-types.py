#!/usr/bin/env python3
"""Print llama-quantize --tensor-type-file lines for a GGUF split.

Reference shards come first, then "--", then the shards to check. The check
fails when a target tensor has no reference type, so a mismatched fine-tune
stops before a long quantize run.
"""

import re
import sys

from gguf import GGUFReader


def entries(paths):
    for path in paths:
        for tensor in GGUFReader(path).tensors:
            yield tensor.name, tensor.tensor_type.name.lower()


def main(argv):
    sep = argv.index("--")
    ref = dict(entries(argv[:sep]))
    targets = argv[sep + 1 :]

    if targets:
        missing = sorted({name for name, _ in entries(targets)} - ref.keys())
        if missing:
            print("unmapped tensors: " + ", ".join(missing), file=sys.stderr)
            return 1

    # llama-quantize matches these as regexes with std::regex_search, so anchor
    # them. Without anchors a short name hits every tensor that contains it.
    for name, kind in sorted(ref.items()):
        print(f"^({re.escape(name)})$={kind}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
