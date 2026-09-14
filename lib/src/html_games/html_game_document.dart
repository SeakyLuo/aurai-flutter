import 'dart:convert';
import 'html_game.dart';
import 'html_game_lifecycle.dart';

String htmlGameDocument(
  HtmlGame game, {
  bool dark = false,
  bool fullscreen = false,
  List<Object?> localState = const [],
}) {
  final local = base64Encode(utf8.encode(jsonEncode(localState)));
  final snapshot = base64Encode(utf8.encode(jsonEncode(game.snapshot())));
  return '''<!doctype html><html data-aurai-display="${fullscreen ? 'fullscreen' : 'inline'}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:; media-src data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
<style>
:root{color-scheme:${dark ? 'dark' : 'light'};--aurai-text:${dark ? '#eee8f7' : '#352b43'};--aurai-muted:${dark ? '#b7b0c4' : '#726b7c'};--aurai-field:${dark ? '#36333e' : '#f8f6fb'};--aurai-border:${dark ? '#51495f' : '#ded7e9'};--aurai-accent:${dark ? '#ddc5f7' : '#493365'}}
html,body{margin:0;padding:0;background:transparent;color:var(--aurai-text);font:14px/1.5 system-ui,sans-serif}*{box-sizing:border-box}
html[data-aurai-paused="true"] *{animation-play-state:paused!important}
#aurai-content{display:flow-root;width:100%;overflow-wrap:anywhere}
:where(input,textarea,select){font:inherit;color:var(--aurai-text);background:var(--aurai-field);border:1px solid var(--aurai-border);border-radius:12px;padding:10px;max-width:100%}
:where(button){font:inherit;border:0;border-radius:18px;padding:10px 14px;background:var(--aurai-accent);color:${dark ? '#352b43' : '#ffffff'}}
</style>
<script>
$htmlGameLifecycleScript
(()=>{
 let snapshot=JSON.parse(new TextDecoder().decode(Uint8Array.from(atob('$snapshot'),c=>c.charCodeAt(0))));
 const listeners=new Set();let pending=null;let timedOut=false;
 const publish=value=>{snapshot=value;for(const fn of listeners){try{fn(structuredClone(snapshot))}catch(e){console.error(e)}}};
 window.AuraiGame=Object.freeze({
   get snapshot(){return structuredClone(snapshot)},
   subscribe(fn){listeners.add(fn);fn(structuredClone(snapshot));return ()=>listeners.delete(fn)},
   commit(args){
     if(timedOut)return Promise.reject(new Error('操作未确认，请关闭后重新打开游戏确认状态'));
     if(pending)return Promise.reject(new Error('请等待当前操作完成'));
     return new Promise((resolve,reject)=>{
       pending={resolve,reject};
       const timer=setTimeout(()=>{if(pending){pending=null;timedOut=true;AuraiGameBridge.reopen();reject(new Error('操作未确认，请重新打开游戏确认状态后再继续'))}},15000);
       pending.timer=timer;
       AuraiGameBridge.postMessage(JSON.stringify(args));
     });
   }
 });
 window.__auraiGameState=value=>{if(value.version>=snapshot.version)publish(value)};
 window.__auraiGameReply=value=>{
   if(value.version!==undefined && value.version>=snapshot.version)publish(value);
   const current=pending;pending=null;if(!current)return;clearTimeout(current.timer);
   if(value.error)current.reject(new Error(value.error));else current.resolve(value);
 };
})();
</script></head><body><div id="aurai-content">${game.html}</div>
<script>
(()=>{
 const root=document.getElementById('aurai-content');
 const saved=JSON.parse(new TextDecoder().decode(Uint8Array.from(atob('$local'),c=>c.charCodeAt(0))));
 const fields=()=>Array.from(root.querySelectorAll('input,textarea,select')).filter(e=>e.type!=='password'&&e.type!=='file');
 fields().forEach((e,i)=>{const key=e.id||e.name||String(i);const value=saved.find(v=>v.key===key);if(value){e.value=value.value;e.checked=value.checked}});
 root.dispatchEvent(new CustomEvent('aurai:restore',{bubbles:true}));
 let frame=0,last=0;
 const measure=()=>{cancelAnimationFrame(frame);frame=requestAnimationFrame(()=>{const height=Math.ceil(root.getBoundingClientRect().height);if(height!==last){last=height;AuraiGameBridge.contentHeight(height)}})};
 new ResizeObserver(measure).observe(root);measure();
 const save=()=>{const values=fields().map((e,i)=>({key:e.id||e.name||String(i),value:e.value,checked:e.checked}));AuraiGameBridge.localState(JSON.stringify(values))};
 root.addEventListener('input',save);root.addEventListener('change',save);
 root.addEventListener('click',()=>setTimeout(save,0));
})();
</script></body></html>''';
}
