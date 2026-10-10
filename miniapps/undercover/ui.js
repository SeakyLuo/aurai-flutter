(()=>{
const $=id=>document.getElementById(id),full=()=>document.documentElement.dataset.auraiDisplay==='fullscreen';
let busy=false,rosterKey='',selection=new Set(),s,h;
function text(tag,value,cls){const node=document.createElement(tag);node.textContent=value;if(cls)node.className=cls;return node;}
function manage(){return h&&(h.viewerId===h.ownerId||h.viewerId==='user:local'||h.viewerId===s.hostId);}
function refreshMembers(){
  const key=JSON.stringify([h.members,$('host').value,busy,manage()]);if(key===rosterKey)return;rosterKey=key;
  const previous=$('host').value,hosts=h.members.filter(m=>m.kind==='agent');
  $('host').replaceChildren(...hosts.map(m=>{const o=text('option',m.name);o.value=m.id;return o;}));
  $('host').value=hosts.some(m=>m.id===previous)?previous:hosts.some(m=>m.id===h.ownerId)?h.ownerId:hosts[0]?.id||'';
  selection.delete($('host').value);
  $('members').replaceChildren(...h.members.filter(m=>m.id!==$('host').value).map(m=>{
    const label=text('label','','person'),input=document.createElement('input');input.type='checkbox';input.checked=selection.has(m.id);input.disabled=!manage()||busy;
    input.onchange=()=>{input.checked?selection.add(m.id):selection.delete(m.id);render();};label.append(input,document.createTextNode(' '+m.name));return label;
  }));
}
function render(){
  s=AuraiHTML.messageState;h=s._miniapp;
  const setup=!s.phase||s.phase==='setup',own=h?.own;
  $('intro').hidden=!setup;$('setup').hidden=!h||!setup;$('match').hidden=setup;
  $('status').textContent=setup?'等待开局':s.phase==='finished'?'本局结束':'第 '+s.round+' 轮';
  if(h&&setup){refreshMembers();$('setupHint').textContent=!manage()?'等待发起人选择玩家':!$('host').value?'先在聊天中添加一位 AI 主持人':'选择参赛玩家，主持人会私密出题。';
    $('host').disabled=!manage()||busy;$('count').disabled=!manage()||busy;
    $('start').disabled=!manage()||busy||!$('host').value||selection.size<3||Number($('count').value)*2>=selection.size;
  }
  if(!setup){
    const speaker=s.players.find(p=>p.id===s.speaker);
    $('phase').textContent=s.phase==='words'?'主持人正在出题':s.phase==='speech'?'轮到 '+speaker.name+' 描述':s.phase==='vote'?'投票中 · '+s.submittedCount+'/'+s.players.filter(p=>p.alive).length:s.winner==='civilian'?'平民获胜':s.winner==='undercover'?'卧底获胜':'本局已结束';
    $('players').replaceChildren(...s.players.map(p=>text('span',p.name+(p.role?' · '+(p.role==='undercover'?'卧底':'平民'):'')+(s.phase==='finished'&&p.word?' · '+p.word:''),'person'+(!p.alive?' out':'')+(p.id===s.speaker?' active':''))));
    $('privateWord').hidden=!own?.word||s.phase==='finished';$('word').textContent=own?.word||'';
    $('hostHint').hidden=!own?.isHost||s.phase==='finished';
    $('chatHint').hidden=!full()||s.phase==='finished'||s.phase==='words';
    $('timeline').replaceChildren(...s.timeline.map(row=>{const el=text('div','','log');el.append(text('strong',row.title));if(row.text)el.append(text('p',row.text,'aurai-muted'));return el;}));
    $('stop').hidden=!manage()||s.phase==='finished';$('stop').disabled=busy;
    $('nextGame').hidden=s.phase!=='finished'||h?.viewerId!=='user:local';$('nextGame').disabled=busy;
  }
  AuraiHTML.requestResize();
}
async function send(action,data={}){
  if(busy)return;busy=true;render();
  try{await AuraiHTML.submitEvent({eventId:crypto.randomUUID(),action,data,notifyAi:false});}
  finally{busy=false;render();}
}
$('host').onchange=()=>{rosterKey='';render();};$('count').oninput=render;
$('setup').onsubmit=ev=>{ev.preventDefault();void send('configure',{hostId:$('host').value,players:[...selection],undercoverCount:Number($('count').value)});};
$('stop').onclick=()=>{$('stopConfirm').hidden=false;AuraiHTML.requestResize();};$('cancelStop').onclick=()=>{$('stopConfirm').hidden=true;AuraiHTML.requestResize();};
$('confirmStop').onclick=()=>send('stop');$('nextGame').onclick=async()=>{if(busy)return;busy=true;render();try{await AuraiHTML.startNextSession();}finally{busy=false;render();}};
document.addEventListener('aurai:messageupdate',render);document.addEventListener('aurai:displaychange',render);render();
})();
