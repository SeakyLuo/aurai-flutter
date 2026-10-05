import json, sqlite3, tarfile, hashlib
from pathlib import Path
p=Path("C:/Users/luoki/Desktop/Aurai数据备份_20261006_021718")
m=json.loads((p/'manifest.json').read_text(encoding='utf-8'))
for f in m['contents']:
 q=p/f['path']; assert q.stat().st_size==f['bytes']; assert hashlib.file_digest(q.open('rb'),'sha256').hexdigest()==f['sha256']
c=sqlite3.connect('file:'+str(p/'databases/aurai.sqlite')+'?mode=ro',uri=True)
assert c.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
s=json.loads(c.execute("SELECT value FROM app_state WHERE key='miniapp-program:hmwfpre1zb'").fetchone()[0])
assert s['state']['players'][4]['previous']['r1s0']==['agent:hms4q8pn0b']
with tarfile.open(p/'files-and-preferences.tar.gz','r:gz') as t:
 entries=t.getmembers()
 assert any(e.name.startswith('files/') for e in entries)
 assert any(e.name.startswith('shared_prefs/') for e in entries)
 for e in entries:
  if e.isfile():
   f=t.extractfile(e)
   while f.read(1048576): pass
print('Verified: SHA256, SQLite integrity, corrected wolf target, complete archive; entries',len(entries))
