"""Bundle the first-phase NoBigDeal office puzzle as an offline Aurai miniapp."""
import base64
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'miniapps/no-big-deal'


def build():
    values = {key.upper(): (SOURCE / (key + '.js')).read_text(encoding='utf-8')
              for key in ['rules', 'welfare', 'board', 'work', 'campaign', 'merge', 'engine', 'inheritance', 'feedback', 'ui']}
    # Compact explicit statement boundaries in the generated bundle only.
    # Source modules and their comments remain readable and unchanged.
    for key, code in values.items():
        values[key] = ''.join(
            line.rstrip() + (' ' if line.rstrip().endswith((';', '{', ','))
                             and not line.lstrip().startswith('//') else '\n')
            for line in code.splitlines()).rstrip()
    values['STYLE'] = (SOURCE / 'style.css').read_text(encoding='utf-8') + (SOURCE / 'layout.css').read_text(encoding='utf-8')
    for asset in sorted((SOURCE / 'art').glob('*.webp')):
        values['ART_' + asset.stem.upper().replace('-', '_')] = 'data:image/webp;base64,' + base64.b64encode(asset.read_bytes()).decode()
    for key in ['paper', 'folder', 'box']:
        values[key.upper()] = 'data:image/webp;base64,' + base64.b64encode(
            (SOURCE / (key + '.webp')).read_bytes()).decode()
    for key in ['move', 'merge', 'collect', 'success', 'select']:
        values['SOUND_' + key.upper()] = 'data:audio/mpeg;base64,' + base64.b64encode(
            (SOURCE / 'audio' / (key + '.mp3')).read_bytes()).decode()
    paths = {
        'TASK': '<rect x="5" y="4" width="14" height="17" rx="3"/><path d="M9 3h6v3H9zM9 11h6M9 16h4"/>',
        'CABINET': '<rect x="4" y="3" width="16" height="18" rx="3"/><path d="M4 12h16M10 8h4M10 16h4"/>',
        'SHOP': '<path d="M3 9 5 4h14l2 5v2a3 3 0 0 1-6 0 3 3 0 0 1-6 0 3 3 0 0 1-6 0ZM5 14v7h14v-7M9 21v-5h6v5"/>',
        'COFFEE': '<path d="M5 8h12v8a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5ZM17 9h2a3 3 0 0 1 0 6h-2M8 3v2M13 3v2"/>',
    }
    for key, path in paths.items():
        values[key] = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" '
                       'stroke-width="1.65" stroke-linecap="round" '
                       'stroke-linejoin="round" aria-hidden="true">' + path + '</svg>')
    html = (SOURCE / 'shell.html').read_text(encoding='utf-8')
    # Script templates also contain artwork tokens, so expand code before images.
    for key, value in values.items():
        html = html.replace('{{' + key + '}}', value)
    if '{{' in html:
        raise ValueError('Unexpanded NoBigDeal template token')
    target = ROOT / 'assets/miniapps/no-big-deal.html'
    target.write_text(html, encoding='utf-8', newline='\n')
    catalog_path = ROOT / 'assets/miniapps/catalog.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    entry = next((e for e in catalog if e['id'] == 'builtin.no-big-deal'), None)
    if entry is None:
        entry = {'id': 'builtin.no-big-deal', 'publisherId': 'user:local'}
        catalog.append(entry)
    entry.update(title='问题不大',
                 description='扮演秘书汉娜，连线整理文件，撑过两天工作。处理需求、桌面意外和夜间疲劳，使用道具与后勤部，进度离线保存。',
                 asset='assets/miniapps/no-big-deal.html',
                 iconAsset='assets/miniapps/icons/no-big-deal.webp',
                 version=hashlib.sha256(target.read_bytes()).hexdigest())
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('no-big-deal: ' + str(target.stat().st_size) + ' bytes')


if __name__ == '__main__':
    build()
