const $=id=>document.getElementById(id),fullscreen=()=>document.documentElement.dataset.auraiDisplay==='fullscreen';
let s=AuraiHTML.messageState,host=s._miniapp,busy=false,pendingAction='',selected=null,pending=null,revision='',roster='',playerDisplay='';
let board=[],deciding=false,decisionAttempt='',paused=false,searchGeneration=0,autoStartAttempted=false;
const decisionTurn=()=>s.phase==='playing'&&s.players?.some(p=>p.kind==='engine'&&(p.side===s.turn||s.drawOffer===host?.viewerId));
const positionKey=()=>`${s.game}:${s.ply}:${s.drawOffer}:${s.difficulty}`;
function cancelSearch(){searchGeneration++;LocalEngine.cancel();deciding=false;}
async function decide(){
  if(deciding||busy||paused||!decisionTurn()||!me())return;
  const generation=++searchGeneration;decisionAttempt=positionKey();deciding=true;render();
  try{
    const job=await AuraiHTML.boardGame('begin');
    if(generation!==searchGeneration||job.skipped)return;
    const view=job.view,draw=!!view.drawOffer;
    // A local engine accepts a mutual draw rather than inventing a model judgement.
    const move=draw?{accept:true}:await LocalEngine.search(view);
    if(generation!==searchGeneration||move===null)return;
    await AuraiHTML.boardGame('complete',{token:job.token,version:job.version,action:draw?'answerDraw':'move',data:{game:view.game,ply:view.ply,...move}});
  }finally{if(generation===searchGeneration){deciding=false;render();}}
}
function autoDecide(){
  if(GAME==='tictactoe'&&host?.independent&&fullscreen()&&!s.phase&&!autoStartAttempted&&!busy&&!paused){
    autoStartAttempted=true;
    void submit('configure',{humanId:host.viewerId,aiId:'engine:local',humanFirst:true,difficulty:3});
    return;
  }
  if(decisionTurn()&&decisionAttempt!==positionKey())void decide();
}

const canManage=()=>host&&(host.viewerId===host.ownerId||host.viewerId==='user:local');
const me=()=>s.players?.find(p=>p.id===host?.viewerId);
const current=()=>s.players?.find(p=>p.side===s.turn);
const flipped=()=>GAME==='xiangqi'&&me()?.side==='b';
const myTurn=()=>!busy&&s.phase==='playing'&&me()?.side===s.turn;
function text(tag,value,cls){const el=document.createElement(tag);el.textContent=value;if(cls)el.className=cls;return el;}
function options(id,members,defaultId){
  const el=$(id),previous=el.value;
  el.replaceChildren(...members.map(m=>{const option=document.createElement('option');option.value=m.id;option.textContent=m.name;return option;}));
  el.value=members.some(m=>m.id===previous)?previous:members.some(m=>m.id===defaultId)?defaultId:members[0]?.id||'';
}
function render(){
  s=AuraiHTML.messageState;host=s._miniapp;
  const nextRevision=`${s.game}:${s.ply}:${s.phase}`;
  if(nextRevision!==revision){revision=nextRevision;selected=null;pending=null;$('resignActions').hidden=true;}
  const setup=!s.phase||s.phase==='setup',playing=!!host&&!setup,own=me(),turn=current();
  $('welcome').hidden=!!host;$('setup').hidden=!host||!setup;$('match').hidden=!playing;
  $('rules').textContent=Chess.rules;
  $('status').textContent=playing?`第 ${s.game} 局 · ${s.ply} 步`:host?'等待开局':'人机对弈';
  if(host&&setup){
    const key=JSON.stringify(host.members.map(m=>[m.id,m.name,m.kind]));
    if(key!==roster){roster=key;options('human',host.members.filter(m=>m.kind!=='agent'),host.viewerId);options('ai',[...host.members.filter(m=>m.kind==='agent'),{id:'engine:local',name:'本地 AI'}],'engine:local');}
    const local=$('ai').value==='engine:local';
    $('difficultyField').hidden=!local||GAME==='tictactoe';
    $('setupHint').textContent=!fullscreen()?'点击打开对局，选择对手':!canManage()?'等待发起人选择玩家并开局':local&&$('human').value!==host.viewerId?'与本地 AI 对局时，请选择自己作为玩家':host.independent?(GAME==='tictactoe'?'选择先手，即可离线开局':'选择难度和先手，即可离线开局'):'选择双方和先手即可开局，群里的其他成员可以观战。';
    for(const id of ['human','ai','first','difficulty'])$(id).disabled=!canManage()||busy;
    $('start').disabled=!canManage()||busy||!$('human').value||!$('ai').value||(local&&$('human').value!==host.viewerId);

  }
  if(playing){
    const history=host.own?.history??[];
    $('matchDifficultyField').hidden=GAME==='tictactoe'||!s.players.some(p=>p.kind==='engine');
    $('matchDifficulty').value=String(s.difficulty);$('matchDifficulty').disabled=busy||!own;
    const codes=Object.fromEntries(Object.entries(s.pieceLegend).map(([code,symbol])=>[symbol,code]));
    board=s.board.flat().map(symbol=>symbol==='·'?null:codes[symbol]);
    const nextPlayerDisplay=JSON.stringify([s.players,s.phase,s.turn,(GAME==='reversi'||GAME==='halma')?board:null]);
    if(playerDisplay!==nextPlayerDisplay){playerDisplay=nextPlayerDisplay;$('players').replaceChildren(...[Chess.first,Chess.second].map(side=>{
      const p=s.players.find(p=>p.side===side),el=text('div','','player'+(s.phase==='playing'&&s.turn===side?' active':'')),name=text('div','','name');
      el.setAttribute('aria-label',p.name+(s.phase==='playing'&&s.turn===side?'，等待落子':''));
      el.append(text('span',GAME==='tictactoe'?(side==='x'?'×':'○'):'','side '+side));name.append(text('strong',p.name));
      if(GAME==='reversi')name.append(text('small',board.filter(piece=>piece===side).length+' 子'));
      if(GAME==='halma')name.append(text('small',Chess.camps[side==='b'?'w':'b'].filter(i=>board[i]===side).length+' / 10 入营'));
      el.append(name);return el;
    }));}
    const winner=s.players.find(p=>p.side===s.winner);
    $('turn').textContent=s.phase==='finished'?(winner?winner.name+'获胜':'和棋')+' · '+s.result:s.inCheck?'将军！':'';
    $('turn').hidden=!$('turn').textContent;
    const last=history.at(-1);
    const drawForMe=!!own&&s.drawOffer&&s.drawOffer!==own.id;
    $('instruction').textContent=s.phase==='finished'?'':!own?'正在观战':drawForMe?'对手提议和棋，你可以接受或继续对局':s.drawOffer===own.id?'已提出和棋，等待对手回应':GAME==='tictactoe'?(own.side===s.turn?'轮到你 · 点击空格落子':'等待对手落子'):own.side===s.turn?(GAME==='xiangqi'?'先选棋子，再选择绿色提示的落点':Chess.hint||''):'';
    $('instruction').hidden=!$('instruction').textContent;
    $('undo').disabled=busy||!own||own.kind==='agent'||!s.undoPlayerIds.includes(own.id);
    $('undo').hidden=s.phase==='finished';$('askAi').hidden=s.phase==='finished';
    $('drawActions').hidden=!drawForMe||s.phase!=='playing';
    $('rematch').hidden=!own||s.phase!=='finished';$('gameActions').hidden=!own||s.phase!=='playing';
    $('offerDraw').disabled=busy||!!s.drawOffer;
    for(const id of ['acceptDraw','declineDraw','askAi','rematch','resign','confirmResign'])$(id).disabled=busy;
    $('askAi').disabled=busy||deciding||!own||own.kind==='agent'||s.phase!=='playing'||(!decisionTurn()&&turn.kind!=='agent');
    $('askAi').setAttribute('aria-busy',String(pendingAction==='requestAi'||deciding));
    $('askAi').title=['agent','engine'].includes(turn.kind)?'请对手继续落子':'轮到你了，请在棋盘落子';
    $('emptyHistory').hidden=history.length>0;
    $('history').start=s.ply-history.length+1;
    $('history').replaceChildren(...history.map(m=>text('li',`${s.players.find(p=>p.id===m.actorId).name}：${m.text}`)));
    drawBoard(board,selected,pending,s.legalMoves,last,s.winningLine,flipped());
  } else {
    // A fresh inline launch card still shows the board instead of an empty form.
    $('board').replaceChildren();
    if(!fullscreen()){
      $('match').hidden=false;$('players').replaceChildren();playerDisplay='';$('turn').hidden=false;$('turn').textContent='邀请 AI，一起下棋';
      drawBoard(Chess.initial(),null,null,[],null,[],false);
    }
  }
  AuraiHTML.requestResize();
  if(!busy&&!deciding&&!paused)queueMicrotask(autoDecide);
}
async function submit(action,data={}){
  if(busy)return;cancelSearch();busy=true;pendingAction=action;render();
  try{await AuraiHTML.boardGame('event',{eventId:crypto.randomUUID(),action,data:action==='configure'?data:{game:s.game,ply:s.ply,...data},notifyAi:false});decisionAttempt='';showMore(false);}
  finally{busy=false;pendingAction='';render();}
}
$('setup').onsubmit=event=>{event.preventDefault();void submit('configure',{humanId:$('human').value,aiId:$('ai').value,humanFirst:$('first').value==='human',difficulty:Number($('difficulty').value)});};
$('board').onclick=event=>{
  if(!myTurn())return;const p=boardPoint(event,flipped());if(!p)return;
  if(GAME==='xiangqi'||Chess.moving){
    const piece=board[p[1]*Chess.width+p[0]];
    if(piece&&piece[0]===s.turn){selected=selected?.[0]===p[0]&&selected?.[1]===p[1]?null:p;pending=null;}
    else if(selected){pending=s.legalMoves.find(m=>m.from[0]===selected[0]&&m.from[1]===selected[1]&&m.to[0]===p[0]&&m.to[1]===p[1])||null;if(pending){void submit('move',pending);return;}}
  } else {pending=s.legalMoves.find(m=>m.to[0]===p[0]&&(GAME==='connect4'||m.to[1]===p[1]))||null;if(pending){void submit('move',pending);return;}}
  render();
};
$('undo').onclick=()=>submit('undo');
function showMore(open){$('morePanel').hidden=!open;$('more').setAttribute('aria-expanded',String(open));if(!open)$('resignActions').hidden=true;}
$('more').onclick=()=>showMore($('morePanel').hidden);$('closeMore').onclick=()=>showMore(false);
document.addEventListener('keydown',event=>{if(event.key==='Escape')showMore(false);});
$('askAi').onclick=()=>decisionTurn()?decide():submit('requestAi');$('rematch').onclick=()=>submit('rematch');$('offerDraw').onclick=()=>submit('offerDraw');
$('acceptDraw').onclick=()=>submit('answerDraw',{accept:true});$('declineDraw').onclick=()=>submit('answerDraw',{accept:false});
$('resign').onclick=()=>{$('resignActions').hidden=false;};$('cancelResign').onclick=()=>{$('resignActions').hidden=true;};$('confirmResign').onclick=()=>submit('resign');
$('matchDifficulty').onchange=()=>submit('difficulty',{level:Number($('matchDifficulty').value)});
$('ai').onchange=render;$('human').onchange=render;
document.addEventListener('aurai:pause',()=>{paused=true;cancelSearch();});
document.addEventListener('aurai:resume',()=>{paused=false;decisionAttempt='';render();});
document.addEventListener('aurai:restore',render);
document.addEventListener('aurai:messageupdate',()=>{const next=AuraiHTML.messageState;if(next.game!==s.game||next.ply!==s.ply||next.phase!==s.phase||next.difficulty!==s.difficulty||next.drawOffer!==s.drawOffer)cancelSearch();render();});
document.addEventListener('aurai:displaychange',()=>{if(!fullscreen())cancelSearch();decisionAttempt='';render();});render();
