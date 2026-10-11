const $=id=>document.getElementById(id);
const readGame=()=>{const saved=AuraiHTML.state?.game;return saved?.rulesVersion===3?saved:null;};
let game=readGame(),mode=game?game.mode:'local',arenaMode=game?game.arenaMode:'classic',playerCount=game?game.players.length:4,available=false,statusLoading=true,paused=true,busy=false,held=null;
let tactics=Array(4).fill('retreat'),request=null,generation=0,lastDecision=-10,lastFrame=0,accumulator=0,lastSaved=0,writing=Promise.resolve();
const freshSeed=()=>crypto.getRandomValues(new Uint32Array(1))[0];
function save(){const value={game:game?structuredClone(game):null};writing=writing.then(()=>AuraiHTML.saveState(value));return writing;}
function cancelDecision(){generation++;if(request){request.abort();request=null;}held=null;document.querySelectorAll('[data-dir]').forEach(b=>b.classList.remove('pressed'));}
function render(){
  $('setup').hidden=!!game;$('match').hidden=!game;$('modeBadge').textContent=BomberRules.modes[arenaMode].name;
  document.querySelectorAll('[data-count]').forEach(b=>{b.classList.toggle('active',Number(b.dataset.count)===playerCount);b.setAttribute('aria-pressed',String(Number(b.dataset.count)===playerCount));});
  $('arenaNote').textContent=BomberRules.modes[arenaMode].description;
  document.querySelectorAll('[data-arena]').forEach(b=>{b.classList.toggle('active',b.dataset.arena===arenaMode);b.setAttribute('aria-pressed',String(b.dataset.arena===arenaMode));});
  document.querySelectorAll('[data-mode]').forEach(b=>{b.classList.toggle('active',b.dataset.mode===mode);b.setAttribute('aria-pressed',String(b.dataset.mode===mode));b.disabled=b.dataset.mode==='jev'&&(statusLoading||!available);});
  $('modeNote').textContent=statusLoading?'本地电脑即开即玩，正在读取决策模型设置…':available?(mode==='jev'?'Jev 负责战术选择，本地控制实时移动与躲避。':'无需联网。与本地电脑比拼走位和放弹时机。'):'本地电脑无需联网。使用 Jev 请先在模型设置中选择默认决策模型。';
  $('start').disabled=busy||mode==='jev'&&!available;
  if(!game){AuraiHTML.requestResize();return;}
  const ended=game.phase==='ended',p=game.players[0],seconds=Math.max(0,Math.ceil(BomberRules.modes[game.arenaMode].duration-game.time));
  $('timeLeft').textContent=`${Math.floor(seconds/60)}:${String(seconds%60).padStart(2,'0')}`;
  updateStats();$('matchCount').textContent=`${game.players.length} 人混战`;
  $('overlay').hidden=!paused&&!ended;$('resume').hidden=ended;$('again').hidden=!ended;
  $('overlayTitle').textContent=ended?(game.winner===0?'漂亮，赢下这局！':game.winner!==null?'差一点，再试一次':'势均力敌'): '已暂停';
  $('overlayText').textContent=ended?(game.reason==='score'?game.players.map((p,i)=>`${BomberRules.playerName(game,i)} ${p.score} 分`).join(' · '):game.winner===0?'走位和退路，缺一不可。再来一场？':game.winner!==null?`${BomberRules.playerName(game,game.winner)} 获胜。留意炸弹和缩圈，记得留好退路。`:'这局平分秋色，下局再分胜负。'):'准备好了再继续，炸弹倒计时也停住了。';
  $('pause').disabled=paused||ended;$('bomb').disabled=paused||ended||!Bomber.canBomb(game,0);
  document.querySelectorAll('[data-dir]').forEach(b=>b.disabled=paused||ended||!p.alive);
  updateTactic();
  drawArena($('arena'),game,performance.now());AuraiHTML.requestResize();
}
function updateStats(){
  const p=game.players[0],roster=game.players.map((p,i)=>`${BomberRules.playerName(game,i)}|${p.alive}|${game.arenaMode==='loot'?p.score:''}`).join(';');
  if($('roster').dataset.value!==roster){
    $('roster').dataset.value=roster;$('roster').replaceChildren(...game.players.map((p,i)=>{
      const row=document.createElement('span'),dot=document.createElement('i'),status=document.createElement('small');
      dot.style.background=BomberRules.colors[i];row.classList.toggle('out',!p.alive);
      status.textContent=!p.alive?'已出局':game.arenaMode==='loot'?`${p.score}/20 分`:'存活';row.append(dot,document.createTextNode(BomberRules.playerName(game,i)),status);return row;
    }));
  }
  document.querySelectorAll('[data-dir]').forEach(b=>b.disabled=paused||game.phase==='ended'||!p.alive);
  const entries=[`✦ 火力 ${p.range}`,`+ 弹袋 ${p.capacity}`,`» 加速 ${p.speed}`];
  if(p.shield)entries.push(`◇ 护盾 ${p.shield}`);if(p.glove)entries.push('↗ 推弹');if(p.pierce)entries.push(`⇥ 穿透 ${p.pierce}`);if(p.quick)entries.push(`ϟ 快爆 ${p.quick}`);
  const text=entries.join('|');if($('equipment').dataset.value!==text){$('equipment').dataset.value=text;$('equipment').replaceChildren(...entries.map(value=>{const chip=document.createElement('span');chip.textContent=value;return chip;}));AuraiHTML.requestResize();}
}
function updateTactic(){
  const closing=game.arenaMode==='rush'?[45,65,85].find(at=>at>game.time):null;
  $('tacticLabel').textContent=!game.players[0].alive?'你已出局，正在观战 · 可更换玩法重新开始':closing&&closing-game.time<=5?`${Math.ceil(closing-game.time)} 秒后边缘收紧，向内移动！`:game.mode==='jev'?(request?'Jev 正在观察局面':'Jev · 各自选择战术'):game.arenaMode==='loot'?'炸箱 +1 分 · 拾取道具 +2 分':'放下炸弹后，记得拐弯躲开';
}
async function decide(){
  const ownGeneration=generation,controller=new AbortController();request=controller;lastDecision=game.time;let completed=false;render();
  try{
    const seats=game.players.flatMap((p,i)=>i>0&&p.alive?[i]:[]),questions={};
    for(const i of seats)questions[`robot${i}`]={type:'choice',instructions:`Choose the best tactical intention for ${BomberRules.playerName(game,i)} using robots.robot${i}. This is a free-for-all: every other living player is an opponent. Follow modeRules, survive and pursue opportunities. Local controls handle movement and bomb escapes.`,criteria:{hunt:'Pursue opponents and bomb when safe.',break:'Bomb nearby crates with an escape route.',power:'Collect reachable powerups and points.',retreat:'Create space from opponents without bombing.'}};
    const result=await AuraiHTML.ai.decide({state:{robots:Object.fromEntries(seats.map(i=>[`robot${i}`,Bomber.tactics(game,i)])),arena:game.board,arenaWidth:Bomber.size,
      bombs:game.bombs.map(b=>({x:b.x,y:b.y,range:b.range,piercing:b.pierce,explodesIn:+(b.at-game.time).toFixed(2)})),powerups:game.items,
      nextShrinkIn:game.arenaMode==='rush'?([45,65,85].find(at=>at>game.time)??game.time)-game.time:null,
      legend:'arena: 0 floor, 1 permanent wall, 2 destructible crate; positions are zero-based. Follow modeRules. In loot mode score 1 per crate and 2 per pickup; first to 20 wins. Rush closes outer rings at 45,65,85 seconds. Shields absorb one explosion, not shrinking walls. Piercing bombs pass through crates. Quick bombs have a 1.6-second fuse.'},
      questions}, {signal:controller.signal});
    if(ownGeneration!==generation||result.cancelled)return;
    for(const i of seats)tactics[i]=result.answers[`robot${i}`].choice;completed=true;
  }finally{
    if(ownGeneration===generation){request=null;if(!completed){paused=true;held=null;}render();}
  }
}
function pause(){if(!game||game.phase!=='playing')return;paused=true;cancelDecision();render();void save();}
async function start(){
  cancelDecision();game=Bomber.create(freshSeed(),mode,arenaMode,playerCount);paused=true;tactics=Array(4).fill('retreat');lastDecision=-10;lastSaved=0;busy=true;render();
  try{await save();paused=false;lastFrame=0;accumulator=0;}finally{busy=false;render();}
}
function endRound(){cancelDecision();paused=true;void save();render();}
function move(dir){if(!game||paused)return;Bomber.move(game,0,dir);if(game.phase==='ended')endRound();else drawArena($('arena'),game,performance.now());}
function bomb(){if(game&&!paused&&Bomber.place(game,0)){render();void save();}}
function frame(now){
  const elapsed=lastFrame?Math.min(.12,(now-lastFrame)/1000):0;lastFrame=now;
  if(game&&!paused&&game.phase==='playing'){
    accumulator+=elapsed;
    while(accumulator>=.025){
      accumulator-=.025;if(held!==null)Bomber.move(game,0,held);
      for(let i=1;i<game.players.length;i++)if(game.players[i].alive)Bomber.bot(game,i,game.mode==='local'?Bomber.localTactic(game,i):tactics[i]);Bomber.step(game,.025);
      if(game.phase==='ended'){endRound();break;}
    }
    if(game.phase==='playing'){
      if(game.mode==='jev'&&!request&&game.time-lastDecision>=1.6)void decide();
      if(game.time-lastSaved>=2){lastSaved=game.time;void save();}
      const seconds=Math.max(0,Math.ceil(BomberRules.modes[game.arenaMode].duration-game.time));$('timeLeft').textContent=`${Math.floor(seconds/60)}:${String(seconds%60).padStart(2,'0')}`;
      updateStats();updateTactic();$('bomb').disabled=!Bomber.canBomb(game,0);drawArena($('arena'),game,now);
    }
  }
  requestAnimationFrame(frame);
}
document.querySelectorAll('[data-count]').forEach(b=>b.onclick=()=>{playerCount=Number(b.dataset.count);render();});
document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{mode=b.dataset.mode;render();});
for(const [value,config] of Object.entries(BomberRules.modes)){const b=document.createElement('button');b.type='button';b.dataset.arena=value;b.textContent=config.name;b.onclick=()=>{arenaMode=value;render();};$('arenaModes').append(b);}
for(const item of Object.values(BomberRules.items)){const row=document.createElement('p'),title=document.createElement('strong');title.textContent=`${item.symbol} ${item.name}　`;row.append(title,document.createTextNode(item.description));$('itemGuide').append(row);}
document.querySelectorAll('[data-dir]').forEach(b=>{
  b.onpointerdown=e=>{e.preventDefault();if(b.disabled)return;b.setPointerCapture(e.pointerId);held=Number(b.dataset.dir);b.classList.add('pressed');move(held);};
  const release=()=>{if(held===Number(b.dataset.dir))held=null;b.classList.remove('pressed');};b.onpointerup=release;b.onpointercancel=release;b.onlostpointercapture=release;
});
$('bomb').onclick=bomb;$('pause').onclick=pause;$('start').onclick=start;$('again').onclick=start;
$('resume').onclick=()=>{paused=false;lastFrame=0;accumulator=0;lastDecision=-10;render();};
$('back').onclick=async()=>{pause();game=null;busy=true;render();try{await save();}finally{busy=false;render();}};
const keys={ArrowUp:0,KeyW:0,ArrowRight:1,KeyD:1,ArrowDown:2,KeyS:2,ArrowLeft:3,KeyA:3};
document.addEventListener('keydown',e=>{
  if(!game||e.target.closest('input,textarea,select'))return;
  if(e.code in keys){e.preventDefault();if(!paused){held=keys[e.code];move(held);}}
  if(e.code==='Space'){e.preventDefault();if(!e.repeat)bomb();}
  if(e.code==='Escape')pause();
});
document.addEventListener('keyup',e=>{if(e.code in keys&&held===keys[e.code])held=null;});window.addEventListener('blur',()=>{held=null;});
document.addEventListener('aurai:pause',pause);
document.addEventListener('visibilitychange',()=>{if(document.hidden)pause();});
document.addEventListener('aurai:restore',()=>{cancelDecision();game=readGame();mode=game?game.mode:mode;arenaMode=game?game.arenaMode:arenaMode;playerCount=game?game.players.length:playerCount;paused=true;lastFrame=0;render();});
document.addEventListener('aurai:resume',()=>{lastFrame=0;render();});document.addEventListener('aurai:displaychange',()=>AuraiHTML.requestResize());
async function loadStatus(){try{const status=await AuraiHTML.ai.getDecisionStatus();available=status.available;if(!game&&available)mode='jev';}finally{statusLoading=false;render();}}
render();requestAnimationFrame(frame);void loadStatus();
