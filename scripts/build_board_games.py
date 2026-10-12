"""Bundle board games; rules are shared by the host and the board UI."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'miniapps/board-games'
GAMES = [
    ('reversi', '黑白棋', '森林棋室里的翻转对决，支持五档本地 AI、自动让行、悔棋和聊天观战。'),
    ('halma', '跳棋', '六色星盘，支持 2、3、4、6 人，聊天成员与本地电脑混合对局、连续跳跃、悔棋和观战。'),
    ('connect4', '四子棋', '复古落子棋架，点击一列投下棋子。支持五档本地 AI、悔棋和聊天观战。'),
    ('tictactoe', '井字棋', '霓虹九宫格，本地 AI 即开即玩，无需联网或配置模型。支持悔棋、交换先手，也可在聊天中对弈和观战。'),
    ('xiangqi', '中国象棋', '普通象棋、揭棋与半盘暗棋。支持五档本地对手、双方 AI 自动对弈、推荐下法、悔棋和聊天观战。'),
    ('gomoku', '五子棋', '15 × 15 无禁手。支持五档本地对手、双方 AI 自动对弈、推荐下法、悔棋和聊天观战。'),
]


def build():
    catalog_path = ROOT / 'assets/miniapps/catalog.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    for game, title, description in GAMES:
        values = {'GAME': game, 'TITLE': title}
        values['VARIANT_WORKER'] = ''
        values['CAPABILITIES'] = json.dumps(['messages.send', 'replies.interrupt'])
        for key, file in [('ENGINE', game + '.js'), ('PROGRAM', 'program.js'),
                          ('BOARD', 'board.js'), ('STYLE', 'style.css'), ('UI', 'ui.js'),
                          ('LOCAL_ENGINE', 'local-engine.js'), ('DIALOGS', 'dialogs.js')]:
            values[key] = (SOURCE / file).read_text(encoding='utf-8')
        if game == 'halma':
            values['PROGRAM'] = (SOURCE / 'halma-program.js').read_text(encoding='utf-8')
            values['UI'] = (SOURCE / 'halma-setup.js').read_text(encoding='utf-8') + '\n' + values['UI']
        vendor = SOURCE / 'vendor'
        if game in ('reversi', 'halma', 'connect4'):
            values['BOARD'] = (SOURCE / 'classic-board.js').read_text(encoding='utf-8')
            values['STYLE'] += '\n' + (SOURCE / 'classic.css').read_text(encoding='utf-8') + '\n' + (SOURCE / (game + '.css')).read_text(encoding='utf-8')
            values['DIFFICULTY'] = ''
            worker = values['ENGINE'] + '\n' + (SOURCE / ('halma-worker.js' if game == 'halma' else 'strategy-worker.js')).read_text(encoding='utf-8')
        elif game == 'tictactoe':
            values['BOARD'] = (SOURCE / 'tictactoe_board.js').read_text(encoding='utf-8')
            values['STYLE'] += '\n' + (SOURCE / 'tictactoe.css').read_text(encoding='utf-8')
            values['DIFFICULTY'] = ''
            worker = values['ENGINE'] + '\n' + (SOURCE / 'tictactoe-worker.js').read_text(encoding='utf-8')
        elif game == 'xiangqi':
            values['ENGINE'] += '\n' + (SOURCE / 'xiangqi-modes.js').read_text(encoding='utf-8')
            values['BOARD'] += '\n' + (SOURCE / 'xiangqi-mode-board.js').read_text(encoding='utf-8')
            hidden_worker = values['ENGINE'] + '\n' + (SOURCE / 'xiangqi-hidden-worker.js').read_text(encoding='utf-8')
            values['VARIANT_WORKER'] = '<script type="application/json" id="hiddenXiangqiEngineSource">' + json.dumps(hidden_worker, ensure_ascii=False).replace('</', '<\\/') + '</script>'
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
        if game == 'halma':
            marker = '<script type="application/json" id="aurai-send-action">'
            begin = html.index(marker) + len(marker)
            end = html.index('</script>', begin)
            launch = json.loads(html[begin:end])
            launch['initialView']['setupProtocol'] = '用户要求下跳棋时，由发起消息的 AI 调用 submitHtmlProgramEvent 开局。action:configure，data:{players:[成员ID列表],firstId:先手成员ID,difficulty:1至5}。players 支持 2、3、4、6 位不重复的当前聊天成员；仅本地用户可加入 engine:halma:1 至 engine:halma:5 作为电脑。firstId 必须在 players 中，默认用户先手。人数和玩家按用户要求选择，不代其他成员同意。仅 ownerId 或本地用户可配置。每席十子，按列表顺序轮流行动；颜色固定，下一局轮换先手。提交成功后 readHtmlProgram 读取最新棋盘及 own.protocol；只在轮到自己时走一步，随后结束执行，不轮询、不重复开局或发送棋盘。'
            html = html[:begin] + json.dumps(launch, ensure_ascii=False) + html[end:]
        if game == 'xiangqi':
            html = html.replace('humanFirst:boolean}', 'humanFirst:boolean,mode:string}，mode 可取 normal、jieqi、banqi，分别为普通象棋、揭棋、暗棋，未指定时默认 normal')
        target = ROOT / ('assets/miniapps/' + game + '.html')
        target.write_text(html, encoding='utf-8', newline='\n')
        entry = next((e for e in catalog if e['id'] == 'builtin.' + game), None)
        if entry is None:
            entry = {'id': 'builtin.' + game, 'publisherId': 'user:local'}
            catalog.append(entry)
        entry.update(title=title, description=description, asset='assets/miniapps/' + game + '.html',
                     version=hashlib.sha256(target.read_bytes()).hexdigest())
        icon = ROOT / ('assets/miniapps/icons/' + game + '.webp')
        if icon.is_file():
            entry['iconAsset'] = 'assets/miniapps/icons/' + game + '.webp'
        print(title + ': ' + str(len(html.encode('utf-8'))) + ' bytes')
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    build()
