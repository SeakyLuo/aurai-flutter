import 'html_ai_script.dart';
import 'package:flutter/material.dart';
import 'html_message_theme.dart';
import 'html_message_components.dart';
import 'dart:convert';
import 'html_game.dart';
import 'html_game_lifecycle.dart';

String htmlGameDocument(
  HtmlGame game, {
  required ThemeData theme,
  bool fullscreen = false,
  List<Object?> localState = const [],
}) {
  final local = base64Encode(utf8.encode(jsonEncode(localState)));
  final snapshot = base64Encode(utf8.encode(jsonEncode(game.snapshot())));
  return '''<!doctype html><html data-aurai-display="${fullscreen ? 'fullscreen' : 'inline'}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' https:; style-src 'unsafe-inline' https:; img-src data: https:; font-src data: https:; media-src data: https:; connect-src https: wss:; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
<style id="aurai-theme">${htmlMessageTheme(theme)}</style>
<style>
html,body{margin:0;padding:0;background:transparent;color:var(--aurai-text);font:var(--aurai-font-size)/1.5 system-ui,sans-serif}*{box-sizing:border-box}
html[data-aurai-display="inline"],html[data-aurai-display="inline"] body{overflow:hidden;height:auto!important;min-height:0!important}
html[data-aurai-paused="true"] *{animation-play-state:paused!important}
#aurai-content{display:flow-root;width:100%;overflow-wrap:anywhere}
:where(input,textarea,select){font:inherit;color:var(--aurai-text);background:var(--aurai-field);border:1px solid var(--aurai-border);border-radius:var(--aurai-field-radius);padding:10px;max-width:100%}
:where(button){font:inherit;border:0;border-radius:var(--aurai-button-radius);padding:10px 14px;background:var(--aurai-accent);color:var(--aurai-on-accent)}
$htmlMessageComponentStyles
</style>
<script>
(()=>{
 let last='',time=0;
 const report=message=>{const now=Date.now();if(message===last&&now-time<2000)return;last=message;time=now;AuraiGameBridge.reportError(message)};
 window.addEventListener('error',e=>report(e.message||'网页资源加载失败'));
 window.addEventListener('unhandledrejection',e=>report(String(e.reason?.message||e.reason)));
})();
$htmlAiScript
$htmlGameLifecycleScript
(()=>{
 let snapshot=JSON.parse(new TextDecoder().decode(Uint8Array.from(atob('$snapshot'),c=>c.charCodeAt(0))));
 const listeners=new Set();let pending=null;let timedOut=false;
 const publish=value=>{snapshot=value;for(const fn of listeners){try{fn(structuredClone(snapshot))}catch(e){AuraiGameBridge.reportError(String(e.message||e))}}};
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
 window.__auraiMessageState=()=>structuredClone(snapshot.state);
 const newerInteraction=(a,b)=>{if(!a)return false;if(!b)return true;for(const k of ['revision','sessionVersion','participantRevision','callbackVersion']){if(a[k]!==b[k])return a[k]>b[k]}return false};
 window.__auraiInteractionState=()=>structuredClone(snapshot.interaction??null);
 window.__auraiApplyInteraction=value=>{if(newerInteraction(value,snapshot.interaction)){publish({...snapshot,interaction:value});document.dispatchEvent(new Event('aurai:messageupdate'))}};
 window.__auraiGameState=value=>{if(value.version>snapshot.version||(value.version===snapshot.version&&newerInteraction(value.interaction,snapshot.interaction))){publish(value);document.dispatchEvent(new Event('aurai:messageupdate'))}};
 window.__auraiGameReply=value=>{
   if(value.version!==undefined && value.version>snapshot.version)publish(value);
   const current=pending;pending=null;if(!current)return;clearTimeout(current.timer);
   if(value.error)current.reject(new Error(value.error));else current.resolve(value);
 };
})();
</script></head><body><div id="aurai-content">${game.html}</div>
<style>html,body,#aurai-content{background:transparent!important}</style>
<script>
$htmlMessageComponentScript
(()=>{
 const root=document.getElementById('aurai-content');
 const saved=JSON.parse(new TextDecoder().decode(Uint8Array.from(atob('$local'),c=>c.charCodeAt(0))));
 const editing=window.__auraiEditing=()=>{const e=document.activeElement;return root.contains(e)&&(e.matches('input,textarea,select')||e.isContentEditable)};
 root.addEventListener('focusin',()=>AuraiGameBridge.editing(editing()));
 root.addEventListener('focusout',()=>setTimeout(()=>AuraiGameBridge.editing(editing()),0));
 const fields=()=>Array.from(root.querySelectorAll('input,textarea,select')).filter(e=>e.type!=='password'&&e.type!=='file');
 fields().forEach((e,i)=>{const key=e.id||e.name||String(i);const value=saved.find(v=>v.key===key);if(value){e.value=value.value;e.checked=value.checked}});
 root.dispatchEvent(new CustomEvent('aurai:restore',{bubbles:true}));
 const viewport=saved.find(v=>v.viewport===true);
 if(viewport)requestAnimationFrame(()=>window.scrollTo(viewport.x,viewport.y));
 let frame=0,last=0,width=window.innerWidth,display=document.documentElement.dataset.auraiDisplay;
 const measure=()=>{cancelAnimationFrame(frame);frame=requestAnimationFrame(()=>{const height=Math.ceil(root.getBoundingClientRect().height);if(height!==last){last=height;AuraiGameBridge.contentHeight(height)}})};
 window.__auraiMeasure=()=>{if(last>0)AuraiGameBridge.contentHeight(last);else measure();lastGestures='';reportGestures()};
 // Measure once after initial layout; later DOM changes keep the card stable.
 window.addEventListener('load',measure,{once:true});
 window.addEventListener('resize',()=>{if(width!==window.innerWidth){width=window.innerWidth;measure()}reportGestures()});
 document.addEventListener('aurai:resize',()=>{measure();reportGestures()});
 document.addEventListener('aurai:displaychange',()=>{const next=document.documentElement.dataset.auraiDisplay;if(next!==display){display=next;measure()}reportGestures()});
 let gestureFrame=0,lastGestures='';
 function reportGestures(){cancelAnimationFrame(gestureFrame);gestureFrame=requestAnimationFrame(()=>{
   const rects=Array.from(root.querySelectorAll('canvas,[data-aurai-gestures="exclusive"]'))
     .filter(e=>e.dataset.auraiGestures==='exclusive'||getComputedStyle(e).touchAction==='none')
     .map(e=>{const r=e.getBoundingClientRect();return [r.left,r.top,r.width,r.height]});
   const encoded=JSON.stringify(rects);if(encoded!==lastGestures){lastGestures=encoded;AuraiGameBridge.gestureRegions(encoded)}
 })}
 new ResizeObserver(reportGestures).observe(root);
 window.addEventListener('scroll',reportGestures,{passive:true});
 reportGestures();
 const formState=()=>JSON.stringify([...fields().map((e,i)=>({key:e.id||e.name||String(i),value:e.value,checked:e.checked})),{viewport:true,x:window.scrollX,y:window.scrollY}]);
 let lastSaved=formState(),saveTimer;
 const save=()=>{const encoded=formState();if(encoded!==lastSaved){lastSaved=encoded;AuraiGameBridge.localState(encoded)}};
 window.__auraiFlushForm=()=>{clearTimeout(saveTimer);save()};
 const scheduleSave=()=>{clearTimeout(saveTimer);saveTimer=setTimeout(()=>{save();AuraiGameBridge.visualChanged()},180)};
 root.addEventListener('input',scheduleSave);root.addEventListener('change',scheduleSave);
 root.addEventListener('click',scheduleSave);
 window.addEventListener('scroll',scheduleSave,{passive:true});
 let visualTimer;
 new MutationObserver(()=>{clearTimeout(visualTimer);visualTimer=setTimeout(()=>{AuraiGameBridge.visualChanged();reportGestures()},250)}).observe(root,{subtree:true,childList:true,characterData:true,attributes:true});
})();
</script></body></html>''';
}
