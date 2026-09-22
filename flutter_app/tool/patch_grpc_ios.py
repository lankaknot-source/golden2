"""Patch the legacy gRPC header used by older Firebase pods for modern Clang."""

from pathlib import Path
import re


def patch_grpc_header(project_root: Path) -> bool:
    header = (
        project_root
        / "ios"
        / "Pods"
        / "gRPC-Core"
        / "src"
        / "core"
        / "lib"
        / "promise"
        / "detail"
        / "basic_seq.h"
    )
    if not header.exists():
        print(f"gRPC-Core header not present; skipping: {header}")
        return False

    original = header.read_text(encoding="utf-8")
    # Older gRPC uses template member-call syntax that newer Apple Clang
    # rejects unless an explicit empty template argument list is present.
    patched = re.sub(
        r"(template\s+CallSeqFactory)\(",
        r"\1<>(",
        original,
    )
    if patched == original:
        print(f"gRPC-Core header already compatible: {header}")
        return False

    header.write_text(patched, encoding="utf-8")
    print(f"Patched gRPC-Core for modern Clang: {header}")
    return True


if __name__ == "__main__":
    patch_grpc_header(Path(__file__).resolve().parents[1])
