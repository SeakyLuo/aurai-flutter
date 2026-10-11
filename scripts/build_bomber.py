"""Bundle the bomb arena game and register its local miniapp."""
from pathlib import Path
import base64
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'miniapps/bomber'

def build():
    values = {name.upper(): (SOURCE / filename).read_text(encoding='utf-8')
              for name, filename in [('rules', 'rules.js'), ('engine', 'engine.js'), ('render', 'render.js'), ('ui', 'ui.js'), ('style', 'style.css')]}
    values['LOGO'] = 'data:image/webp;base64,' + base64.b64encode((ROOT / 'assets/miniapps/icons/bomber.webp').read_bytes()).decode()
    paths = {
        'UP': '<path d="m6 15 6-6 6 6"/>',
        'RIGHT': '<path d="m9 6 6 6-6 6"/>',
        'DOWN': '<path d="m6 9 6 6 6-6"/>',
        'LEFT': '<path d="m15 6-6 6 6 6"/>',
        'PAUSE': '<path d="M9 5v14M15 5v14"/>',
        'BOMB': '<circle cx="11" cy="14" r="7"/><path d="m15 8 2-3h3M19 2v1m3 3h-1M21 2l-1 1M7 12c0-1 1-2 2-2"/>',
    }
    for name, path in paths.items():
        values[name] = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + path + '</svg>'
    html = (SOURCE / 'shell.html').read_text(encoding='utf-8')
    for name, value in values.items():
        html = html.replace('{{' + name + '}}', value)
    target = ROOT / 'assets/miniapps/bomber.html'
    target.write_text(html, encoding='utf-8', newline='\n')
    catalog_path = ROOT / 'assets/miniapps/catalog.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    entry = next((item for item in catalog if item['id'] == 'builtin.bomber'), None)
    if entry is None:
        entry = {'id': 'builtin.bomber', 'publisherId': 'user:local'}
        catalog.append(entry)
    entry.update(title='炸弹人', description='支持 2～4 人混战、四种玩法、七种道具。经典对战、限时缩圈、道具争夺、火力全开，与本地电脑或默认决策模型对战。',
                 asset='assets/miniapps/bomber.html', iconAsset='assets/miniapps/icons/bomber.webp',
                 version=hashlib.sha256(target.read_bytes()).hexdigest())
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'bomber: {target.stat().st_size} bytes')

if __name__ == '__main__':
    build()
