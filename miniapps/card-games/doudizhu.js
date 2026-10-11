// Classic three-player Dou Dizhu: called-score bidding and non-gambling scores.
// Rules reference: https://www.gameabc.com/news/201907/5588.html
var Cards=(function(){
  var labels=['3','4','5','6','7','8','9','10','J','Q','K','A','2','小王','大王'];
  var names={single:'单张',pair:'对子',triple:'三张',tripleSingle:'三带一',triplePair:'三带二',straight:'顺子',pairs:'连对',plane:'飞机',planeSingle:'飞机带单',planePair:'飞机带对',fourSingle:'四带二',fourPair:'四带两对',bomb:'炸弹',rocket:'火箭'};
  function rank(id){return id<52?Math.floor(id/4):id-39;}
  function sorted(hand){return hand.slice().sort(function(a,b){return rank(a)-rank(b)||a-b;});}
  function groups(hand){var g=Array.from({length:15},function(){return [];});hand.forEach(function(c){g[rank(c)].push(c);});return g;}
  function require(ok,message){if(!ok)throw new Error(message);}
  function combinations(items,n,visit,start,picked){start=start||0;picked=picked||[];if(!n){visit(picked);return;}for(var i=start;i<=items.length-n;i++)combinations(items,n-1,visit,i+1,picked.concat([items[i]]));}
  function beats(a,b){return !b||a.type==='rocket'||(a.type==='bomb'&&b.type!=='rocket'&&(b.type!=='bomb'||a.high>b.high))||(a.type===b.type&&a.cards.length===b.cards.length&&a.high>b.high);}
  function moves(hand,last){
    var g=groups(hand),out=[];
    function add(type,high,cards){var m={type:type,high:high,cards:cards};if(beats(m,last))out.push(m);}
    function wings(type,high,core,n,size){var available=[];g.forEach(function(v,r){if(core.indexOf(r)<0&&v.length>=size)available.push(r);});combinations(available,n,function(rs){var cards=[];core.forEach(function(r){cards=cards.concat(g[r].slice(0,3));});rs.forEach(function(r){cards=cards.concat(g[r].slice(0,size));});add(type,high,cards);});}
    g.forEach(function(v,r){
      if(v.length)add('single',r,v.slice(0,1));
      if(v.length>=2)add('pair',r,v.slice(0,2));
      if(v.length>=3){add('triple',r,v.slice(0,3));wings('tripleSingle',r,[r],1,1);wings('triplePair',r,[r],1,2);}
      if(v.length===4){add('bomb',r,v.slice());[1,2].forEach(function(size){var others=[];g.forEach(function(w,k){if(k!==r&&w.length>=size)others.push(k);});combinations(others,2,function(rs){add(size===1?'fourSingle':'fourPair',r,v.concat(g[rs[0]].slice(0,size),g[rs[1]].slice(0,size)));});});}
    });
    if(g[13].length&&g[14].length)add('rocket',14,[g[13][0],g[14][0]]);
    [1,2,3].forEach(function(size){var minimum=size===1?5:size===2?3:2;for(var start=0;start<12;start++){var core=[],cards=[];for(var end=start;end<12&&g[end].length>=size;end++){core.push(end);cards=cards.concat(g[end].slice(0,size));if(core.length<minimum)continue;add(size===1?'straight':size===2?'pairs':'plane',end,cards.slice());if(size===3){wings('planeSingle',end,core,core.length,1);wings('planePair',end,core,core.length,2);}}}});
    return out;
  }
  function rng(seed){var x=seed>>>0;return function(){x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296;};}
  function deal(s){var deck=Array.from({length:54},function(_,i){return i;}),random=rng(s.seed+s.deals*7919);for(var i=53;i>0;i--){var j=Math.floor(random()*(i+1)),c=deck[i];deck[i]=deck[j];deck[j]=c;}s.hands=[sorted(deck.slice(0,17)),sorted(deck.slice(17,34)),sorted(deck.slice(34,51))];s.bottom=deck.slice(51);s.stage='bid';s.bid=0;s.bids=[null,null,null];s.landlord=null;s.turn=s.deals%3;s.firstBid=s.turn;s.deals++;s.last=null;s.passes=0;s.multiplier=1;s.playCounts=[0,0,0];s.table=[null,null,null];}
  function log(s,seat,text){s.logs.push({seat:seat,text:text});s.logs=s.logs.slice(-12);}
  function create(players,seed){var s={phase:'playing',players:players,seed:seed,deals:0,logs:[],winner:null,result:'',scores:[0,0,0]};deal(s);return s;}
  function launch(s){s.stage='play';s.turn=s.landlord;s.hands[s.landlord]=sorted(s.hands[s.landlord].concat(s.bottom));s.table=[null,null,null];log(s,s.landlord,'成为地主');}
  function classify(hand,cards,last){var ranks=cards.map(rank).sort(function(a,b){return a-b;}).join(',');return moves(hand,last).find(function(m){return m.cards.map(rank).sort(function(a,b){return a-b;}).join(',')===ranks;});}
  function apply(s,seat,action,d){
    require(s.phase==='playing','本局已经结束');require(seat===s.turn,'还没轮到你');
    if(s.stage==='bid'){
      require(action==='bid','请先叫分');require(Number.isInteger(d.score)&&(d.score===0||(d.score>s.bid&&d.score<=3)),'请选择更高的分数，或不叫');
      s.bids[seat]=d.score;s.table[seat]={text:d.score?'叫 '+d.score+' 分':'不叫'};log(s,seat,s.table[seat].text);
      if(d.score){s.bid=d.score;s.landlord=seat;}
      if(d.score===3||s.bids.every(function(v){return v!==null;})){if(s.landlord===null){log(s,seat,'无人叫分，重新发牌');deal(s);}else launch(s);}else s.turn=(seat+1)%3;
      return;
    }
    if(action==='pass'){
      require(s.last&&s.last.seat!==seat,'你领出时不能不出');s.passes++;s.table[seat]={text:'不出'};log(s,seat,'不出');s.turn=(seat+1)%3;
      if(s.passes===2){s.turn=s.last.seat;s.last=null;s.passes=0;s.table=[null,null,null];}
      return;
    }
    require(action==='play','不支持的出牌操作');require(Array.isArray(d.cards)&&d.cards.length>0&&new Set(d.cards).size===d.cards.length,'请选择要出的牌');
    require(d.cards.every(function(c){return s.hands[seat].indexOf(c)>=0;}),'所选牌不在你的手牌中');
    var m=classify(s.hands[seat],d.cards,s.last);require(m,'牌型不成立，或不能压过上一手');
    m.cards=sorted(d.cards);m.seat=seat;s.last=m;s.passes=0;s.table[seat]={cards:m.cards,type:m.type};s.playCounts[seat]++;s.hands[seat]=s.hands[seat].filter(function(c){return d.cards.indexOf(c)<0;});
    if(m.type==='bomb'||m.type==='rocket')s.multiplier*=2;
    log(s,seat,names[m.type]+' '+m.cards.map(function(c){return labels[rank(c)];}).join(' '));
    if(!s.hands[seat].length){s.phase='finished';s.winner=seat;var landlordWon=seat===s.landlord;var spring=landlordWon?s.playCounts.every(function(n,i){return i===s.landlord||n===0;}):s.playCounts[s.landlord]===1;if(spring)s.multiplier*=2;var value=s.bid*s.multiplier;s.scores=s.players.map(function(_,i){return(i===s.landlord?2:-1)*value*(landlordWon?1:-1);});s.result=(landlordWon?'地主获胜':'农民获胜')+(spring?' · '+(landlordWon?'春天':'反春天'):'');log(s,seat,s.result);}else s.turn=(seat+1)%3;
  }
  function publicView(s){return {phase:s.phase,stage:s.stage,turn:s.turn,players:s.players,counts:s.hands.map(function(h){return h.length;}),bids:s.bids,bid:s.bid,landlord:s.landlord,bottom:s.stage==='bid'?[]:s.bottom,last:s.last,table:s.table,multiplier:s.multiplier,playCounts:s.playCounts,logs:s.logs,winner:s.winner,result:s.result,scores:s.scores};}
  function privateView(s,seat){return {seat:seat,hand:s.hands[seat],legalMoves:s.phase==='playing'&&s.stage==='play'&&s.turn===seat?moves(s.hands[seat],s.last):[]};}
  function ai(own,v){
    if(v.stage==='bid'){var g=groups(own.hand),power=g[12].length*1.4+g[13].length*2+g[14].length*3+g.filter(function(c){return c.length===4;}).length*3;var score=power>=8?3:power>=5?2:power>=3?1:0;return {action:'bid',data:{score:score>v.bid?score:0}};}
    var legal=own.legalMoves;if(!legal.length)return {action:'pass',data:{}};
    var finishing=legal.find(function(m){return m.cards.length===own.hand.length;});if(finishing)return {action:'play',data:{cards:finishing.cards}};
    var teammate=v.last&&own.seat!==v.landlord&&v.last.seat!==v.landlord;
    if(teammate&&(v.counts[v.last.seat]<=3||v.last.high>=9))return {action:'pass',data:{}};
    var handGroups=groups(own.hand),threat=v.counts[v.landlord]===1&&own.seat!==v.landlord||own.seat===v.landlord&&v.counts.some(function(n,i){return i!==own.seat&&n===1;});
    function cost(m){var value=m.high*.8-m.cards.length*3;if(m.type==='bomb'||m.type==='rocket')value+=24;var used=groups(m.cards);used.forEach(function(c,r){if(c.length&&c.length<handGroups[r].length)value+=(handGroups[r].length===4?15:handGroups[r].length===3?5:2);});if(threat&&m.type==='single')value-=m.high*2;if(teammate)value+=m.high*1.5;return value;}
    legal=legal.slice().sort(function(a,b){return cost(a)-cost(b);});if(teammate&&legal[0].cards.length<5)return {action:'pass',data:{}};return {action:'play',data:{cards:legal[0].cards}};
  }
  return {title:'斗地主',seats:3,rules:'三人斗地主，一人对两名农民。按顺序叫 1—3 分，只能加叫或不叫；无人叫分重新发牌。地主取得三张底牌并先出。支持单张、对子、三张、三带一/对、顺子（至少五张）、连对（至少三对）、飞机及带翅膀、四带二/两对、炸弹、火箭。顺子和飞机不含 2 与王；带单牌须点数各异，翅膀不能与主体重复。必须以相同牌型及张数压过上一手，炸弹可压普通牌，火箭最大。连续两人不出后，由上一手领出。地主先出完则地主胜，否则农民共同获胜。炸弹、火箭、春天和反春天各翻倍；分数仅为本局游戏记录。',create:create,apply:apply,publicView:publicView,privateView:privateView,ai:ai,rank:rank,labels:labels,names:names,moves:moves,classify:classify};
})();
