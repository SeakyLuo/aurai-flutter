"""Bundle the two board games; rules are shared by the host and the board UI."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'miniapps/board-games'
GAMES = [
    ('xiangqi', '中国象棋', '与 AI 对弈中国象棋，私聊、群聊都能玩。消息内预览棋盘，点击打开操作；每步回调，同步观战。'),
    ('gomoku', '五子棋', '与 AI 对弈五子棋，15 × 15 无禁手。支持聊天棋盘预览、全屏落子、每步回调和群聊观战。'),
]


def build():
    catalog_path = ROOT / 'assets/miniapps/catalog.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    for game, title, description in GAMES:
        values = {'GAME': game, 'TITLE': title}
        values['CAPABILITIES'] = json.dumps(['messages.send', 'replies.interrupt'])
        for key, file in [('ENGINE', game + '.js'), ('PROGRAM', 'program.js'),
                          ('BOARD', 'board.js'), ('STYLE', 'style.css'), ('UI', 'ui.js')]:
            values[key] = (SOURCE / file).read_text(encoding='utf-8')
        html = (SOURCE / 'shell.html').read_text(encoding='utf-8')
        for key, value in values.items():
            html = html.replace('{{' + key + '}}', value)
        target = ROOT / ('assets/miniapps/' + game + '.html')
        target.write_text(html, encoding='utf-8', newline='\n')
        entry = next((e for e in catalog if e['id'] == 'builtin.' + game), None)
        if entry is None:
            entry = {'id': 'builtin.' + game, 'publisherId': 'user:local'}
            catalog.append(entry)
        entry.update(title=title, description=description, asset='assets/miniapps/' + game + '.html',
                     version=hashlib.sha256(target.read_bytes()).hexdigest())
        icon = ROOT / ('assets/miniapps/icons/' + game + '.png')
        if icon.is_file():
            entry['iconAsset'] = 'assets/miniapps/icons/' + game + '.png'
        print(title + ': ' + str(len(html.encode('utf-8'))) + ' bytes')
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    build()
