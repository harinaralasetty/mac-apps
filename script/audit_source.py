#!/usr/bin/env python3
"""Check tracked source before a personal GitHub handoff. Prints paths only."""
import pathlib, re, subprocess, sys
root = pathlib.Path(__file__).resolve().parents[1]
paths = subprocess.check_output(['git','ls-files','-z'], cwd=root).decode().split('\0')
patterns = [
    rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    rb'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16})\b',
    rb'\bsk-[A-Za-z0-9_-]{24,}\b',
    rb'(?i)(?:api[_-]?key|access[_-]?token|password|secret)\s*[:=]\s*[\"\x27][A-Za-z0-9/+_-]{16,}'
]
allowed_assets = {'.png', '.icns', '.jpg'}
failures = []
for name in filter(None, paths):
    path = root / name
    data = path.read_bytes()
    if any(part in {'.build','dist','outputs','recovery','verification','node_modules','.aws','.ssh'} for part in path.relative_to(root).parts):
        failures.append((name, 'generated or private directory'))
    elif any(re.search(pattern, data) for pattern in patterns):
        failures.append((name, 'possible credential'))
    elif b'\0' in data and path.suffix not in allowed_assets:
        failures.append((name, 'unexpected binary'))
    elif path.suffix in allowed_assets and not name.startswith(('CaffeinateUI/Resources/', 'docs/screenshots/')):
        failures.append((name, 'unexpected asset'))
for name, reason in failures: print(f'FAIL: {name}: {reason}')
print(f'Scanned {len(list(filter(None, paths)))} tracked files; {len(failures)} findings.')
sys.exit(bool(failures))
