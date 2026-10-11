"""Bundle the guaranteed-solvable, offline sheep tile puzzle."""
from pathlib import Path
import base64
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'miniapps/sheep'

def build():
    engine = (SOURCE / 'engine.js').read_text(encoding='utf-8')
    worker = engine + '\nself.onmessage=({data})=>self.postMessage(Sheep.hint(data));'
    icon = ROOT / 'assets/miniapps/icons/sheep.png'
    values = {'ENGINE': engine, 'UI': (SOURCE / 'ui.js').read_text(encoding='utf-8'),
              'STYLE': (SOURCE / 'style.css').read_text(encoding='utf-8'),
              'WORKER': json.dumps(worker, ensure_ascii=False).replace('</', '<\\/'),
              'LOGO': 'data:image/png;base64,' + base64.b64encode(icon.read_bytes()).decode()}
    paths = {'UNDO': '<path d="M9 5 4 10l5 5M4 10h9a6 6 0 0 1 0 12" transform="translate(0 -2)"/>',
             'HINT': '<path d="M9 18h6m-5 3h4M8 13a6 6 0 1 1 8 0c-1.5 1-1.5 2-1.5 3h-5c0-1 0-2-1.5-3Z"/>',
             'RETRY': '<path d="M4 10a8 8 0 1 1 1 8M4 4v6h6"/>',
             'NEW': '<rect x="4" y="4" width="16" height="16" rx="5"/><path d="M8 8h.01M16 16h.01M12 12h.01"/>'}
    for name, path in paths.items():
        values[name] = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + path + '</svg>'
    html = (SOURCE / 'shell.html').read_text(encoding='utf-8')
    for key, value in values.items():
        html = html.replace('{{' + key + '}}', value)
    target = ROOT / 'assets/miniapps/sheep.html'
    target.write_text(html, encoding='utf-8', newline='\n')
    catalog_path = ROOT / 'assets/miniapps/catalog.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    entry = next((e for e in catalog if e['id'] == 'builtin.sheep'), None)
    if entry is None:
        entry = {'id': 'builtin.sheep', 'publisherId': 'user:local'}
        catalog.append(entry)
    entry.update(title='羊了个羊', description='每局都有通关解法的叠牌三消。七格收集槽、三档难度，支持撤回、提示、同关重来和离线保存。',
                 asset='assets/miniapps/sheep.html', iconAsset='assets/miniapps/icons/sheep.png',
                 version=hashlib.sha256(target.read_bytes()).hexdigest())
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('sheep: ' + str(target.stat().st_size) + ' bytes')

if __name__ == '__main__':
    build()
