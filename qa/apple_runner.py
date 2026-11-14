"""Run NibMotion Apple compatibility tests and keep raw, honest evidence."""

import argparse
import datetime as dt
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAN = json.loads((ROOT / "qa/apple_test_plan.json").read_text())
FATAL = re.compile(
    r"Could not register dynamic stage library|Failed to build runtime effect|"
    r"ERROR:flutter/impeller|Unhandled Exception|EXCEPTION CAUGHT",
    re.IGNORECASE,
)


def parse_event(line, names, outcomes):
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        return
    if event.get("type") == "testStart":
        names[event["test"]["id"]] = event["test"]["name"]
    elif event.get("type") == "testDone":
        name = names.get(event["testID"], "")
        match = re.search(r"QA-[A-Z]+-\d+", name)
        if match:
            outcomes[match.group()] = {
                "success": "passed", "failure": "failed", "error": "failed",
                "skipped": "blocked",
            }.get(event.get("result"), "failed")


def command(args, cwd, log):
    with log.open("a") as output:
        output.write(f"\n$ {' '.join(map(str, args))}\n")
        result = subprocess.run(args, cwd=cwd, stdout=output, stderr=subprocess.STDOUT,
                                text=True, check=False)
        output.write(f"exit={result.returncode}\n")
    return result.returncode


def capture(args, cwd, log):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, check=False)
    with log.open("a") as output:
        output.write(f"\n$ {' '.join(map(str, args))}\n{result.stdout}{result.stderr}\n")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("platform", choices=("macos", "ios"))
    parser.add_argument("--device", help="Required physical iPhone device ID")
    args = parser.parse_args()
    run_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + f"-{os.getpid()}"
    folder = ROOT / "qa/results" / run_id
    raw = folder / "raw"
    shots = folder / "screenshots"
    raw.mkdir(parents=True)
    shots.mkdir()
    preflight = raw / "preflight.log"
    test_log = raw / "flutter_test.log"
    selected = None
    phase = "preflight"
    exit_code = 2
    reason = ""
    names, outcomes = {}, {}
    environment = {
        "run_id": run_id, "host": platform.platform(),
        "github_hosted": bool(os.environ.get("GITHUB_ACTIONS")),
        "physical_host_verified": False,
        "renderer": "unverified; inspect Flutter and Impeller logs",
        "platform": args.platform, "selected_device": None,
    }
    try:
        git = capture(["git", "rev-parse", "HEAD"], ROOT, preflight)
        if git.returncode:
            raise RuntimeError("Cannot identify source commit")
        environment["source_commit"] = git.stdout.strip()
        status = capture(["git", "status", "--porcelain"], ROOT, preflight)
        environment["source_dirty"] = bool(status.stdout.strip())
        if environment["source_dirty"]:
            raise RuntimeError("Source checkout is dirty; commit or restore changes before evidence run")
        if platform.system() != "Darwin":
            raise RuntimeError("Apple tests require macOS host")
        for tool in ("flutter", "dart", "xcodebuild", "xcrun"):
            if not shutil.which(tool):
                raise RuntimeError(f"Missing required tool: {tool}")
        flutter = capture(["flutter", "--version", "--machine"], ROOT, preflight)
        if flutter.returncode:
            raise RuntimeError("Flutter version check failed")
        environment["flutter"] = json.loads(flutter.stdout)
        version = environment["flutter"].get("frameworkVersion", "0")
        if tuple(map(int, re.match(r"\d+\.\d+\.\d+", version).group().split("."))) < (3, 50, 0):
            raise RuntimeError("Flutter 3.50.0 or newer is required for target-device validation")
        environment["dart"] = capture(["dart", "--version"], ROOT, preflight).stderr.strip()
        xcode = capture(["xcodebuild", "-version"], ROOT, preflight)
        if xcode.returncode:
            raise RuntimeError("Xcode command-line tools are unavailable")
        environment["xcode"] = xcode.stdout.strip()
        if args.platform == "macos":
            if command(["flutter", "config", "--enable-macos-desktop"], ROOT, preflight):
                raise RuntimeError("Cannot enable macOS desktop")
        devices = capture(["flutter", "devices", "--machine"], ROOT, preflight)
        if devices.returncode:
            raise RuntimeError("Flutter device discovery failed")
        available = json.loads(devices.stdout)
        device_id = args.device if args.platform == "ios" else "macos"
        if args.platform == "ios" and not args.device:
            raise RuntimeError("Select a physical iPhone with --device DEVICE_ID")
        selected = next((item for item in available if item.get("id") == device_id), None)
        if selected is None:
            raise RuntimeError(f"Selected device {device_id} is unavailable")
        if args.platform == "ios" and (selected.get("emulator") or
                                       "ios" not in selected.get("targetPlatform", "").lower()):
            raise RuntimeError("Selected device is not a physical iPhone")
        environment["selected_device"] = selected
        environment["os_version"] = capture(["sw_vers"], ROOT, preflight).stdout.strip()
        native = ROOT / "example" / args.platform
        if not native.exists():
            if command(["flutter", "create", "--empty", f"--platforms={args.platform}",
                        "--project-name", "nib_motion_example", "."], ROOT / "example", preflight):
                raise RuntimeError(f"Cannot generate {args.platform} example scaffold")
        if args.platform == "ios":
            identities = capture(["security", "find-identity", "-v", "-p", "codesigning"],
                                 ROOT, preflight)
            environment["signing_identity_available"] = bool(re.search(r"\d+\) [0-9A-Fa-f]{40}", identities.stdout))
            project = native / "Runner.xcodeproj/project.pbxproj"
            team = re.search(r"DEVELOPMENT_TEAM = ([A-Z0-9]+);", project.read_text()) if project.exists() else None
            environment["development_team_configured"] = bool(team)
            if not environment["signing_identity_available"] or not team:
                raise RuntimeError("Physical iPhone signing is incomplete; set a team in Xcode and install a signing identity")
        phase = "setup"
        if command(["flutter", "pub", "get"], ROOT, preflight):
            raise RuntimeError("Package dependency resolution failed")
        if command(["flutter", "pub", "get"], ROOT / "example", preflight):
            raise RuntimeError("Example dependency resolution failed")
        if command([sys.executable, "tool/check_metal_bindings.py"], ROOT, preflight):
            raise RuntimeError("Metal shader binding check failed")
        if args.platform == "macos" and command(
                ["flutter", "build", "macos", "-t", "lib/demos.dart"],
                ROOT / "example", preflight):
            raise RuntimeError("macOS example build failed")
        phase = "tests"
        cmd = ["flutter", "test", "--no-pub", "--reporter", "json", "-d", device_id,
               f"--dart-define=NIB_QA_SCREENSHOT_DIR={shots}",
               "integration_test/apple_compatibility_test.dart"]
        with test_log.open("w") as output:
            output.write(f"$ {' '.join(cmd)}\n")
            process = subprocess.Popen(cmd, cwd=ROOT / "example", stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True, bufsize=1)
            try:
                for line in process.stdout:
                    output.write(line)
                    output.flush()
                    parse_event(line, names, outcomes)
                test_exit = process.wait()
            except KeyboardInterrupt:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                raise
        fatal = [line.strip() for line in test_log.read_text(errors="replace").splitlines()
                 if FATAL.search(line)]
        if fatal:
            reason = "Fatal Flutter or Impeller diagnostics found"
        elif test_exit:
            reason = f"Flutter integration tests exited {test_exit}"
        elif len(outcomes) != len(PLAN):
            reason = "Some test outcomes are missing"
        exit_code = 1 if reason else 0
    except KeyboardInterrupt:
        reason, exit_code = "Interrupted", 130
    except (OSError, ValueError, RuntimeError, AttributeError) as error:
        reason = str(error)
        exit_code = 1 if phase == "tests" else 2
    finally:
        environment["phase"] = phase
        log_text = test_log.read_text(errors="replace") if test_log.exists() else ""
        if re.search(r"Impeller.*Metal|Metal.*Impeller", log_text, re.IGNORECASE):
            environment["renderer"] = "Impeller Metal (runtime log)"
        (folder / "environment.json").write_text(json.dumps(environment, indent=2) + "\n")
        errors = [line.strip() for line in log_text.splitlines() if FATAL.search(line)]
        screenshot_files = sorted(str(path.relative_to(folder)) for path in shots.glob("*"))
        screenshot_by_test = {"QA-WATER-01": "water.png", "QA-GLASS-01": "glass.png",
                              "QA-DISSOLVE-01": "dissolve.png"}
        results = []
        for test in PLAN:
            automatic = outcomes.get(test["id"], "blocked" if exit_code == 2 else "not_run")
            if errors and automatic == "passed":
                automatic = "failed"
            manual = "not_run" if test["manual"] else "passed"
            overall = automatic if automatic != "passed" else manual
            shot_name = screenshot_by_test.get(test["id"])
            results.append({"id": test["id"], "component": test["component"],
                            "automatic_outcome": automatic, "manual_outcome": manual,
                            "outcome": overall, "expected": test["expected"],
                            "manual_requirement": test["manual"],
                            "screenshots": [path for path in screenshot_files
                                            if shot_name and path.endswith(shot_name)]})
        report = {"source_commit": environment.get("source_commit"),
                  "platform": args.platform, "device": selected, "exit_code": exit_code,
                  "reason": reason, "renderer_errors": errors,
                  "screenshots": screenshot_files,
                  "tests": results,
                  "unverified": ["Physical Mac status requires owner attestation",
                                 "Manual visual checks pending", "Renderer identity not verified by Flutter API"]}
        (folder / "results.json").write_text(json.dumps(report, indent=2) + "\n")
        lines = [f"# Apple QA {run_id}", "", f"Commit: `{environment.get('source_commit', 'unknown')}`",
                 f"Platform: {args.platform}; device: {selected.get('name') if selected else 'unavailable'}",
                 f"Exit: {exit_code}; reason: {reason or 'Automatic tests completed'}", "",
                 "| Test | Automatic | Manual | Overall |", "|---|---|---|---|"]
        lines += [f"| {item['id']} | {item['automatic_outcome']} | {item['manual_outcome']} | {item['outcome']} |"
                  for item in results]
        if errors:
            lines += ["", "## Renderer errors", *[f"- {error}" for error in errors[:20]]]
        lines += ["", "Raw logs: `raw/`; screenshots: `screenshots/`. Manual checks remain pending."]
        (folder / "summary.md").write_text("\n".join(lines) + "\n")
        print(f"{folder / 'summary.md'}: exit {exit_code}; {reason or 'automatic tests completed'}")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
