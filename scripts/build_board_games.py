"""Bundle board games; rules are shared by the host and the board UI."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'miniapps/board-games'
GAMES = [
    ('reversi', '黑白棋', '森林棋室里的翻转对决，支持五档本地 AI、自动让行、悔棋和聊天观战。'),
    ('halma', '跳棋', '薄荷与蜜桃的双人星盘，支持连续跳跃、五档本地 AI、悔棋和聊天观战。'),
    ('connect4', '四子棋', '复古落子棋架，点击一列投下棋子。支持五档本地 AI、悔棋和聊天观战。'),
    ('tictactoe', '井字棋', '霓虹九宫格，本地 AI 即开即玩，无需联网或配置模型。支持悔棋、交换先手，也可在聊天中对弈和观战。'),
    ('xiangqi', '中国象棋', '直接与本地 AI开局，也可在私聊、群聊中选择 AI 对手。支持五档难度、悔棋、棋谱和同步观战。'),
    ('gomoku', '五子棋', '15 × 15 无禁手。直接与本地 AI开局，也可在聊天中选择 AI 对手，支持五档难度、悔棋和同步观战。'),
]


def build():
    catalog_path = ROOT / 'assets/miniapps/catalog.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    for game, title, description in GAMES:
        values = {'GAME': game, 'TITLE': title}
        values['CAPABILITIES'] = json.dumps(['messages.send', 'replies.interrupt'])
        for key, file in [('ENGINE', game + '.js'), ('PROGRAM', 'program.js'),
                          ('BOARD', 'board.js'), ('STYLE', 'style.css'), ('UI', 'ui.js'),
                          ('LOCAL_ENGINE', 'local-engine.js')]:
            values[key] = (SOURCE / file).read_text(encoding='utf-8')
        vendor = SOURCE / 'vendor'
        if game in ('reversi', 'halma', 'connect4'):
            values['BOARD'] = (SOURCE / 'classic-board.js').read_text(encoding='utf-8')
            values['STYLE'] += '\n' + (SOURCE / 'classic.css').read_text(encoding='utf-8') + '\n' + (SOURCE / (game + '.css')).read_text(encoding='utf-8')
            values['DIFFICULTY'] = ''
            worker = values['ENGINE'] + '\n' + (SOURCE / 'strategy-worker.js').read_text(encoding='utf-8')
        elif game == 'tictactoe':
            values['BOARD'] = (SOURCE / 'tictactoe_board.js').read_text(encoding='utf-8')
            values['STYLE'] += '\n' + (SOURCE / 'tictactoe.css').read_text(encoding='utf-8')
            values['DIFFICULTY'] = ''
            worker = values['ENGINE'] + '\n' + (SOURCE / 'tictactoe-worker.js').read_text(encoding='utf-8')
        elif game == 'xiangqi':
            worker = (vendor / 'xqwlight.min.js').read_text(encoding='utf-8') + '\n' + (SOURCE / 'xiangqi-worker.js').read_text(encoding='utf-8')
            values['DIFFICULTY'] = ''
        else:
            values['DIFFICULTY'] = (vendor / 'gomoku-difficulty.min.js').read_text(encoding='utf-8')
            worker = values['DIFFICULTY'] + '\n' + (vendor / 'gomoku-worker.min.js').read_text(encoding='utf-8')
        values['WORKER'] = json.dumps(worker, ensure_ascii=False).replace('</', '<\\/')
        license_file = 'XQWLight-LICENSE.txt' if game == 'xiangqi' else 'Gomoku-LICENSE.txt'
        values['LICENSE'] = json.dumps('Aurai local board game engine' if game in ('tictactoe', 'reversi', 'halma', 'connect4') else (vendor / license_file).read_text(encoding='utf-8'), ensure_ascii=False)
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
