#!/usr/bin/env python3
"""Exercise the real QML service and disk persistence without opening windows."""
import os
from pathlib import Path
import subprocess
import tempfile
import shutil

with tempfile.TemporaryDirectory(prefix="solitaire-smoke-") as state:
    source = Path(__file__).resolve().parents[1]
    config = Path(state) / "config"
    config.mkdir()
    for name in ("Service.qml", "Game.js"):
        shutil.copy2(source / name, config / name)
    harness = Path(__file__).with_suffix('.qml').read_text().replace('import ".." as Solitaire', 'import "." as Solitaire').replace('import "../Game.js" as Game', 'import "Game.js" as Game')
    (config / "shell.qml").write_text(harness)
    for phase, marker in [("save", "SOLITAIRE_SAVE_PASS"), ("restore", "SOLITAIRE_RESTORE_PASS")]:
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_STATE_HOME=state, SOLITAIRE_SMOKE_PHASE=phase)
        result = subprocess.run(["quickshell", "--no-color", "-p", str(config)],
                                env=env, capture_output=True, text=True, timeout=12)
        log = result.stdout + result.stderr
        if marker not in log or "SOLITAIRE_SMOKE_FAIL" in log or "TypeError" in log or "ReferenceError" in log:
            raise SystemExit(log)
        print(phase + ": PASS")
