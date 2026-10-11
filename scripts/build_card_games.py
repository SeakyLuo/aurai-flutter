"""Bundle local card tables and their authoritative, private-hand reducers."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'miniapps/card-games'
GAMES = [
    ('doudizhu', '斗地主', '一副好牌，一场默契',
     '三人经典叫分，与两位本地 AI 较量。支持提示、农民配合与本局积分。', ['♣', 'A', '♦']),
    ('uno', 'UNO', '下一张，改变牌局',
     '四人经典配色牌局，与三位本地 AI 游玩。支持反转、UNO 与 +4 质疑。', ['↻', '4', '+2']),
    ('scout', 'Scout 马戏星探', '把你的手牌，变成好戏',
     '三人马戏牌局，与两位本地 AI 游玩。招募、演出，三轮决出最佳团长。', ['3', '4', '5']),
]


def build():
    catalog_path = ROOT / 'assets/miniapps/catalog.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    for game, title, subtitle, description, cover in GAMES:
        values = dict(GAME=game, TITLE=title, SUBTITLE=subtitle, DESCRIPTION=description,
                      COVER=''.join('<span>' + value + '</span>' for value in cover))
        for key, filename in [('RULES', game+'.js'), ('GAME_UI', game+'-ui.js'),
                              ('GAME_STYLE', game+'.css'), ('PROGRAM', 'program.js'),
                              ('STYLE', 'style.css'), ('UI', 'ui.js')]:
            values[key] = (SOURCE / filename).read_text(encoding='utf-8')
        # Rules are read from the same module for both an unstarted and saved table.
        values['UI'] = values['UI'].replace("'{{RULES_TEXT}}'", 'Cards.rules')
        html = (SOURCE / 'shell.html').read_text(encoding='utf-8')
        for key, value in values.items():
            html = html.replace('{{'+key+'}}', value)
        target = ROOT / ('assets/miniapps/'+game+'.html')
        target.write_text(html, encoding='utf-8', newline='\n')
        entry = next((item for item in catalog if item['id']=='builtin.'+game), None)
        if entry is None:
            entry = {'id': 'builtin.'+game, 'publisherId': 'user:local'}
            catalog.append(entry)
        entry.update(title=title, description=description, asset='assets/miniapps/'+game+'.html',
                     version=hashlib.sha256(target.read_bytes()).hexdigest())
        icon = ROOT / ('assets/miniapps/icons/'+game+'.png')
        if icon.is_file():
            entry['iconAsset'] = 'assets/miniapps/icons/'+game+'.png'
        print(title+': '+str(target.stat().st_size)+' bytes')
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    build()
