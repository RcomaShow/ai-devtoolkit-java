#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path
import runpy


SCRIPT_PATH = Path(__file__).resolve().parents[1] / 'skills' / 'java-flow-analysis' / 'scripts' / 'analyze-java.py'

if __name__ == '__main__':
    runpy.run_path(str(SCRIPT_PATH), run_name='__main__')
