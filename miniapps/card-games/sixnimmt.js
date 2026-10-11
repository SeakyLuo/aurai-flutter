// Standard 104-card game, four players, 66-point match.
// https://blog.amigo-spiele.de/content/ap/rule/04910-DE-AmigoRule.pdf
var Cards=(function(){
  function require(ok,message){if(!ok)throw Error(message);}
  function points(c){return c===55?7:c%11===0?5:c%10===0?3:c%5===0?2:1;}
  function cost(row){return row.reduce(function(n,c){return n+points(c);},0);}
  function random(s){s.seed=(Math.imul(s.seed,1664525)+1013904223)>>>0;return s.seed/4294967296;}
  function log(s,seat,text){s.logs.push({seat:seat,text:text});s.logs=s.logs.slice(-12);}
  function deal(s){var deck=Array.from({length:104},function(_,i){return i+1;});for(var i=103;i>0;i--){var j=Math.floor(random(s)*(i+1)),v=deck[i];deck[i]=deck[j];deck[j]=v;}
    s.hands=Array.from({length:4},function(){return deck.splice(0,10).sort(function(a,b){return a-b;});});s.rows=deck.splice(0,4).map(function(c){return [c];});s.unused=deck;s.taken=[[],[],[],[]];s.roundPoints=[0,0,0,0];s.seen=s.rows.map(function(r){return r[0];});s.trick=1;startTrick(s);
  }
  function startTrick(s){s.stage='select';s.turn=0;s.choices=[null,null,null,null];s.queue=[];s.revealed=[];s.resolved=[];}
  function create(players,seed){var s={phase:'playing',players:players,seed:seed>>>0,round:1,scores:[0,0,0,0],logs:[],winner:null,winners:[],result:''};deal(s);return s;}
  function rowFor(rows,card){var best=-1,tail=0;rows.forEach(function(r,i){var n=r[r.length-1];if(n<card&&n>tail){best=i;tail=n;}});return best;}
  function cheapest(rows){return rows.reduce(function(best,row,i){return cost(row)<cost(rows[best])?i:best;},0);}
  function place(s,item,row,take){var captured=take?s.rows[row].slice():[],penalty=cost(captured);if(take){s.taken[item.seat]=s.taken[item.seat].concat(captured);s.scores[item.seat]+=penalty;s.roundPoints[item.seat]+=penalty;s.rows[row]=[item.card];}else s.rows[row].push(item.card);
    s.resolved.push({seat:item.seat,card:item.card,row:row,points:penalty,taken:captured});log(s,item.seat,'打出 '+item.card+'，'+(take?'收第 '+(row+1)+' 行，罚 '+penalty+' 分':'放入第 '+(row+1)+' 行'));
  }
  function resolve(s){while(s.queue.length){var item=s.queue[0],row=rowFor(s.rows,item.card);if(row===-1){s.stage='choose';s.turn=item.seat;return;}s.queue.shift();place(s,item,row,s.rows[row].length===5);}
    s.turn=0;
    if(s.trick<10){s.stage='trickEnd';return;}
    if(s.scores.some(function(n){return n>=66;})){s.phase='finished';s.stage='finished';var best=Math.min.apply(null,s.scores);s.winners=[0,1,2,3].filter(function(i){return s.scores[i]===best;});s.winner=s.winners.length===1?s.winners[0]:null;s.result=s.winners.map(function(i){return s.players[i].name;}).join('、')+(s.winners.length>1?'并列获胜':'获胜');}
    else s.stage='roundEnd';
  }
  function apply(s,seat,action,d){
    require(s.phase==='playing'&&s.turn===seat,'尚未轮到你');
    if(s.stage==='trickEnd'){require(action==='nextTrick','请继续下一次出牌');s.trick++;startTrick(s);return;}
    if(s.stage==='roundEnd'){require(action==='nextRound','请开始下一轮');s.round++;deal(s);return;}
    if(s.stage==='choose'){require(action==='take'&&Number.isInteger(d.row)&&d.row>=0&&d.row<4,'请选择要收取的一行');var item=s.queue.shift();place(s,item,d.row,true);resolve(s);return;}
    require(action==='commit'&&s.hands[seat].indexOf(d.card)>=0,'请选择一张手牌');s.hands[seat].splice(s.hands[seat].indexOf(d.card),1);s.choices[seat]=d.card;
    var next=s.choices.indexOf(null);if(next>=0){s.turn=next;return;}
    s.revealed=s.choices.map(function(card,i){return {card:card,seat:i};}).sort(function(a,b){return a.card-b.card;});s.queue=s.revealed.slice();s.seen=s.seen.concat(s.revealed.map(function(p){return p.card;}));resolve(s);
  }
  function publicView(s){var view={phase:s.phase,stage:s.stage,turn:s.turn,players:s.players,rows:s.rows,scores:s.scores,roundPoints:s.roundPoints,round:s.round,trick:s.trick,ready:s.choices.map(function(c){return c!==null;}),revealed:s.revealed,resolved:s.resolved,pending:s.stage==='choose'?s.queue[0]:null,seen:s.seen,logs:s.logs,winner:s.winner,winners:s.winners,result:s.result};if(s.phase==='finished')view.hands=s.hands;return view;}
  function privateView(s,seat){return {seat:seat,hand:s.hands[seat],chosen:s.choices[seat]};}
  function ai(own,v){
    if(v.stage==='choose')return {action:'take',data:{row:cheapest(v.rows)}};
    // Sample unknown cards, never committed choices or opponents' hands.
    var unknown=Array.from({length:104},function(_,i){return i+1;}).filter(function(c){return own.hand.indexOf(c)<0&&v.seen.indexOf(c)<0;}),samples=[];
    for(var i=0;i<48;i++){var pool=unknown.slice(),sample=[];for(var j=0;j<3;j++)sample.push(pool.splice(Math.floor(Math.random()*pool.length),1)[0]);samples.push(sample);}
    function evaluate(card){var total=0;samples.forEach(function(sample){var rows=v.rows.map(function(r){return r.slice();}),plays=sample.map(function(c){return {card:c,us:false};});plays.push({card:card,us:true});plays.sort(function(a,b){return a.card-b.card;});plays.forEach(function(p){var row=rowFor(rows,p.card),take=row<0;if(take)row=cheapest(rows);take=take||rows[row].length===5;if(p.us&&take)total+=cost(rows[row]);if(take)rows[row]=[p.card];else rows[row].push(p.card);});});return total/samples.length+card*.0005;}
    var best=own.hand[0],score=evaluate(best);own.hand.slice(1).forEach(function(c){var next=evaluate(c);if(next<score){best=c;score=next;}});return {action:'commit',data:{card:best}};
  }
  return {title:'牛头王',seats:4,create:create,apply:apply,publicView:publicView,privateView:privateView,ai:ai,points:points,cost:cost,rowFor:rowFor,
    rules:'你与三位电脑使用 1—104 号牌。每轮每人 10 张手牌，桌面四行各放一张牌。每次各选一张暗牌，全部选定后一起揭晓，按数字从小到大处理；电脑选择时看不到你的暗牌。\n牌必须接到小于它、且差值最小的行尾。放上第六张时，收走该行原有五张牌，新牌成为行首。若比所有行尾都小，必须自选一行收走，再放入自己的牌。收来的牌只计罚分，不进入手牌。\n普通牌 1 分，5 的倍数 2 分，10 的倍数 3 分，11 的倍数 5 分，55 特殊为 7 分。罚分越少越好。\n每轮出完 10 张后重新发牌；在一轮结束时有人累计达到 66 分，整场结束，最低分获胜，同分共享胜利。'};
})();
