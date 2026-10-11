const $=id=>document.getElementById(id);
const el=(tag,value,cls)=>{const node=document.createElement(tag);node.textContent=value;if(cls)node.className=cls;return node;};
let s=AuraiHTML.messageState,busy=false,thinking=false,paused=false,generation=0,attempt='',timer=null;
const host=()=>s._miniapp;
const mine=()=>s.players?.find(p=>p.id===host()?.viewerId);
const aiTurn=()=>s.phase==='playing'&&s.players[s.turn].kind==='engine';
const key=()=>`${s.game}:${s.ply}`;
function cancel(){generation++;clearTimeout(timer);timer=null;thinking=false;}
async function continueAi(){
  if(busy||thinking||paused||!mine()||!aiTurn())return;
  const run=++generation;attempt=key();thinking=true;render();
  try{
    const job=await AuraiHTML.boardGame('begin');
    if(run!==generation||job.skipped)return;
    await AuraiHTML.boardGame('complete',{token:job.token,version:job.version,action:'cardAi',data:{game:job.view.game,ply:job.view.ply}});
  }finally{if(run===generation){thinking=false;render();}}
}
async function act(action,data={}){
  if(busy)return;cancel();busy=true;render();
  try{
    await AuraiHTML.boardGame('event',{eventId:crypto.randomUUID(),action,data:action==='configure'?data:{game:s.game,ply:s.ply,...data},notifyAi:false});
    attempt='';
  }finally{busy=false;render();}
}
function more(open){$('cardMorePanel').hidden=!open;$('cardMore').setAttribute('aria-expanded',String(open));$('cardLeaveConfirm').hidden=true;AuraiHTML.requestResize();}
function render(){
  s=AuraiHTML.messageState;
  const setup=!s.phase||s.phase==='setup',owner=host()?.viewerId==='user:local';
  $('cardSetup').hidden=!setup;$('cardMatch').hidden=setup;
  $('cardStatus').textContent=setup?'本地 AI':s.phase==='finished'?'本局结束':`第 ${s.game} 局`;
  $('cardRules').textContent=s.rules||'{{RULES_TEXT}}';
  $('cardStart').disabled=busy||!owner;
  $('cardSetupHint').textContent=host()?owner?'无需联网，也不用配置模型':'等待玩家开始对局':'从小程序库打开即可开始';
  if(!setup){
    $('cardPlayers').replaceChildren(...s.players.map((p,i)=>{
      const node=el('div','',`card-player${s.phase==='playing'&&s.turn===i?' active':''}`);
      node.append(el('span','','card-seat'),el('strong',p.name));
      if(s.counts)node.append(el('small',s.counts[i]+' 张'));
      node.setAttribute('aria-label',p.name+(s.phase==='playing'&&s.turn===i?'，正在行动':''));return node;
    }));
    if(s.abandoned){$('cardTable').replaceChildren(el('p','本局已结束，可重新开局。','aurai-muted'));}
    else CardUI.render($('cardTable'),s,host()?.own,{act,busy:busy||thinking,canPlay:!busy&&!thinking&&!!mine()&&s.turn===mine().side,el});
    $('cardContinue').hidden=s.phase==='finished';$('cardContinue').disabled=busy||thinking||!mine()||!aiTurn();
    $('cardContinue').setAttribute('aria-busy',String(thinking));
    $('cardRematch').hidden=s.phase!=='finished'||!mine();$('cardRematch').disabled=busy;
    $('cardLeave').hidden=s.phase==='finished'||!mine();
    $('cardLog').replaceChildren(...(s.logs||[]).map(item=>el('li',(item.seat>=0?s.players[item.seat].name+' · ':'')+item.text)));
  }
  AuraiHTML.requestResize();
  if(!setup&&!busy&&!thinking&&!paused&&mine()&&aiTurn()&&attempt!==key()&&!timer){
    timer=setTimeout(()=>{timer=null;void continueAi();},650);
  }
}
$('cardStart').onclick=()=>act('configure');
$('cardRematch').onclick=()=>{CardUI.reset();more(false);void act('rematch');};
$('cardContinue').onclick=()=>{clearTimeout(timer);timer=null;void continueAi();};
$('cardMore').onclick=()=>more($('cardMorePanel').hidden);$('cardCloseMore').onclick=()=>more(false);
$('cardLeave').onclick=()=>{$('cardLeaveConfirm').hidden=false;};
$('cardCancelLeave').onclick=()=>{$('cardLeaveConfirm').hidden=true;};
$('cardConfirmLeave').onclick=()=>{more(false);void act('leave');};
document.addEventListener('keydown',e=>{if(e.key==='Escape')more(false);});
document.addEventListener('aurai:pause',()=>{paused=true;cancel();});
document.addEventListener('aurai:resume',()=>{paused=false;attempt='';render();});
document.addEventListener('aurai:restore',render);
document.addEventListener('aurai:messageupdate',()=>{const next=AuraiHTML.messageState;if(next.game!==s.game||next.ply!==s.ply)cancel();render();});
document.addEventListener('aurai:displaychange',render);
render();
