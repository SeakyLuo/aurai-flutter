var s=ctx.state,e=ctx.event,d=e.data,members=ctx.members;
if(GAME==='xiangqi'){
  Chess=XiangqiModes.get(e.action==='configure'?(d.mode===undefined?'normal':d.mode):(s.mode===undefined?'normal':s.mode));
  s.mode=Chess.mode||'normal';
}
function require(ok,message) { if (!ok) throw new Error(message); }
function member(id) { if(id==='engine:local'||id==='engine:opponent')return {id:id,name:id==='engine:local'?'本地电脑一':'本地电脑二',kind:'engine'}; return members.find(function(m){return m.id===id;}); }
function manager() { return e.actorId===ctx.ownerId||e.actorId==='user:local'; }
function player(color) { return s.players.find(function(p){return p.side===color;}); }
function finished(winner,reason) { s.phase='finished'; s.winner=winner; s.result=reason; }
function position() { return s.turn+':'+s.board.map(function(p){return p||'.';}).join(','); }
function legalMoves() { return Chess.allowed?Chess.allowed(s):Chess.legal(s.board,s.turn); }
var fixedColors=GAME==='connect4'||GAME==='gomoku'||GAME==='tictactoe'||GAME==='reversi';
function otherSide(side) { return side===Chess.first?Chess.second:Chess.first; }
// These games alternate every move, so the opening side is derived from the
// live turn and ply. Undo and rematch must not confuse color with move order.
function openingSide() {
  if(GAME==='xiangqi'&&s.mode==='banqi')return s.history.length?s.history[0].side:s.turn;
  // Reversi can pass a turn, so ply parity cannot recover its opening color.
  if(GAME==='reversi')return s.history.length?s.history[0].side:s.turn;
  return fixedColors&&s.ply%2===1?otherSide(s.turn):fixedColors?s.turn:Chess.first;
}
function person(p) { if(p.kind==='engine')return p.name.replace(/[\\\[\]*_`]/g,'\\$&'); return '['+p.name.replace(/[\\\[\]]/g,'\\$&')+'](aurai://member/'+encodeURIComponent(p.id)+')'; }
function start(human,ai,humanFirst,game,difficulty,color) {
  var humanSide=fixedColors?color:humanFirst?Chess.first:Chess.second;
  s={phase:'playing',game:game,difficulty:difficulty,board:Chess.initial(),turn:fixedColors?(humanFirst?humanSide:otherSide(humanSide)):Chess.first,ply:0,quiet:0,history:[],positions:{},winner:null,result:'',winningLine:[],drawOffer:null,
    paused:false,players:[{id:human.id,name:human.name,kind:human.kind,side:humanSide},{id:ai.id,name:ai.name,kind:ai.kind,side:otherSide(humanSide)}]};
  if(GAME==='xiangqi')s.mode=Chess.mode||'normal';
  if(Chess.initialize)Chess.initialize(s);
  s.positions[position()]=1;
}
function notify(text,wake) {
  var args={text:text,markdown:true};
  if (wake) {
    var ai=s.drawOffer?s.players.find(function(p){return p.id!==s.drawOffer&&p.kind==='agent';}):player(s.turn);
    args.audience=members.map(function(m){return m.id;});args.wakeAi=true;args.wakeMemberIds=[ai.id];
  }
  host.call('messages.send',args);
}
if (e.action==='configure') {
  require(manager(),'只有发起人可以配置对局');require(!s.phase,'本局已经创建');
  var human=member(d.humanId),ai=member(d.aiId);
  var watching=d.watching===true;
  require(!watching||GAME==='xiangqi'||GAME==='gomoku','此棋类暂不支持观战开局');
  require(human&&(watching?(human.kind==='agent'||human.kind==='engine'):human.kind!=='agent'&&human.kind!=='engine'),'请选择当前聊天中的玩家');require(ai&&(ai.kind==='agent'||ai.kind==='engine'),'请选择对手');
  require(human.id!==ai.id,'请选择两个不同的对手');
  if(ai.kind==='engine'||human.kind==='engine')require(e.actorId==='user:local'&&(watching||human.id==='user:local'),'请由本地用户开启电脑对局');
  require(typeof d.humanFirst==='boolean','请选择先手');
  var difficulty=d.difficulty===undefined?3:d.difficulty;
  require(Number.isInteger(difficulty)&&difficulty>=1&&difficulty<=5,'请选择有效难度');
  start(human,ai,d.humanFirst,1,difficulty,fixedColors?(Math.random()<.5?Chess.first:Chess.second):null);
  // The AI configuring its own first move is already running; do not wake it twice.
  notify(person(player(s.turn))+(s.mode==='banqi'?'先翻棋，首次翻子决定颜色':'执'+Chess.sides[s.turn]+'先行'),player(s.turn).kind==='agent'&&player(s.turn).id!==e.actorId);
} else {
  require(s.phase==='playing'||s.phase==='finished','请先创建对局');
  require(d.game===s.game&&d.ply===s.ply,'棋盘已变化，请查看最新棋盘再操作');
  var actor=s.players.find(function(p){return p.id===e.actorId;});
  if(ctx.decision===true){require(e.actorId==='user:local','引擎只能由本地玩家执行');actor=s.players.find(function(p){return p.kind==='engine'&&(s.drawOffer?p.id!==s.drawOffer:p.side===s.turn);});}
  var watching=s.players.every(function(p){return p.kind==='agent'||p.kind==='engine';});
  var spectatorControl=watching&&manager()&&['pause','resume','requestAi','rematch','restart','difficulty'].includes(e.action);
  require(actor||spectatorControl,'只有本局玩家可以操作');
  require(s.players.every(function(p){return !!member(p.id);}), '对手已离开聊天，请新建一局');
  if (e.action==='move') {
    require(s.phase==='playing','本局已经结束');require(!s.paused,'对局已暂停');require(actor.side===s.turn,'还没轮到你');
    var moves=legalMoves(),match=moves.find(function(m){return JSON.stringify(m.to)===JSON.stringify(d.to)&&JSON.stringify(m.from)===JSON.stringify(d.from);});
    require(match,'这一步不符合棋规，请选择合法落点');
    var record=Chess.play(s,match);record.actorId=actor.id;record.side=s.turn;s.history.push(record);s.ply++;s.drawOffer=null;
    var movedSide=s.turn;s.turn=Chess.nextTurn?Chess.nextTurn(s.board,movedSide):s.turn===Chess.first?Chess.second:Chess.first;
    if (Chess.outcome) {
      var outcome=Chess.judge?Chess.judge(s,match,movedSide):Chess.outcome(s.board,match,movedSide);
      if(outcome){s.winningLine=outcome.line;finished(outcome.winner,outcome.reason);}
      if(GAME==='halma'&&s.phase==='playing'&&!Chess.legal(s.board,s.turn).length)finished(null,'双方均无法移动');
      if(Chess.repetition){var key=position(),maxPly=Chess.maxPly===undefined?400:Chess.maxPly;s.positions[key]=(s.positions[key]||0)+1;if(s.phase==='playing'&&(s.positions[key]>=3||maxPly>0&&s.ply>=maxPly))finished(null,s.positions[key]>=3?'三次重复局面':'达到 '+maxPly+' 步');}
    } else if (GAME!=='xiangqi') {
      s.winningLine=Chess.winningLine(s.board,match.to);
      if (s.winningLine.length) finished(movedSide,GAME==='tictactoe'?'三子连线':'连成五子');
      else if (s.ply===Chess.width*Chess.height) finished(null,'棋盘已满');
    } else {
      var key=position();s.positions[key]=(s.positions[key]||0)+1;
      if (!legalMoves().length) finished(movedSide,Chess.legal(s.board,s.turn).length?'长将长捉无可变着':Chess.check(s.board,s.turn)?'将死':'无棋可走');
      var repeat=Chess.repetition(s);
      if (s.phase==='playing'&&repeat&&!repeat.offender) finished(null,'三次重复局面');
      if (s.phase==='playing'&&s.quiet>=120) finished(null,'连续 120 步未吃子');
      if (s.phase==='playing'&&s.ply>=400) finished(null,'达到 400 步');
    }
    notify(person(actor)+' '+record.text+(s.phase==='playing'&&GAME==='xiangqi'&&Chess.check(s.board,s.turn)?' · **将军！**':''),s.phase==='playing'&&player(s.turn).kind==='agent');
    if((GAME==='reversi'||GAME==='halma')&&s.phase==='playing'&&s.turn===movedSide)notify(person(player(movedSide===Chess.first?Chess.second:Chess.first))+'无合法走法，自动让行',false);
    if (s.phase==='finished') notify((s.winner?person(player(s.winner))+'**获胜**':'**和棋**')+' · '+s.result,false);
  } else if (e.action==='undo') {
    require(actor.kind!=='agent'&&actor.kind!=='engine','只有玩家可以悔棋');
    var index=s.history.map(function(m){return m.actorId;}).lastIndexOf(actor.id);
    require(index>=0,'没有可以撤回的落子');
    var retained=s.history.slice(0,index),count=s.history.length-index;
    var firstSide=openingSide();
    s.board=Chess.initial();s.turn=firstSide;s.ply=0;s.quiet=0;s.positions={};s.positions[position()]=1;
    if(Chess.restore){Chess.restore(s);s.positions={};s.positions[position()]=1;}
    retained.forEach(function(m){Chess.play(s,m);s.ply++;s.turn=Chess.nextTurn?Chess.nextTurn(s.board,s.turn):s.turn===Chess.first?Chess.second:Chess.first;var key=position();s.positions[key]=(s.positions[key]||0)+1;});
    s.history=retained;s.phase='playing';s.winner=null;s.result='';s.winningLine=[];s.drawOffer=null;
    host.call('replies.interrupt',{});
    notify(person(actor)+' 悔棋，撤回'+count+'步',false);
  } else if (e.action==='resign') {
    require(s.phase==='playing','本局已经结束');finished(actor.side===Chess.first?Chess.second:Chess.first,'对手认输');notify(person(actor)+'认输，'+person(player(s.winner))+'**获胜**',false);
  } else if (e.action==='offerDraw') {
    require(s.phase==='playing'&&!s.drawOffer,'当前不能提和');s.drawOffer=actor.id;
    notify(actor.name+'提议和棋',s.players.some(function(p){return p.id!==actor.id&&p.kind==='agent';}));
  } else if (e.action==='answerDraw') {
    require(s.phase==='playing'&&s.drawOffer&&s.drawOffer!==actor.id,'没有需要你处理的提和');require(typeof d.accept==='boolean','请选择接受或拒绝');
    s.drawOffer=null;if (d.accept) finished(null,'双方同意和棋');
    notify(actor.name+(d.accept?'接受和棋':'拒绝和棋'),!d.accept&&player(s.turn).kind==='agent');
  } else if (e.action==='pause'||e.action==='resume') {
    require(watching&&manager()&&s.phase==='playing','只有观战发起人可以暂停或继续');
    s.paused=e.action==='pause';
    var waiting=s.drawOffer?s.players.find(function(p){return p.id!==s.drawOffer;}):player(s.turn);
    if(!s.paused&&waiting.kind==='agent')notify(s.drawOffer?'请'+waiting.name+'回应和棋':'继续对局，轮到'+waiting.name,true);
  } else if (e.action==='requestAi') {
    require((spectatorControl||actor.kind!=='agent')&&!s.paused&&s.phase==='playing'&&player(s.turn).kind==='agent','当前不需要请 AI 落子');notify('请'+player(s.turn).name+'继续落子',true);
  } else if (e.action==='difficulty') {
    require((spectatorControl||actor.kind!=='agent'&&actor.kind!=='engine')&&s.players.some(function(p){return p.kind==='engine';}),'只有本地对局玩家可以调整难度');
    require(Number.isInteger(d.level)&&d.level>=1&&d.level<=5,'请选择有效难度');s.difficulty=d.level;
  } else if (e.action==='rematch'||e.action==='restart') {
    require(s.phase==='finished'||e.action==='restart'&&s.phase==='playing'&&(spectatorControl||actor.kind!=='agent'&&actor.kind!=='engine'),'本局尚未结束');
    if(s.phase==='playing')host.call('replies.interrupt',{});
    var oldHuman=s.players[0],oldAi=s.players[1];
    var humanFirst=oldHuman.side!==openingSide();
    if(GAME==='xiangqi'&&d.mode!==undefined)Chess=XiangqiModes.get(d.mode);
    start(member(oldHuman.id),member(oldAi.id),humanFirst,s.game+1,s.difficulty,oldHuman.side);
    notify('第'+s.game+'局开始，交换先后手，轮到'+player(s.turn).name,player(s.turn).kind==='agent');
  } else throw new Error('不支持的棋局操作');
}
var protocol='这是'+(GAME==='xiangqi'?XiangqiModes.labels[s.mode]:TITLE)+'人机对局。先 readHtmlProgram 读取当前 view；board 是从上到下逐行排列的二维棋盘，board[y][x] 对应坐标 [x,y]，左上角为 [0,0]，空位为“·”。'+(GAME==='xiangqi'?'棋子含义见 pieceLegend。暗子身份对双方保密，不得猜作确定棋子；揭棋暗子的标记只代表原位置走法。暗棋首次翻子后按最新 players 确认自己的颜色。':GAME==='tictactoe'?'X/O 为双方固定符号，本局先手见 firstSide。':Chess.legend?'棋子标记和阵营含义见 pieceLegend、players 与 rules。':'●为黑棋，○为白棋。')+'具体棋规：'+Chess.rules+' 行列索引见 boardCoordinates；界面字母列 A、B…对应 x=0、1…，数字行 1、2…对应 y=0、1…。只在轮到你时从 legalMoves 中选择一步，submitHtmlProgramEvent action:move data:{game:view.game,ply:view.ply,from:[x,y],to:[x,y]}；没有 from 的合法走法省略 from；跳棋按 legalMoves 的起终点提交，程序自动完成整条连跳。不要凭旧聊天记忆下棋，不要修改源代码或直接写数据。对方提和时可 action:answerDraw data:{game,ply,accept:boolean}；主动提和 action:offerDraw、认输 action:resign；结束后等用户决定是否再来一局。view.paused 为 true 时不要落子，等待继续对局回调。一次只走一步，等待下一次回调，不要轮询；错误按实际原因处理，不要自动原样重试。';
var privateViews={};s.players.filter(function(p){return p.kind!=='engine';}).forEach(function(p){privateViews[p.id]={protocol:protocol};});
s.players.filter(function(p){return p.kind!=='engine';}).forEach(function(p){privateViews[p.id].protocol+=' 下棋时没有必要的话就不要说话，不必每走一步都回复一句；程序会自动发布棋谱、将军与胜负。用户悔棋后以最新棋盘为准，等用户重新落子。';});
// The UI history is for human viewers; model views use the live board only.
members.filter(function(m){return m.kind!=='agent';}).forEach(function(m){privateViews[m.id]=Object.assign({},privateViews[m.id],{history:s.history.slice(-12)});});
// The engine retains its flat board; the public view exposes readable rows.
var legend=Chess.legend|| (GAME==='xiangqi'?Object.keys(Chess.names).reduce(function(out,code){out[code]=(code[0]==='r'?'红':'黑')+Chess.names[code];return out;},{}):GAME==='tictactoe'?{x:'X',o:'O'}:{b:'●',w:'○'});
var boardRows=[];
for(var y=0;y<Chess.height;y++) boardRows.push(s.board.slice(y*Chess.width,(y+1)*Chess.width).map(function(piece){return piece===null?'·':legend[piece];}));
return {state:s,view:{gameType:GAME,title:TITLE,mode:s.mode,colorsAssigned:s.colorsAssigned,unseenPieces:Chess.unseen?Chess.unseen(s):undefined,quiet:s.quiet,phase:s.phase,paused:s.paused,watching:s.players.every(function(p){return p.kind==='agent'||p.kind==='engine';}),game:s.game,firstSide:openingSide(),difficulty:s.difficulty,board:boardRows,boardCoordinates:{columns:Array.from({length:Chess.width},function(_,x){return x;}),rows:Array.from({length:Chess.height},function(_,y){return y;})},width:Chess.width,height:Chess.height,players:s.players,turn:s.turn,ply:s.ply,
  legalMoves:s.phase==='playing'?legalMoves():[],inCheck:GAME==='xiangqi'&&s.phase==='playing'?Chess.check(s.board,s.turn):false,
  undoPlayerIds:s.players.filter(function(p){return p.kind!=='agent'&&p.kind!=='engine'&&s.history.some(function(m){return m.actorId===p.id;});}).map(function(p){return p.id;}),
  pieceLegend:legend,winner:s.winner,result:s.result,winningLine:s.winningLine,drawOffer:s.drawOffer,rules:Chess.rules},privateViews:privateViews};
