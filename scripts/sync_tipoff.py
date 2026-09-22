"""Bundle an already-built TipOff HTML package without changing its saved data."""
import hashlib
import json
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
data = source.read_bytes()
if len(data) > 4 * 1024 * 1024:
    raise SystemExit('TipOff HTML exceeds 4 MiB')
root = pathlib.Path(__file__).resolve().parents[1] / 'assets' / 'miniapps'
root.mkdir(parents=True, exist_ok=True)
(root / 'tipoff.html').write_bytes(data)
catalog_path = root / 'catalog.json'
catalog = json.loads(catalog_path.read_text()) if catalog_path.exists() else []
entry = {
    'id': 'builtin.tipoff',
    'title': 'TipOff',
    'description': '选择一位球员，重新打完整个职业生涯。创建球员、参加比赛，体验成长与交易。',
    'publisherId': 'user:local',
    'asset': 'assets/miniapps/tipoff.html',
    'iconAsset': 'assets/miniapps/icons/tipoff-logo.jpg',
    'version': hashlib.sha256(data).hexdigest(),
}
catalog = [item for item in catalog if item['id'] != entry['id']]
catalog.insert(0, entry)
catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
print(f'Bundled TipOff: {len(data):,} bytes')
