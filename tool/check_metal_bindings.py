"""Compile bundled runtime shaders to Metal source and enforce binding limit."""

import json
import platform
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    flutter = shutil.which("flutter")
    if flutter is None:
        raise RuntimeError("flutter is required")
    sdk = Path(flutter).resolve().parent.parent
    compilers = list((sdk / "bin/cache/artifacts/engine").glob("*/impellerc"))
    if not compilers:
        raise RuntimeError("Flutter impellerc is missing; run flutter precache")
    arch = "arm64" if platform.machine().lower() in ("arm64", "aarch64") else "x64"
    host = ("darwin" if sys.platform == "darwin" else "linux") + f"-{arch}"
    compiler = next((path for path in compilers if path.parent.name == host), compilers[0])
    version = json.loads(subprocess.check_output([flutter, "--no-version-check", "--version", "--machine"], text=True))[
        "frameworkVersion"]
    old_gles = tuple(map(int, re.match(r"\d+\.\d+\.\d+", version).group().split("."))) < (3, 47, 0)
    include = compiler.parent / "shader_lib"
    shaders = sorted((Path(__file__).resolve().parents[1] / "lib/shaders").glob("*.frag"))
    failed = False
    with tempfile.TemporaryDirectory() as temporary:
        for shader in shaders:
            output = Path(temporary) / f"{shader.stem}.metal"
            result = subprocess.run(
                [str(compiler), "--runtime-stage-metal", f"--input={shader}",
                 "--input-type=frag", f"--include={include}", f"--sl={output}",
                 f"--spirv={output}.spv"],
                capture_output=True, text=True,
            )
            if result.returncode:
                print(f"{shader.name}: Metal compilation failed\n{result.stderr}", file=sys.stderr)
                failed = True
                continue
            bindings = [int(n) for n in re.findall(r"\[\[buffer\((\d+)\)\]\]", output.read_text())]
            highest = max(bindings, default=-1)
            print(f"{shader.name}: highest Metal buffer binding {highest}")
            failed |= highest > 30
        glass = next(s for s in shaders if s.name == "liquid_glass.frag")
        for legacy in (True, False):
            output = Path(temporary) / ("glass_legacy.glsl" if legacy else "glass_current.glsl")
            defines = ["--define=IMPELLER_TARGET_OPENGLES"]
            if not legacy:
                defines.append("--define=IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED")
            result = subprocess.run(
                [str(compiler), "--runtime-stage-gles", *defines, f"--input={glass}",
                 "--input-type=frag", f"--include={include}", f"--sl={output}",
                 f"--spirv={output}.spv"],
                capture_output=True, text=True,
            )
            if result.returncode:
                print(f"{glass.name}: GLES compilation failed\n{result.stderr}", file=sys.stderr)
                failed = True
                continue
            flipped = bool(re.search(r"\.y\s*=\s*1\.0\s*-", output.read_text()))
            print(f"{glass.name}: {'legacy' if legacy else 'current'} GLES Y flip {flipped}")
            failed |= flipped != (legacy and old_gles)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
