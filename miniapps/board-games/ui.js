const $=id=>document.getElementById(id),fullscreen=()=>document.documentElement.dataset.auraiDisplay==='fullscreen';
$('recommend').textContent='提示';
let s=AuraiHTML.messageState,host=s._miniapp,busy=false,pendingAction='',selected=null,pending=null,revision='',roster='',playerDisplay='';
let board=[],deciding=false,decisionAttempt='',paused=false,searchGeneration=0,autoStartAttempted=false,recommending=false,recommendation=null;
const decisionTurn=()=>s.phase==='playing'&&!s.paused&&s.players?.some(p=>p.kind==='engine'&&(s.drawOffer?p.id!==s.drawOffer:p.side===s.turn));
const positionKey=()=>`${s.game}:${s.ply}:${s.drawOffer}:${s.difficulty}:${s.paused}`;
function cancelSearch(){searchGeneration++;LocalEngine.cancel();deciding=false;recommending=false;recommendation=null;}
async function decide(){
  if(deciding||busy||paused||!decisionTurn()||(!me()&&!s.watching))return;
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
const flipped=()=>['xiangqi','halma'].includes(GAME)&&s.mode!=='banqi'&&me()?.side==='b';
const myTurn=()=>!busy&&s.phase==='playing'&&me()?.side===s.turn;
function text(tag,value,cls){const el=document.createElement(tag);el.textContent=value;if(cls)el.className=cls;return el;}
function options(id,members,defaultId){
  const el=$(id),previous=el.value;
  el.replaceChildren(...members.map(m=>{const option=document.createElement('option');option.value=m.id;option.textContent=m.name;return option;}));
  el.value=members.some(m=>m.id===previous)?previous:members.some(m=>m.id===defaultId)?defaultId:members[0]?.id||'';
}
function render(){
  s=AuraiHTML.messageState;host=s._miniapp;
  if(GAME==='xiangqi'){
    Chess=XiangqiModes.get(s.mode===undefined?$('mode').value:s.mode);
    document.documentElement.dataset.xiangqiMode=Chess.mode||'normal';
    document.querySelector('#game h1').textContent=XiangqiModes.labels[Chess.mode||'normal'];
    $('modeField').hidden=!!s.phase&&s.phase!=='setup';$('mode').disabled=!canManage()||busy;
    $('nextModeField').hidden=!s.phase||s.phase==='setup'||(!me()&&!canManage());$('nextMode').disabled=busy;
    if($('nextMode').dataset.game!==String(s.game)){$('nextMode').value=s.mode||'normal';$('nextMode').dataset.game=String(s.game);}
  }
  const nextRevision=`${s.game}:${s.ply}:${s.phase}`;
  if(nextRevision!==revision){revision=nextRevision;selected=null;pending=null;recommendation=null;}
  $('matchTypeField').hidden=!['xiangqi','gomoku'].includes(GAME);
  const setup=!s.phase||s.phase==='setup',playing=!!host&&!setup,own=me(),turn=current();
  $('welcome').hidden=!!host;$('setup').hidden=!host||!setup;$('match').hidden=!playing;
  $('rules').textContent=Chess.rules;
  $('status').textContent=playing?`第 ${s.game} 局 · ${s.ply} 步`:host?'等待开局':'人机对弈';
  if(GAME==='halma'&&s.players)Chess.setSides(s.players.filter(p=>p.active).map(p=>p.side));
  if(host&&setup&&GAME==='halma')renderHalmaSetup();
  if(host&&setup&&GAME!=='halma'){
    const watch=$('matchType').value==='watch',key=JSON.stringify([watch,host.members.map(m=>[m.id,m.name,m.kind])]);
    if(key!==roster){roster=key;options('human',watch?[...host.members.filter(m=>m.kind==='agent'),{id:'engine:local',name:'本地电脑一'}]:host.members.filter(m=>m.kind!=='agent'),watch?'engine:local':host.viewerId);options('ai',[...host.members.filter(m=>m.kind==='agent'),{id:watch?'engine:opponent':'engine:local',name:watch?'本地电脑二':'本地 AI'}],watch?'engine:opponent':'engine:local');}
    $('humanLabel').textContent=watch?'对弈方一':'玩家';$('aiLabel').textContent=watch?'对弈方二':'对手';
    $('first').options[0].textContent=watch?'对弈方一先手':'玩家先手';$('first').options[1].textContent=watch?'对弈方二先手':'对手先手';
    const local=$('ai').value.startsWith('engine:')||$('human').value.startsWith('engine:');
    $('difficultyField').hidden=!local||GAME==='tictactoe';
    $('setupHint').textContent=watch?'选择双方，自动轮流下棋；观战时可以暂停。':!fullscreen()?'点击打开对局，选择对手':!canManage()?'等待发起人选择玩家并开局':local&&$('human').value!==host.viewerId?'与本地 AI 对局时，请选择自己作为玩家':host.independent?(GAME==='tictactoe'?'选择先手，即可离线开局':'选择难度和先手，即可离线开局'):'选择双方和先手即可开局，群里的其他成员可以观战。';
    for(const id of ['human','ai','first','difficulty','matchType'])$(id).disabled=!canManage()||busy;
    $('start').disabled=!canManage()||busy||!$('human').value||!$('ai').value||(!watch&&local&&$('human').value!==host.viewerId)||$('human').value===$('ai').value;

  }
  if(playing){
    const history=host.own?.history??[];
    $('matchDifficultyField').hidden=GAME==='tictactoe'||!s.players.some(p=>p.kind==='engine');
    if(dialogPage!=='Difficulty')$('matchDifficulty').value=String(s.difficulty);$('matchDifficulty').disabled=busy||(!own&&!canManage());
    const codes=Object.fromEntries(Object.entries(s.pieceLegend).map(([code,symbol])=>[symbol,code]));
    board=s.board.flat().map(symbol=>symbol==='·'?null:codes[symbol]);
    const nextPlayerDisplay=JSON.stringify([s.players,s.phase,s.turn,s.firstSide,s.colorsAssigned,(GAME==='reversi'||GAME==='halma')?board:null]);
    if(playerDisplay!==nextPlayerDisplay){playerDisplay=nextPlayerDisplay;$('players').replaceChildren(...(GAME==='halma'?s.players.map(p=>p.side):[Chess.first,Chess.second]).map(side=>{
      const p=s.players.find(p=>p.side===side),el=text('div','','player'+(s.phase==='playing'&&s.turn===side?' active':'')),name=text('div','','name');
      el.setAttribute('aria-label',p.name+(s.phase==='playing'&&s.turn===side?'，等待落子':''));
      const mark=text('span','','side '+(s.colorsAssigned===false?'pending':side));
      if(GAME==='tictactoe'){
        // Draw symmetric marks instead of relying on a font's glyph baseline.
        const symbol=node('svg',{viewBox:'0 0 24 24','aria-hidden':'true',fill:'none',stroke:'currentColor','stroke-width':2.5,'stroke-linecap':'round'},mark);
        if(side==='x')node('path',{d:'M5 5 19 19M19 5 5 19'},symbol);
        else node('circle',{cx:12,cy:12,r:8},symbol);
      }
      el.append(mark);name.append(text('strong',p.name));
      if(GAME==='xiangqi'&&s.mode==='banqi')name.append(text('small',s.colorsAssigned===false?(side===s.turn?'先翻棋':'等待翻棋'):Chess.sides[side]));
      if(GAME==='connect4'||GAME==='gomoku'||GAME==='tictactoe')name.append(text('small',Chess.sides[side]+' · '+(side===s.firstSide?'先手':'后手')));
      if(GAME==='reversi')name.append(text('small',(side===s.firstSide?'先手':'后手')+' · '+board.filter(piece=>piece===side).length+' 子'));
      if(GAME==='halma')name.append(text('small',(p.active?Chess.target(side).filter(i=>board[i]===side).length+' / 10 入营':'已认输')));
      el.append(name);return el;
    }));}
    const winner=s.players.find(p=>p.side===s.winner);
    $('turn').textContent=s.phase==='finished'?(winner?winner.name+'获胜':'和棋')+' · '+s.result:s.inCheck?'将军！':'';
    $('turn').hidden=!$('turn').textContent;
    const last=history.at(-1);
    const drawForMe=!!own&&s.drawOffer&&s.drawOffer!==own.id;
    $('instruction').textContent=s.phase==='finished'?'':s.paused?'对局已暂停':!own?'正在观战':drawForMe?'对手提议和棋，你可以接受或继续对局':s.drawOffer===own.id?'已提出和棋，等待对手回应':GAME==='tictactoe'?(own.side===s.turn?'轮到你 · 点击空格落子':'等待对手落子'):own.side===s.turn&&GAME!=='xiangqi'?(Chess.hint||''):'';
    $('instruction').hidden=!$('instruction').textContent;
    $('undo').disabled=busy||!own||own.kind==='agent'||!s.undoPlayerIds.includes(own.id);
    $('undo').hidden=s.phase==='finished'||!own;$('askAi').hidden=s.phase==='finished'||s.paused||own?.side===s.turn;
    $('rematch').hidden=(!own&&!(s.watching&&canManage()))||s.phase!=='finished';$('resign').hidden=!own||s.phase!=='playing'||own.active===false;
    $('offerDraw').disabled=busy||!!s.drawOffer;
    for(const id of ['askAi','rematch','resign'])$(id).disabled=busy;
    $('askAi').disabled=busy||deciding||(!own&&!(s.watching&&canManage()))||own?.kind==='agent'||s.paused||s.phase!=='playing'||(!decisionTurn()&&turn.kind!=='agent');
    $('askAi').setAttribute('aria-busy',String(pendingAction==='requestAi'||deciding));
    $('askAi').title=['agent','engine'].includes(turn.kind)?'请对手继续落子':'轮到你了，请在棋盘落子';
    $('emptyHistory').hidden=history.length>0;
    $('history').start=s.ply-history.length+1;
    $('history').replaceChildren(...history.map(m=>text('li',`${s.players.find(p=>p.id===m.actorId).name}：${m.text}`)));
    $('watchPause').hidden=GAME==='halma'||!s.watching||!canManage()||s.phase!=='playing';
    $('watchPause').textContent=s.paused?'继续':'暂停';$('watchPause').disabled=busy;
    $('recommend').hidden=s.phase!=='playing'||!own;
    $('recommend').disabled=busy||deciding||recommending||!myTurn();
    $('recommend').setAttribute('aria-busy',String(recommending));
    $('recommendation').hidden=!recommendation;
    $('recommendation').textContent=recommendation?'建议：'+(recommendation.from?Chess.coordinate(recommendation.from)+' → ':'')+Chess.coordinate(recommendation.to):'';
    drawBoard(board,selected,pending||recommendation,s.legalMoves,last,s.winningLine,flipped());
  } else {
    // A fresh inline launch card still shows the board instead of an empty form.
    $('board').replaceChildren();
    if(!fullscreen()){
      $('match').hidden=false;$('players').replaceChildren();playerDisplay='';$('turn').hidden=false;$('turn').textContent='邀请 AI，一起下棋';
      drawBoard(Chess.initial(),null,null,[],null,[],false);
    }
  }
  syncGameDialogs();
  AuraiHTML.requestResize();
  if(!busy&&!deciding&&!recommending&&!paused)queueMicrotask(autoDecide);
}
async function recommend(){
  if(!myTurn()||deciding||recommending)return;
  const generation=++searchGeneration,key=positionKey();
  recommending=true;recommendation=null;render();
  try{
    const move=await LocalEngine.search({...s,difficulty:5});
    if(generation!==searchGeneration||key!==positionKey()||move===null)return;
    recommendation=move;
    selected=move.from||null;pending=null;
  }finally{if(generation===searchGeneration){recommending=false;render();}}
}
$('recommend').onclick=recommend;
async function submit(action,data={}){
  if(busy)return;cancelSearch();busy=true;pendingAction=action;render();
  try{await AuraiHTML.boardGame('event',{eventId:crypto.randomUUID(),action,data:action==='configure'?data:{game:s.game,ply:s.ply,...data},notifyAi:false});decisionAttempt='';}
  finally{busy=false;pendingAction='';render();}
}
$('setup').onsubmit=event=>{event.preventDefault();void submit('configure',GAME==='halma'?halmaSetup():{humanId:$('human').value,aiId:$('ai').value,humanFirst:$('first').value==='human',difficulty:Number($('difficulty').value),watching:$('matchType').value==='watch',...(GAME==='xiangqi'?{mode:$('mode').value}:{})});};
$('board').onclick=event=>{
  if(!myTurn())return;const p=boardPoint(event,flipped());if(!p)return;
  if(GAME==='xiangqi'&&s.mode==='banqi'&&board[p[1]*Chess.width+p[0]]==='uD'){
    const move=s.legalMoves.find(m=>!m.from&&m.to[0]===p[0]&&m.to[1]===p[1]);if(move)void submit('move',move);return;
  }
  if(GAME==='xiangqi'||Chess.moving){
    const piece=board[p[1]*Chess.width+p[0]];
    if(piece&&piece[0]===s.turn){selected=selected?.[0]===p[0]&&selected?.[1]===p[1]?null:p;pending=null;}
    else if(selected){pending=s.legalMoves.find(m=>m.from&&m.from[0]===selected[0]&&m.from[1]===selected[1]&&m.to[0]===p[0]&&m.to[1]===p[1])||null;if(pending){void submit('move',pending);return;}}
  } else {pending=s.legalMoves.find(m=>m.to[0]===p[0]&&(GAME==='connect4'||m.to[1]===p[1]))||null;if(pending){void submit('move',pending);return;}}
  render();
};
$('undo').onclick=()=>submit('undo');
$('askAi').onclick=()=>decisionTurn()?decide():submit('requestAi');
initGameDialogs();
$('ai').onchange=render;$('human').onchange=render;
$('mode').onchange=render;$('matchType').onchange=render;
$('watchPause').onclick=()=>submit(s.paused?'resume':'pause');
document.addEventListener('aurai:pause',()=>{paused=true;cancelSearch();});
document.addEventListener('aurai:resume',()=>{paused=false;decisionAttempt='';render();});
document.addEventListener('aurai:restore',render);
document.addEventListener('aurai:messageupdate',()=>{const next=AuraiHTML.messageState;if(next.game!==s.game||next.ply!==s.ply||next.phase!==s.phase||next.difficulty!==s.difficulty||next.drawOffer!==s.drawOffer||next.paused!==s.paused)cancelSearch();render();});
document.addEventListener('aurai:displaychange',()=>{if(!fullscreen()){cancelSearch();closeGameDialog();}decisionAttempt='';render();});render();
