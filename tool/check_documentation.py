#!/usr/bin/env python3
"""Check canonical guide coverage, metadata, anchors and repository links."""
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]


def validate(root=ROOT):
    manifest = json.loads((root / 'doc/website.json').read_text())
    assert manifest['schema'] == 1 and manifest['package'] == 'nib_motion'
    assert manifest['channel'] in ('stable', 'next')
    assert re.fullmatch(r'\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?', manifest['package_version'])
    assert re.fullmatch(r'[0-9a-f]{40}', manifest['runtime_commit'])
    ids, sources, anchors = set(), set(), {}
    for entry in manifest['guides']:
        assert re.fullmatch(r'[a-z0-9-]+', entry['id'])
        assert entry['id'] not in ids, 'Duplicate guide ID'
        ids.add(entry['id'])
        assert entry['source'] == f'doc/guides/{entry["id"]}.md'
        sources.add(entry['source'])
        text = (root / entry['source']).read_text()
        meta, body = text.split('\n---\n', 1)
        assert json.loads(meta[4:])['id'] == entry['id']
        headings = re.findall(r'^<!-- section: ([a-z0-9-]+) -->$', body, re.M)
        assert headings and len(headings) == len(set(headings)), 'Duplicate section anchors'
        anchors[entry['source']] = set(headings)
        assert body.count('```') % 2 == 0, 'Unclosed code fence'
    assert sources == {p.relative_to(root).as_posix() for p in (root / 'doc/guides').glob('*.md')}, 'Unmapped guide'
    for source in sources:
        text = (root / source).read_text()
        for link in re.findall(r'^\[[^\]]+\]\(([^)]+)\)$', text, re.M):
            url = urlsplit(link)
            if url.scheme:
                assert url.scheme == 'https', 'Non-HTTPS external link'
                continue
            target = str(Path(source).parent / url.path)
            assert target in sources, f'Broken guide link: {source} -> {link}'
            assert not url.fragment or url.fragment in anchors[target], f'Broken anchor: {link}'
    return len(ids)


if __name__ == '__main__':
    print(f'PASS: {validate()} canonical guides; source coverage, metadata, links and anchors.')
