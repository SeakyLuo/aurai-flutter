"""Bundle the host-controlled Who is the Undercover miniapp."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'miniapps/undercover'


def build():
    html = (SOURCE / 'shell.html').read_text(encoding='utf-8')
    for key, name in [('PROGRAM', 'program.js'), ('UI', 'ui.js')]:
        html = html.replace('{{' + key + '}}', (SOURCE / name).read_text(encoding='utf-8'))
    target = ROOT / 'assets/miniapps/undercover.html'
    target.write_text(html, encoding='utf-8', newline='\n')
    path = ROOT / 'assets/miniapps/catalog.json'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    entry = next((item for item in catalog if item['id'] == 'builtin.undercover'), None)
    if entry is None:
        entry = {'id': 'builtin.undercover', 'publisherId': 'user:local'}
        catalog.append(entry)
    entry.update(title='谁是卧底',
                 description='主持 AI 临场想词，程序私密发词、轮流描述、投票、平票加赛和结算。支持人类与 AI 群聊同玩，消息内预览、全屏参与。',
                 asset='assets/miniapps/undercover.html',
                 version=hashlib.sha256(target.read_bytes()).hexdigest())
    if (ROOT / 'assets/miniapps/icons/undercover.png').is_file():
        entry['iconAsset'] = 'assets/miniapps/icons/undercover.png'
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('谁是卧底: ' + str(len(html.encode('utf-8'))) + ' bytes')


if __name__ == '__main__':
    build()
