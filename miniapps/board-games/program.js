var s=ctx.state,e=ctx.event,d=e.data,members=ctx.members;
function require(ok,message) { if (!ok) throw new Error(message); }
function member(id) { return members.find(function(m){return m.id===id;}); }
function manager() { return e.actorId===ctx.ownerId||e.actorId==='user:local'; }
function player(color) { return s.players.find(function(p){return p.side===color;}); }
function finished(winner,reason) { s.phase='finished'; s.winner=winner; s.result=reason; }
function position() { return s.turn+':'+s.board.map(function(p){return p||'.';}).join(','); }
function person(p) { return '['+p.name.replace(/[\\\[\]]/g,'\\$&')+'](aurai://member/'+encodeURIComponent(p.id)+')'; }
function start(human,ai,humanFirst,game) {
  s={phase:'playing',game:game,board:Chess.initial(),turn:Chess.first,ply:0,quiet:0,history:[],positions:{},winner:null,result:'',winningLine:[],drawOffer:null,
    players:[{id:human.id,name:human.name,kind:human.kind,side:humanFirst?Chess.first:Chess.second},{id:ai.id,name:ai.name,kind:ai.kind,side:humanFirst?Chess.second:Chess.first}]};
  s.positions[position()]=1;
}
function notify(text,wake) {
  var args={text:text,markdown:true};
  if (wake) {
    var ai=s.players.find(function(p){return p.kind==='agent';});
    args.audience=members.map(function(m){return m.id;});args.wakeAi=true;args.wakeMemberIds=[ai.id];
  }
  host.call('messages.send',args);
}
if (e.action==='configure') {
  require(manager(),'只有发起人可以配置对局');require(!s.phase,'本局已经创建');
  var human=member(d.humanId),ai=member(d.aiId);
  require(human&&human.kind!=='agent','请选择当前聊天中的玩家');require(ai&&ai.kind==='agent','请选择当前聊天中的 AI');
  require(typeof d.humanFirst==='boolean','请选择先手');start(human,ai,d.humanFirst,1);
  // The AI configuring its own first move is already running; do not wake it twice.
  notify(person(player(s.turn))+'执'+Chess.sides[s.turn]+'先行',player(s.turn).kind==='agent'&&player(s.turn).id!==e.actorId);
} else {
  require(s.phase==='playing'||s.phase==='finished','请先创建对局');
  require(d.game===s.game&&d.ply===s.ply,'棋盘已变化，请查看最新棋盘再操作');
  var actor=s.players.find(function(p){return p.id===e.actorId;});
  require(actor,'只有本局玩家可以操作');
  require(s.players.every(function(p){return !!member(p.id);}), '对手已离开聊天，请新建一局');
  if (e.action==='move') {
    require(s.phase==='playing','本局已经结束');require(actor.side===s.turn,'还没轮到你');
    var moves=Chess.legal(s.board,s.turn),match=moves.find(function(m){return JSON.stringify(m.to)===JSON.stringify(d.to)&&JSON.stringify(m.from)===JSON.stringify(d.from);});
    require(match,'这一步不符合棋规，请选择合法落点');
    var record=Chess.play(s,match);record.actorId=e.actorId;record.side=s.turn;s.history.push(record);s.ply++;s.drawOffer=null;
    var movedSide=s.turn;s.turn=s.turn===Chess.first?Chess.second:Chess.first;
    if (GAME==='gomoku') {
      s.winningLine=Chess.winningLine(s.board,match.to);
      if (s.winningLine.length) finished(movedSide,'连成五子');
      else if (s.ply===225) finished(null,'棋盘已满');
    } else {
      if (!Chess.legal(s.board,s.turn).length) finished(movedSide,Chess.check(s.board,s.turn)?'将死':'无棋可走');
      var key=position();s.positions[key]=(s.positions[key]||0)+1;
      if (s.phase==='playing'&&s.positions[key]>=3) finished(null,'三次重复局面');
      if (s.phase==='playing'&&s.quiet>=120) finished(null,'连续 120 步未吃子');
      if (s.phase==='playing'&&s.ply>=400) finished(null,'达到 400 步');
    }
    notify(person(actor)+' '+record.text+(s.phase==='playing'&&GAME==='xiangqi'&&Chess.check(s.board,s.turn)?' · **将军！**':''),s.phase==='playing'&&player(s.turn).kind==='agent');
    if (s.phase==='finished') notify((s.winner?person(player(s.winner))+'**获胜**':'**和棋**')+' · '+s.result,false);
  } else if (e.action==='undo') {
    require(actor.kind!=='agent','只有玩家可以悔棋');
    var index=s.history.map(function(m){return m.actorId;}).lastIndexOf(actor.id);
    require(index>=0,'没有可以撤回的落子');
    var retained=s.history.slice(0,index),count=s.history.length-index;
    s.board=Chess.initial();s.turn=Chess.first;s.ply=0;s.quiet=0;s.positions={};s.positions[position()]=1;
    retained.forEach(function(m){Chess.play(s,m);s.ply++;s.turn=s.turn===Chess.first?Chess.second:Chess.first;var key=position();s.positions[key]=(s.positions[key]||0)+1;});
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
  } else if (e.action==='requestAi') {
    require(actor.kind!=='agent'&&s.phase==='playing'&&player(s.turn).kind==='agent','当前不需要请 AI 落子');notify('请'+player(s.turn).name+'继续落子',true);
  } else if (e.action==='rematch') {
    require(s.phase==='finished','本局尚未结束');
    var oldHuman=s.players.find(function(p){return p.kind!=='agent';}),oldAi=s.players.find(function(p){return p.kind==='agent';});
    start(member(oldHuman.id),member(oldAi.id),oldHuman.side!==Chess.first,s.game+1);
    notify('第'+s.game+'局开始，交换先后手，轮到'+player(s.turn).name,player(s.turn).kind==='agent');
  } else throw new Error('不支持的棋局操作');
}
var protocol='这是'+TITLE+'人机对局。先 readHtmlProgram 读取当前 view；board 是从上到下逐行排列的二维棋盘，board[y][x] 对应坐标 [x,y]，左上角为 [0,0]，空位为“·”。'+(GAME==='xiangqi'?'棋子直接标明红黑双方与名称。':'●为黑棋，○为白棋。')+'行列索引见 boardCoordinates；界面字母列 A、B…对应 x=0、1…，数字行 1、2…对应 y=0、1…。只在轮到你时从 legalMoves 中选择一步，submitHtmlProgramEvent action:move data:{game:view.game,ply:view.ply,from:[x,y],to:[x,y]}；五子棋省略 from。不要凭旧聊天记忆下棋，不要修改源代码或直接写数据。对方提和时可 action:answerDraw data:{game,ply,accept:boolean}；主动提和 action:offerDraw、认输 action:resign；结束后等用户决定是否再来一局。一次只走一步，等待下一次回调，不要轮询；错误按实际原因处理，不要自动原样重试。';
var privateViews={};s.players.forEach(function(p){privateViews[p.id]={protocol:protocol};});
s.players.forEach(function(p){privateViews[p.id].protocol+=' 下棋时没有必要的话就不要说话，不必每走一步都回复一句；程序会自动发布棋谱、将军与胜负。用户悔棋后以最新棋盘为准，等用户重新落子。';});
// The UI history is for human viewers; model views use the live board only.
members.filter(function(m){return m.kind!=='agent';}).forEach(function(m){privateViews[m.id]=Object.assign({},privateViews[m.id],{history:s.history.slice(-12)});});
// The engine retains its flat board; the public view exposes readable rows.
var legend=GAME==='xiangqi'?Object.keys(Chess.names).reduce(function(out,code){out[code]=(code[0]==='r'?'红':'黑')+Chess.names[code];return out;},{}):{b:'●',w:'○'};
var boardRows=[];
for(var y=0;y<Chess.height;y++) boardRows.push(s.board.slice(y*Chess.width,(y+1)*Chess.width).map(function(piece){return piece===null?'·':legend[piece];}));
return {state:s,view:{gameType:GAME,title:TITLE,phase:s.phase,game:s.game,board:boardRows,boardCoordinates:{columns:Array.from({length:Chess.width},function(_,x){return x;}),rows:Array.from({length:Chess.height},function(_,y){return y;})},width:Chess.width,height:Chess.height,players:s.players,turn:s.turn,ply:s.ply,
  legalMoves:s.phase==='playing'?Chess.legal(s.board,s.turn):[],inCheck:GAME==='xiangqi'&&s.phase==='playing'?Chess.check(s.board,s.turn):false,
  undoPlayerIds:s.players.filter(function(p){return p.kind!=='agent'&&s.history.some(function(m){return m.actorId===p.id;});}).map(function(p){return p.id;}),
  pieceLegend:legend,winner:s.winner,result:s.result,winningLine:s.winningLine,drawOffer:s.drawOffer,rules:Chess.rules},privateViews:privateViews};
