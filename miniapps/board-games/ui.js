const $=id=>document.getElementById(id),fullscreen=()=>document.documentElement.dataset.auraiDisplay==='fullscreen';
let s=AuraiHTML.messageState,host=s._miniapp,busy=false,pendingAction='',selected=null,pending=null,revision='',roster='',playerDisplay='';
let board=[];
const canManage=()=>host&&(host.viewerId===host.ownerId||host.viewerId==='user:local');
const me=()=>s.players?.find(p=>p.id===host?.viewerId);
const current=()=>s.players?.find(p=>p.side===s.turn);
const flipped=()=>GAME==='xiangqi'&&me()?.side==='b';
const myTurn=()=>fullscreen()&&!busy&&s.phase==='playing'&&me()?.side===s.turn;
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
    if(key!==roster){roster=key;options('human',host.members.filter(m=>m.kind!=='agent'),host.viewerId);options('ai',host.members.filter(m=>m.kind==='agent'),host.ownerId);}
    $('setupHint').textContent=!fullscreen()?'点击打开对局，选择 AI 对手':!canManage()?'等待发起人选择玩家并开局':!$('ai').value?'请先在聊天中添加一位 AI，再开始对局':'选好双方和先手即可开局，群里的其他成员可以观战。';
    for(const id of ['human','ai','first'])$(id).disabled=!canManage()||busy;
    $('start').disabled=!canManage()||busy||!$('human').value||!$('ai').value;
  }
  if(playing){
    const history=host.own?.history??[];
    const codes=Object.fromEntries(Object.entries(s.pieceLegend).map(([code,symbol])=>[symbol,code]));
    board=s.board.flat().map(symbol=>symbol==='·'?null:codes[symbol]);
    const nextPlayerDisplay=JSON.stringify([s.players,s.phase,s.turn]);
    if(playerDisplay!==nextPlayerDisplay){playerDisplay=nextPlayerDisplay;$('players').replaceChildren(...[Chess.first,Chess.second].map(side=>{
      const p=s.players.find(p=>p.side===side),el=text('div','','player'+(s.phase==='playing'&&s.turn===side?' active':'')),name=text('div','','name');
      el.setAttribute('aria-label',p.name+(s.phase==='playing'&&s.turn===side?'，等待落子':''));
      el.append(text('span','','side '+side));name.append(text('strong',p.name));el.append(name);return el;
    }));}
    const winner=s.players.find(p=>p.side===s.winner);
    $('turn').textContent=s.phase==='finished'?(winner?winner.name+'获胜':'和棋')+' · '+s.result:s.inCheck?'将军！':'';
    $('turn').hidden=!$('turn').textContent;
    const last=history.at(-1);
    const drawForMe=!!own&&s.drawOffer&&s.drawOffer!==own.id;
    $('instruction').textContent=s.phase==='finished'?(own?'可在更多中交换先手，再来一局':''):!own?'正在观战':drawForMe?'对手提议和棋，你可以接受或继续对局':s.drawOffer===own.id?'已提出和棋，等待对手回应':own.side===s.turn&&GAME==='xiangqi'?'先选棋子，再选择绿色提示的落点':'';
    $('instruction').hidden=!$('instruction').textContent;
    $('undo').disabled=busy||!own||own.kind==='agent'||!s.undoPlayerIds.includes(own.id);
    $('drawActions').hidden=!drawForMe||s.phase!=='playing';
    $('rematch').hidden=!own||s.phase!=='finished';$('gameActions').hidden=!own||s.phase!=='playing';
    $('offerDraw').disabled=busy||!!s.drawOffer;
    for(const id of ['acceptDraw','declineDraw','askAi','rematch','resign','confirmResign'])$(id).disabled=busy;
    $('askAi').disabled=busy||!own||own.kind==='agent'||s.phase!=='playing'||turn.kind!=='agent';
    $('askAi').setAttribute('aria-busy',String(pendingAction==='requestAi'));
    $('askAi').title=s.phase==='finished'?'本局已结束，可在更多中再来一局':turn.kind==='agent'?'请 AI 继续落子':'轮到你了，请在棋盘落子';
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
}
async function submit(action,data={}){
  if(busy)return;busy=true;pendingAction=action;render();
  try{await AuraiHTML.submitEvent({eventId:crypto.randomUUID(),action,data:action==='configure'?data:{game:s.game,ply:s.ply,...data},notifyAi:false});showMore(false);}
  finally{busy=false;pendingAction='';render();}
}
$('setup').onsubmit=event=>{event.preventDefault();void submit('configure',{humanId:$('human').value,aiId:$('ai').value,humanFirst:$('first').value==='human'});};
$('board').onclick=event=>{
  if(!myTurn())return;const p=boardPoint(event,flipped());if(!p)return;
  if(GAME==='xiangqi'){
    const piece=board[p[1]*Chess.width+p[0]];
    if(piece&&piece[0]===s.turn){selected=selected?.[0]===p[0]&&selected?.[1]===p[1]?null:p;pending=null;}
    else if(selected){pending=s.legalMoves.find(m=>m.from[0]===selected[0]&&m.from[1]===selected[1]&&m.to[0]===p[0]&&m.to[1]===p[1])||null;if(pending){void submit('move',pending);return;}}
  } else {pending=s.legalMoves.find(m=>m.to[0]===p[0]&&m.to[1]===p[1])||null;if(pending){void submit('move',pending);return;}}
  render();
};
$('undo').onclick=()=>submit('undo');
function showMore(open){$('morePanel').hidden=!open;$('more').setAttribute('aria-expanded',String(open));if(!open)$('resignActions').hidden=true;}
$('more').onclick=()=>showMore($('morePanel').hidden);$('closeMore').onclick=()=>showMore(false);
document.addEventListener('keydown',event=>{if(event.key==='Escape')showMore(false);});
$('askAi').onclick=()=>submit('requestAi');$('rematch').onclick=()=>submit('rematch');$('offerDraw').onclick=()=>submit('offerDraw');
$('acceptDraw').onclick=()=>submit('answerDraw',{accept:true});$('declineDraw').onclick=()=>submit('answerDraw',{accept:false});
$('resign').onclick=()=>{$('resignActions').hidden=false;};$('cancelResign').onclick=()=>{$('resignActions').hidden=true;};$('confirmResign').onclick=()=>submit('resign');
document.addEventListener('aurai:messageupdate',render);document.addEventListener('aurai:displaychange',render);render();
