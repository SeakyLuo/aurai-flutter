var s=ctx.state,e=ctx.event,d=e.data;
function require(ok,message){if(!ok)throw new Error(message);}
function person(p){return p.kind==='engine'?p.name:'['+p.name.replace(/[\\\[\]]/g,'\\$&')+'](aurai://member/'+encodeURIComponent(p.id)+')';}
function notify(text){host.call('messages.send',{text:text,markdown:true});}
function start(game){
  var human=ctx.members.find(function(p){return p.id==='user:local';});
  require(human,'请由本机玩家打开对局');
  var players=[{id:human.id,name:human.name,kind:human.kind,side:0}];
  for(var i=1;i<Cards.seats;i++)players.push({id:'engine:card:'+i,name:'电脑 '+i,kind:'engine',side:i});
  s=Cards.create(players,Math.floor(Math.random()*4294967296));s.game=game;s.ply=0;
}
require(e.actorId==='user:local','请由本局玩家操作，其他成员可以观战');
if(e.action==='configure'){
  require(!s.phase||s.phase==='setup','对局已经开始');start(1);
  notify(person(s.players[0])+'开始了'+TITLE+'，与本地 AI 对局');
}else{
  require(s.phase==='playing'||s.phase==='finished','请先开始对局');
  require(d.game===s.game&&d.ply===s.ply,'对局已变化，请基于当前状态操作');
  var was=s.phase;
  if(e.action==='rematch'){
    require(s.phase==='finished','本局尚未结束');start(s.game+1);
    notify(person(s.players[0])+'开始了新一局'+TITLE);
  }else if(e.action==='leave'){
    require(!ctx.decision&&s.phase==='playing','当前无法结束对局');
    s.phase='finished';s.abandoned=true;s.result='本局已结束';s.ply++;
    notify(person(s.players[0])+'结束了'+TITLE+'对局');
  }else{
    require(s.phase==='playing','本局已经结束');
    var seat=0,action=e.action,data=d;
    if(ctx.decision===true){
      require(e.action==='cardAi'&&s.players[s.turn].kind==='engine','当前没有需要行动的电脑');
      seat=s.turn;
      // Only the same public table and this seat's own hand enter the strategy.
      var move=Cards.ai(Cards.privateView(s,seat),Cards.publicView(s));action=move.action;data=move.data;
    }else require(e.action!=='cardAi','请通过对局引擎继续');
    Cards.apply(s,seat,action,data);s.ply++;
    if(s.phase==='finished'&&was!=='finished'){
      var winners=s.winners|| (s.winner===null?[]:[s.winner]);
      notify((winners.length?winners.map(function(i){return person(s.players[i]);}).join('、')+'**获胜**':'**和局**')+' · '+TITLE+(GAME==='doudizhu'?' · '+s.result:''));
    }
  }
}
var view=Cards.publicView(s);
view.gameType=GAME;view.title=TITLE;view.game=s.game;view.ply=s.ply;view.rules=Cards.rules;
view.abandoned=!!s.abandoned;
var privateViews={};
privateViews['user:local']=Cards.privateView(s,0);
// Hidden hands and the remaining deck stay inside the persisted reducer state.
return {state:s,view:view,privateViews:privateViews};
