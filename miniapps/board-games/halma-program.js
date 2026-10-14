var s=ctx.state,e=ctx.event,d=e.data,members=ctx.members;
function require(ok,message){if(!ok)throw new Error(message);}
function member(id){if(/^engine:halma:[1-5]$/.test(id))return {id:id,name:'电脑 '+id.slice(-1),kind:'engine'};return members.find(function(m){return m.id===id;});}
function manager(){return e.actorId===ctx.ownerId||e.actorId==='user:local';}
function player(side){return s.players.find(function(p){return p.side===side;});}
function activeSides(){return s.players.filter(function(p){return p.active;}).map(function(p){return p.side;});}
function position(){return s.turn+':'+activeSides().join('')+':'+s.board.map(function(p){return p||'.';}).join(',');}
function person(p){return p.kind==='engine'?p.name:'['+p.name.replace(/[\\\[\]]/g,'\\$&')+'](aurai://member/'+encodeURIComponent(p.id)+')';}
function notify(text,wake){var args={text:text,markdown:true};if(wake){args.audience=members.map(function(m){return m.id;});args.wakeAi=true;args.wakeMemberIds=[player(s.turn).id];}host.call('messages.send',args);}
function finish(winner,reason){s.phase='finished';s.winner=winner;s.result=reason;s.winningLine=winner?Chess.target(winner).map(function(i){return [i%17,Math.floor(i/17)];}):[];notify((winner?person(player(winner))+'**获胜**':'**和棋**')+' · '+reason,false);}
function start(players,firstSide,game,difficulty){
  Chess.setSides(players.map(function(p){return p.side;}));
  s={phase:'playing',game:game,difficulty:difficulty,players:players.map(function(p){return {id:p.id,name:p.name,kind:p.kind,side:p.side,active:true};}),firstSide:firstSide,turn:firstSide,board:Chess.initial(),ply:0,history:[],positions:{},winner:null,result:'',winningLine:[],drawOffer:null,paused:false};
  s.positions[position()]=1;
}
function nextGame(){
  var first=s.players[(s.players.findIndex(function(p){return p.side===s.firstSide;})+1)%s.players.length].side;
  start(s.players,first,s.game+1,s.difficulty);notify('第'+s.game+'局开始，轮到'+person(player(s.turn)),player(s.turn).kind==='agent');
}
function advance(side){
  var order=s.players.map(function(p){return p.side;}),at=order.indexOf(side),next=null;
  for(var n=1;n<=order.length;n++){var candidate=player(order[(at+n)%order.length]);if(!candidate.active)continue;if(Chess.legal(s.board,candidate.side).length){next=candidate.side;break;}notify(person(candidate)+'无合法走法，自动让行',false);}
  if(next===null){finish(null,'所有玩家均无法移动');return;}s.turn=next;
}
if(e.action==='configure'){
  require(manager(),'只有发起人可以配置对局');require(!s.phase,'本局已经创建');
  require(Array.isArray(d.players)&&[2,3,4,6].includes(d.players.length),'请选择 2、3、4 或 6 位玩家');
  require(d.players.every(function(id,i){return typeof id==='string'&&member(id)&&d.players.indexOf(id)===i;}),'请选择当前聊天中的不同玩家');
  require(!d.players.some(function(id){return member(id).kind==='engine';})||e.actorId==='user:local','请由本地用户开启电脑对局');
  require(d.players.includes(d.firstId),'请选择先手玩家');
  var level=d.difficulty===undefined?3:d.difficulty;require(Number.isInteger(level)&&level>=1&&level<=5,'请选择有效难度');
  var sides=Chess.seatSides[d.players.length],players=d.players.map(function(id,i){return Object.assign({},member(id),{side:sides[i]});});
  start(players,players.find(function(p){return p.id===d.firstId;}).side,1,level);
  notify(person(player(s.turn))+'执'+Chess.sides[s.turn]+'先行',player(s.turn).kind==='agent'&&player(s.turn).id!==e.actorId);
}else{
  require(s.phase==='playing'||s.phase==='finished','请先创建对局');
  require(d.game===s.game&&d.ply===s.ply,'棋盘已变化，请查看最新棋盘再操作');
  Chess.setSides(activeSides());
  var actor=s.players.find(function(p){return p.id===e.actorId;});
  if(ctx.decision===true){require(e.actorId==='user:local','引擎只能由本地玩家执行');actor=s.players.find(function(p){return p.active&&p.kind==='engine'&&(s.drawOffer?p.id!==s.drawOffer:p.side===s.turn);});}
  var control=manager()&&['rematch','restart','difficulty','requestAi'].includes(e.action);
  require(actor||control,'只有本局玩家或发起人可以操作');
  require(s.players.every(function(p){return !!member(p.id);}), '玩家已离开聊天，请新建一局');
  if(e.action==='move'){
    require(s.phase==='playing'&&actor.active,'本局已经结束或你已认输');require(actor.side===s.turn,'还没轮到你');
    var move=Chess.legal(s.board,s.turn).find(function(m){return JSON.stringify(m.from)===JSON.stringify(d.from)&&JSON.stringify(m.to)===JSON.stringify(d.to);});
    require(move,'这一步不符合棋规，请选择合法落点');
    var side=s.turn,record=Chess.play(s,move);record.actorId=actor.id;record.side=side;s.history.push(record);s.ply++;s.drawOffer=null;
    notify(person(actor)+' '+record.text,false);
    var outcome=Chess.outcome(s.board,move,side);
    if(outcome)finish(side,outcome.reason);else advance(side);
    if(s.phase==='playing'){var key=position();s.positions[key]=(s.positions[key]||0)+1;if(s.ply>=1200)finish(null,'达到 1200 步');}
    if(s.phase==='playing'&&player(s.turn).kind==='agent')notify('轮到'+person(player(s.turn))+'落子',true);
  }else if(e.action==='undo'){
    require(actor.active&&actor.kind!=='agent'&&actor.kind!=='engine','只有未退出的玩家可以悔棋');
    var index=s.history.map(function(m){return m.actorId;}).lastIndexOf(actor.id);require(index>=0,'没有可以撤回的落子');
    var retained=s.history.slice(0,index),count=s.history.length-index;
    Chess.setSides(s.players.map(function(p){return p.side;}));s.board=Chess.initial();Chess.setSides(activeSides());s.turn=s.firstSide;s.ply=0;s.positions={};s.positions[position()]=1;
    retained.forEach(function(m){s.turn=m.side;Chess.play(s,m);s.ply++;s.turn=Chess.nextTurn(s.board,m.side);var key=position();s.positions[key]=(s.positions[key]||0)+1;});
    s.turn=actor.side;s.history=retained;s.phase='playing';s.winner=null;s.result='';s.winningLine=[];s.drawOffer=null;host.call('replies.interrupt',{});
    notify(person(actor)+'悔棋，撤回'+count+'步',false);
  }else if(e.action==='resign'){
    require(s.phase==='playing'&&actor.active,'本局已经结束或你已认输');actor.active=false;s.drawOffer=null;s.ply++;Chess.setSides(activeSides());
    notify(person(actor)+'认输',false);
    if(activeSides().length===1){finish(activeSides()[0],'其余玩家认输');host.call('replies.interrupt',{});nextGame();}
    else if(s.turn===actor.side)advance(actor.side);
    if(s.game===d.game&&s.phase==='playing'&&player(s.turn).kind==='agent')notify('轮到'+person(player(s.turn))+'落子',true);
  }else if(e.action==='offerDraw'||e.action==='answerDraw'){
    require(s.players.length===2&&s.phase==='playing','和棋协商仅用于双人对局');
    if(e.action==='offerDraw'){require(!s.drawOffer,'已提出和棋');s.drawOffer=actor.id;var other=s.players.find(function(p){return p.id!==actor.id;});var args={text:actor.name+'提议和棋'};if(other.kind==='agent'){args.audience=members.map(function(m){return m.id;});args.wakeAi=true;args.wakeMemberIds=[other.id];}host.call('messages.send',args);}
    else{require(s.drawOffer&&s.drawOffer!==actor.id,'没有需要你处理的提和');require(typeof d.accept==='boolean','请选择接受或拒绝');s.drawOffer=null;if(d.accept)finish(null,'双方同意和棋');else notify(actor.name+'拒绝和棋',player(s.turn).kind==='agent');}
  }else if(e.action==='difficulty'){
    require((manager()||actor.kind!=='agent'&&actor.kind!=='engine')&&s.players.some(function(p){return p.kind==='engine';}),'只有玩家或发起人可以调整难度');require(Number.isInteger(d.level)&&d.level>=1&&d.level<=5,'请选择有效难度');s.difficulty=d.level;
  }else if(e.action==='requestAi'){
    require(s.phase==='playing'&&player(s.turn).kind==='agent','当前不需要请 AI 落子');notify('请'+person(player(s.turn))+'继续落子',true);
  }else if(e.action==='rematch'||e.action==='restart'){
    require(s.phase==='finished'||e.action==='restart'&&(manager()||actor.kind!=='agent'&&actor.kind!=='engine'),'本局尚未结束');host.call('replies.interrupt',{});
    nextGame();
  }else throw new Error('不支持的棋局操作');
}
var protocol='这是多人中国跳棋。每次先 readHtmlProgram 读取最新 view；players 给出各玩家颜色和 active 状态，turn 是当前颜色，board 是二维棋盘，pieceLegend 解释棋子标记。只在轮到自己且 active 时，从 legalMoves 选择一步，submitHtmlProgramEvent action:move data:{game:view.game,ply:view.ply,from:[x,y],to:[x,y]}，起终点按棋盘索引提交，连跳由程序完成。不要凭聊天旧棋盘落子，不读其他玩家视角，不代其他玩家操作。一次只走一步，不轮询，不重复发送确认。'+Chess.rules;
var privateViews={};s.players.filter(function(p){return p.kind!=='engine';}).forEach(function(p){privateViews[p.id]={protocol:protocol};});
members.filter(function(m){return m.kind!=='agent';}).forEach(function(m){privateViews[m.id]=Object.assign({},privateViews[m.id],{history:s.history.slice(-12)});});
var rows=[];for(var y=0;y<17;y++)rows.push(s.board.slice(y*17,(y+1)*17).map(function(p){return p===null?'·':Chess.legend[p];}));
return {state:s,view:{gameType:GAME,title:TITLE,phase:s.phase,watching:s.players.every(function(p){return p.kind==='agent'||p.kind==='engine';}),paused:false,game:s.game,firstSide:s.firstSide,difficulty:s.difficulty,board:rows,boardCoordinates:{columns:Array.from({length:17},function(_,i){return i;}),rows:Array.from({length:17},function(_,i){return i;})},width:17,height:17,players:s.players,turn:s.turn,ply:s.ply,legalMoves:s.phase==='playing'?Chess.legal(s.board,s.turn):[],undoPlayerIds:s.players.filter(function(p){return p.active&&p.kind!=='agent'&&p.kind!=='engine'&&s.history.some(function(m){return m.actorId===p.id;});}).map(function(p){return p.id;}),pieceLegend:Chess.legend,winner:s.winner,result:s.result,winningLine:s.winningLine,drawOffer:s.drawOffer,rules:Chess.rules},privateViews:privateViews};
