#!/usr/bin/env python3
"""Generate gallery cards from the app's catalog and existing PNGs."""
import argparse
import html
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
badges = Path(__file__).resolve().parents[1] / 'CaffeinateUI/Resources/Badges'
awards = json.loads((badges / 'catalog.json').read_text())['awards']
assert len(awards) == 12 and len({award['id'] for award in awards}) == 12
cards = []
for index, award in enumerate(awards, 1):
    assert (badges / award['image']).is_file()
    final = index == len(awards)
    escape = html.escape
    cards.append(f'<article class="card{" final" if final else ""}">'
                 f'<div class="rank">{"FINAL AWARD" if final else f"AWARD {index:02d}"}</div>'
                 f'<img src="{escape(award["image"])}" alt="{escape(award["title"])} badge">'
                 f'<div class="time">{escape(award["threshold_label"])}</div>'
                 f'<h2 class="title">{escape(award["title"])}</h2></article>')
preview = badges / 'preview.html'
old = preview.read_text()
prefix, rest = old.split('<section class="grid">', 1)
_, suffix = rest.split('</section>', 1)
new = prefix + '<section class="grid">' + ''.join(cards) + '</section>' + suffix
if args.check:
    if new != old:
        parser.exit(1, 'Gallery differs from the authoritative award catalog. Regenerate it.\n')
else:
    preview.write_text(new)
print('Verified 12 catalog labels, thresholds and existing image references.')
