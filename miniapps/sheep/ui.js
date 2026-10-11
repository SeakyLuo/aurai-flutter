const $=id=>document.getElementById(id),el=(tag,text,cls)=>{const n=document.createElement(tag);n.textContent=text;if(cls)n.className=cls;return n;};
let game=AuraiHTML.state?.game??null,level=game?game.level:0,busy=false,hinting=false,hinted=null,worker=null,cancelHint=null,confirmation=null;
const seed=()=>crypto.getRandomValues(new Uint32Array(1))[0];
function stopHint(){if(worker){worker.terminate();worker=null;}if(cancelHint){cancelHint({status:'cancelled'});cancelHint=null;}hinting=false;hinted=null;}
function render(){
  $('welcome').hidden=!!game;$('match').hidden=!game;$('levelName').textContent=Sheep.levels[level].name;
  $('levels').replaceChildren(...Sheep.levels.map((config,index)=>{const b=el('button',config.name,index===level?'active':'');b.type='button';b.setAttribute('aria-pressed',String(index===level));b.onclick=()=>{level=index;render();};return b;}));
  $('start').disabled=busy;
  if(game){
    const gone=new Set(game.removed),available=new Set(Sheep.available(game).map(t=>t.id));
    $('progressLabel').textContent=`已消除 ${game.removed.length-game.tray.length} / ${game.tiles.length}`;
    $('moveLabel').textContent=`${game.history.length} 步`;$('progress').style.width=((game.removed.length-game.tray.length)/game.tiles.length*100)+'%';
    $('board').replaceChildren(...game.tiles.filter(t=>!gone.has(t.id)).map(tile=>{
      const open=available.has(tile.id),b=el('button',Sheep.symbols[tile.type],'sheep-tile'+(open?'':' covered')+(hinted===tile.id?' hinted':''));
      b.type='button';b.style.left=tile.x/8*100+'%';b.style.top=tile.y/7.1*100+'%';b.style.zIndex=tile.z*100+tile.id;
      b.disabled=busy||hinting||!open||game.phase!=='playing';b.setAttribute('aria-label',Sheep.symbols[tile.type]+(open?'，可选择':'，被遮挡'));b.dataset.tile=tile.id;b.onclick=()=>play(tile.id);return b;
    }));
    $('tray').replaceChildren(...Array.from({length:7},(_,i)=>el('div',i<game.tray.length?Sheep.symbols[game.tiles[game.tray[i]].type]:'','tray-slot'+(i<game.tray.length?' filled':''))));
    $('tray').classList.toggle('danger',game.tray.length>=5);$('trayLabel').textContent=`${game.tray.length} / 7`;
    $('instruction').textContent=game.phase==='playing'?(hinting?'寻找通关走法…':hinted!==null?'发光的这张，可以通向过关':game.tray.length>=5?'收集槽快满了，优先凑齐已有图案':'三张相同就消除，灰暗的牌还被遮挡'):'';
    $('result').hidden=game.phase==='playing';$('resultSymbol').textContent=game.phase==='won'?'🐑':'🌿';
    $('resultTitle').textContent=game.phase==='won'?'恭喜，羊羊回家了':'先歇一小会儿';
    $('resultText').textContent=game.phase==='won'?(level===Sheep.levels.length-1?'山顶挑战完成，可以换一副牌继续挑战。':`已清空 ${game.tiles.length} 张牌，下一关见。`):'收集槽满了。可以撤回几步，或者用同一副牌再试一次。';
    $('next').textContent=level===Sheep.levels.length-1?'再次挑战':'下一关';
    $('next').hidden=game.phase!=='won';$('next').disabled=busy;
    $('undo').disabled=busy||hinting||!game.history.length;$('hint').disabled=busy||hinting||game.phase!=='playing';$('retry').disabled=busy||hinting||!game.history.length;$('new').disabled=busy||hinting;
  }
  AuraiHTML.requestResize();
}
async function commit(next){game=next;render();await AuraiHTML.saveState({game});}
async function play(id){
  if(busy)return;stopHint();
  const from=document.querySelector(`[data-tile="${id}"]`).getBoundingClientRect(),type=game.tiles[id].type,oldTray=game.tray.length;
  const next=Sheep.move(structuredClone(game),id);busy=true;
  try{
    await commit(next);
    if(next.tray.length<oldTray){$('tray').classList.remove('cleared');void $('tray').offsetWidth;$('tray').classList.add('cleared');}
    if(!matchMedia('(prefers-reduced-motion: reduce)').matches){
      const target=$('tray').children[Math.min(next.tray.findIndex(t=>t===id)<0?oldTray:next.tray.indexOf(id),6)].getBoundingClientRect();
      const ghost=el('div',Sheep.symbols[type],'sheep-ghost');Object.assign(ghost.style,{left:from.left+'px',top:from.top+'px',width:from.width+'px',height:from.height+'px'});document.body.append(ghost);
      const a=ghost.animate([{transform:'translate(0,0)',opacity:1},{transform:`translate(${target.left-from.left}px,${target.top-from.top}px) scale(.9)`,opacity:0}],{duration:220,easing:'ease-out'});a.onfinish=()=>ghost.remove();
    }
  }finally{busy=false;render();}
}
async function newGame(nextLevel=level,same=false){stopHint();$('confirm').hidden=true;confirmation=null;level=nextLevel;busy=true;try{await commit(same?{...structuredClone(game),removed:[],tray:[],history:[],phase:'playing'}:Sheep.deal(level,seed()));}finally{busy=false;render();}}
function confirm(action,text){confirmation=action;$('confirmText').textContent=text;$('confirm').hidden=false;AuraiHTML.requestResize();}
$('start').onclick=()=>newGame();$('next').onclick=()=>newGame(Math.min(level+1,Sheep.levels.length-1));
$('undo').onclick=async()=>{stopHint();busy=true;try{await commit(Sheep.undo(structuredClone(game)));}finally{busy=false;render();}};
$('retry').onclick=()=>confirm(()=>newGame(level,true),'用这副牌重新开始？当前走牌进度会清空。');
$('new').onclick=()=>confirm(async()=>{stopHint();$('confirm').hidden=true;busy=true;try{await commit(null);}finally{busy=false;render();}},'返回关卡选择？当前进度会被替换。');
$('confirmNo').onclick=()=>{$('confirm').hidden=true;confirmation=null;AuraiHTML.requestResize();};$('confirmYes').onclick=()=>{const action=confirmation;confirmation=null;$('confirm').hidden=true;void action();};
$('hint').onclick=async()=>{
  stopHint();hinting=true;render();
  const url=URL.createObjectURL(new Blob([JSON.parse($('sheepHintSource').textContent)],{type:'text/javascript'}));worker=new Worker(url);URL.revokeObjectURL(url);
  try{
    const result=await new Promise((resolve,reject)=>{cancelHint=resolve;worker.onmessage=e=>resolve(e.data);worker.onerror=e=>{e.preventDefault();reject(Error(e.message));};worker.postMessage(game);});
    if(result.status==='cancelled')return;
    if(result.status!=='solved')throw Error(result.status==='deadend'?'这个走牌顺序已无法通关，撤回几步再试试':'暂未找到通关走法，可以撤回几步或同关重来');hinted=result.move;
  }finally{if(worker){worker.terminate();worker=null;}cancelHint=null;hinting=false;render();}
};
document.addEventListener('aurai:restore',()=>{stopHint();game=AuraiHTML.state?.game??null;level=game?game.level:level;render();});
document.addEventListener('aurai:pause',stopHint);
document.addEventListener('aurai:resume',render);document.addEventListener('aurai:displaychange',()=>AuraiHTML.requestResize());
render();
