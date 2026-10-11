// SCOUT rules by Kei Kajino / Oink Games, three-player rules.
// https://oinkgames.com/en/games/analog/scout/ — artwork below is original CSS.
var Cards=(function(){
  function require(ok,message){if(!ok)throw Error(message);}
  function random(s){s.seed=(Math.imul(s.seed,1664525)+1013904223)>>>0;return s.seed/4294967296;}
  function log(s,seat,text){s.logs.push({seat:seat,text:text});s.logs=s.logs.slice(-12);}
  function flipped(hand){return hand.slice().reverse().map(function(c){return {id:c.id,top:c.bottom,bottom:c.top};});}
  function combination(cards){
    if(!cards.length)return null;
    var values=cards.map(function(c){return c.top;}),same=values.every(function(n){return n===values[0];});
    var direction=values.length>1?values[1]-values[0]:0;
    if(!same&&!(Math.abs(direction)===1&&values.every(function(n,i){return i===0||n-values[i-1]===direction;})))return null;
    return {count:values.length,type:same?1:0,low:Math.min.apply(null,values)};
  }
  function beats(a,b){return !b||a.count>b.count||a.count===b.count&&(a.type>b.type||a.type===b.type&&a.low>b.low);}
  function shows(hand,active){
    var target=combination(active),out=[];
    for(var i=0;i<hand.length;i++)for(var n=1;n<=hand.length-i;n++){
      var group=combination(hand.slice(i,i+n));if(group&&beats(group,target))out.push({start:i,count:n,type:group.type,low:group.low});
    }
    return out;
  }
  function recruit(hand,active,data){
    require(data.edge==='left'||data.edge==='right','请选择牌桌左端或右端');
    require(typeof data.flip==='boolean','请选择招募牌的朝向');
    require(Number.isInteger(data.position)&&data.position>=0&&data.position<=hand.length,'请选择插入位置');
    require(active.length>0,'牌桌上没有可招募的牌');
    var picked=active[data.edge==='left'?0:active.length-1];
    var card={id:picked.id,top:data.flip?picked.bottom:picked.top,bottom:data.flip?picked.top:picked.bottom};
    var nextHand=hand.slice();nextHand.splice(data.position,0,card);
    return {hand:nextHand,active:active.filter(function(c){return c.id!==picked.id;}),card:card};
  }
  function deal(s){
    var deck=[],id=0;
    // Three players remove all nine cards containing 10: 36 cards, 12 each.
    for(var a=1;a<=9;a++)for(var b=a+1;b<=9;b++)deck.push({id:id++,top:a,bottom:b});
    for(var i=deck.length-1;i>0;i--){var j=Math.floor(random(s)*(i+1)),card=deck[i];deck[i]=deck[j];deck[j]=card;}
    deck=deck.map(function(c){return random(s)<.5?{id:c.id,top:c.bottom,bottom:c.top}:c;});
    s.hands=[deck.slice(0,12),deck.slice(12,24),deck.slice(24)];
    s.stage='orient';s.turn=0;s.oriented=[false,false,false];s.active=[];s.owner=null;s.scouted=0;
    s.captured=[0,0,0];s.tokens=[0,0,0];s.comboUsed=[false,false,false];s.roundScores=null;
  }
  function create(players,seed){var s={phase:'playing',players:players,seed:seed>>>0,round:1,scores:[0,0,0],logs:[],winner:null,winners:[],result:''};deal(s);return s;}
  function quality(hand){
    // Minimum number of adjacent valid sets needed to empty this hand.
    var costs=Array(hand.length+1).fill(Infinity);costs[hand.length]=0;
    for(var i=hand.length-1;i>=0;i--)for(var n=1;n<=hand.length-i;n++)if(combination(hand.slice(i,i+n)))costs[i]=Math.min(costs[i],1+costs[i+n]);
    return -costs[0]*10+hand.reduce(function(total,c){return total+c.top;},0)/100;
  }
  function endRound(s,immune){
    s.roundScores=s.scores.map(function(_,i){return s.captured[i]+s.tokens[i]-(i===immune?0:s.hands[i].length);});
    s.scores=s.scores.map(function(n,i){return n+s.roundScores[i];});
    log(s,-1,'第 '+s.round+' 轮结束');
    if(s.round===3){s.phase='finished';s.stage='finished';var best=Math.max.apply(null,s.scores);s.winners=s.scores.map(function(n,i){return n===best?i:-1;}).filter(function(i){return i>=0;});s.winner=s.winners[0];s.result=s.winners.map(function(i){return s.players[i].name;}).join('、')+'获胜';}
    else{s.stage='roundEnd';s.turn=0;}
  }
  function show(s,seat,start,count){
    var move=shows(s.hands[seat],s.active).find(function(m){return m.start===start&&m.count===count;});
    require(move,'请选择手中相邻且比当前演出更强的组合');
    s.captured[seat]+=s.active.length;s.active=s.hands[seat].splice(start,count);s.owner=seat;s.scouted=0;
    log(s,seat,'演出 '+s.active.map(function(c){return c.top;}).join(' · '));
    if(!s.hands[seat].length)endRound(s,null);else s.turn=(seat+1)%3;
  }
  function apply(s,seat,action,data){
    require(s.phase==='playing'&&seat===s.turn,'尚未轮到你');
    if(s.stage==='orient'){
      require(action==='orient'&&typeof data.flip==='boolean','请确认整手牌的朝向');
      if(data.flip)s.hands[seat]=flipped(s.hands[seat]);s.oriented[seat]=true;
      if(s.oriented.every(Boolean)){s.stage='play';s.turn=(s.round-1)%3;}else s.turn=(seat+1)%3;
      return;
    }
    if(s.stage==='roundEnd'){
      require(action==='nextRound','请开始下一轮');s.round++;deal(s);return;
    }
    if(action==='show'){show(s,seat,data.start,data.count);return;}
    require(action==='scout'||action==='scoutShow','请选择演出或招募');
    require(s.owner!==seat,'不能招募自己的演出');
    if(action==='scoutShow')require(!s.comboUsed[seat],'本轮招募并演出已经使用');
    var change=recruit(s.hands[seat],s.active,data);
    if(action==='scoutShow')require(shows(change.hand,change.active).some(function(m){return m.start===data.start&&m.count===data.count;}),'招募后请选择有效的演出组合');
    s.hands[seat]=change.hand;s.active=change.active;s.tokens[s.owner]++;s.scouted++;
    log(s,seat,'招募 '+change.card.top);
    if(action==='scoutShow'){s.comboUsed[seat]=true;show(s,seat,data.start,data.count);}
    else if(s.scouted===2)endRound(s,s.owner);else s.turn=(seat+1)%3;
  }
  function publicView(s){return {phase:s.phase,stage:s.stage,turn:s.turn,players:s.players,round:s.round,scores:s.scores,counts:s.hands.map(function(h){return h.length;}),active:s.active,owner:s.owner,scouted:s.scouted,captured:s.captured,tokens:s.tokens,comboUsed:s.comboUsed,roundScores:s.roundScores,logs:s.logs,winner:s.winner,winners:s.winners,result:s.result};}
  function privateView(s,seat){return {seat:seat,hand:s.hands[seat],legalShows:s.phase==='playing'&&s.stage==='play'&&s.turn===seat?shows(s.hands[seat],s.active):[]};}
  function ai(own,v){
    if(v.stage==='orient')return {action:'orient',data:{flip:quality(flipped(own.hand))>quality(own.hand)}};
    var legal=own.legalShows;
    if(legal.length){
      var best=legal.slice().sort(function(a,b){function value(m){var rest=own.hand.slice();rest.splice(m.start,m.count);return m.count*8+quality(rest)-m.low*.15;}return value(b)-value(a);})[0];
      return {action:'show',data:{start:best.start,count:best.count}};
    }
    var choices=[];
    ['left','right'].forEach(function(edge){[false,true].forEach(function(flip){for(var p=0;p<=own.hand.length;p++){
      var data={edge:edge,flip:flip,position:p},r=recruit(own.hand,v.active,data),value=quality(r.hand);
      choices.push({action:'scout',data:data,value:value});
      if(!v.comboUsed[own.seat])shows(r.hand,r.active).forEach(function(m){var rest=r.hand.slice();rest.splice(m.start,m.count);choices.push({action:'scoutShow',data:{edge:edge,flip:flip,position:p,start:m.start,count:m.count},value:quality(rest)+m.count*8-5});});
    }});});
    choices.sort(function(a,b){return b.value-a.value;});return {action:choices[0].action,data:choices[0].data};
  }
  return {title:'Scout 马戏星探',seats:3,create:create,apply:apply,publicView:publicView,privateView:privateView,ai:ai,flipped:flipped,combination:combination,shows:shows,recruit:recruit,
    rules:'三人局，共三轮；使用不含 10 的 36 张双数字牌，每人 12 张。每轮开始可把整手牌翻转一次，之后不能重排或翻转手牌。\n演出：打出手中相邻的同数牌或连续升序／降序牌。先比张数，再比牌型（同数大于连续），最后比最小数字；必须严格压过桌面演出。被压过的桌牌每张得 1 分。\n招募：只能取桌牌两端的一张，可翻面并插入手牌任意位置；原演出者得 1 分。本轮每人可使用一次“招募并演出”，招募后立即出牌。\n有人出完手牌，或一次演出后其他两人都仅招募，立即结束本轮。每人得分为赢得的桌牌数＋被招募次数－剩余手牌数；连续被两人招募的演出者不扣手牌分。桌上仍在演出的牌不计分。每轮起始玩家轮换，三轮总分最高者获胜，可并列。'};
})();
