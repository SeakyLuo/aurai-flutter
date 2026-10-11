// Basic 108-card rules: https://service.mattel.com/instruction_sheets/M2062-0920.pdf
var Cards=(function(){
  var colors=['r','y','g','b'],names={r:'红',y:'黄',g:'绿',b:'蓝'},symbols={skip:'跳过',reverse:'反转',draw2:'+2',wild:'变色',draw4:'+4'};
  function label(c){return (names[c.color]||'')+(symbols[c.value]||c.value);}
  function random(s){s.seed=(Math.imul(s.seed,1664525)+1013904223)>>>0;return s.seed/4294967296;}
  function shuffle(s,a){for(var i=a.length-1;i>0;i--){var j=Math.floor(random(s)*(i+1)),t=a[i];a[i]=a[j];a[j]=t;}return a;}
  function log(s,seat,text){s.logs.push({seat:seat,text:text});s.logs=s.logs.slice(-12);}
  function next(s,n){return (s.turn+s.direction*(n||1)+8)%4;}
  function draw(s,seat,n){var drawn=[];for(var i=0;i<n;i++){if(!s.deck.length){var top=s.discard.pop();s.deck=shuffle(s,s.discard);s.discard=[top];}if(!s.deck.length)break;var c=s.deck.pop();s.hands[seat].push(c);drawn.push(c);}return drawn;}
  function matches(s,c){var top=s.discard[s.discard.length-1];return c.color==='k'||c.color===s.color||c.value===top.value;}
  function points(c){return c.color==='k'?50:(isNaN(Number(c.value))?20:Number(c.value));}
  function finish(s){var winner=s.hands.findIndex(function(h){return h.length===0;});if(winner<0)return;s.phase='finished';s.winner=winner;s.score=s.hands.reduce(function(n,h){return n+h.reduce(function(a,c){return a+points(c);},0);},0);log(s,winner,'获胜，获得 '+s.score+' 分');}
  function create(players,seed){
    var s={phase:'playing',stage:'play',turn:0,players:players,seed:seed>>>0,direction:1,hands:[[],[],[],[]],deck:[],discard:[],color:'r',logs:[],unoSeat:null,drawn:null,challenge:null,evidence:null,winner:null,score:0};
    var id=0;colors.forEach(function(color){for(var n=0;n<=9;n++)for(var k=0;k<(n===0?1:2);k++)s.deck.push({id:id++,color:color,value:String(n)});['skip','reverse','draw2'].forEach(function(value){for(var k=0;k<2;k++)s.deck.push({id:id++,color:color,value:value});});});
    ['wild','draw4'].forEach(function(value){for(var k=0;k<4;k++)s.deck.push({id:id++,color:'k',value:value});});shuffle(s,s.deck);
    for(var p=0;p<4;p++)draw(s,p,7);
    var top=s.deck.pop();while(top.value==='draw4'){s.deck.unshift(top);shuffle(s,s.deck);top=s.deck.pop();}s.discard.push(top);s.color=top.color;
    if(top.value==='wild')s.stage='color';
    if(top.value==='skip')s.turn=1;
    if(top.value==='draw2'){draw(s,0,2);s.turn=1;log(s,0,'起始牌 +2，摸两张并跳过');}
    if(top.value==='reverse'){s.direction=-1;s.turn=3;}
    return s;
  }
  function apply(s,seat,action,data){
    if(s.phase!=='playing'||seat!==s.turn)throw Error('尚未轮到你');
    if(action==='catch'){
      if(s.unoSeat===null)throw Error('无人漏喊 UNO');draw(s,s.unoSeat,2);log(s,s.unoSeat,'漏喊 UNO，被抓到并摸两张');s.unoSeat=null;return;
    }
    if(s.evidence&&s.evidence.seat===seat)s.evidence=null;
    if(s.stage==='color'){
      if(action!=='color'||colors.indexOf(data.color)<0)throw Error('请选择当前颜色');s.color=data.color;s.stage='play';log(s,seat,'选择'+names[s.color]+'色');return;
    }
    if(s.stage==='challenge'){
      if(action!=='accept'&&action!=='challenge')throw Error('请接受 +4 或质疑');
      var q=s.challenge;s.unoSeat=null;
      if(action==='challenge'){
        s.evidence={seat:seat,hand:q.hand,offender:q.seat,illegal:q.illegal};
        if(q.illegal){draw(s,q.seat,4);log(s,seat,'质疑成功，对方摸四张');}
        else{draw(s,seat,6);log(s,seat,'质疑失败，摸六张并跳过');s.turn=next(s);}
      }else{draw(s,seat,4);log(s,seat,'接受 +4，摸四张并跳过');s.turn=next(s);}
      s.challenge=null;s.stage='play';finish(s);return;
    }
    if(action==='draw'){
      if(s.stage!=='play')throw Error('本回合已摸牌');s.unoSeat=null;
      var cards=draw(s,seat,1);log(s,seat,'摸一张');
      if(cards.length&&matches(s,cards[0])){s.stage='drawn';s.drawn=cards[0].id;}
      else{s.turn=next(s);s.drawn=null;}return;
    }
    if(action==='pass'){
      if(s.stage!=='drawn')throw Error('摸牌后才能保留并结束回合');s.turn=next(s);s.stage='play';s.drawn=null;s.unoSeat=null;return;
    }
    if(action!=='play')throw Error('无效的出牌操作');
    var index=s.hands[seat].findIndex(function(c){return c.id===data.card;});if(index<0)throw Error('手中没有这张牌');
    var card=s.hands[seat][index];if(!matches(s,card)||(s.stage==='drawn'&&card.id!==s.drawn))throw Error('这张牌当前不能出');
    if(card.color==='k'&&colors.indexOf(data.color)<0)throw Error('请选择下一轮颜色');
    var prior=s.hands[seat].slice(),illegal=prior.some(function(c){return c.color===s.color;});
    s.unoSeat=null;s.hands[seat].splice(index,1);s.discard.push(card);s.color=card.color==='k'?data.color:card.color;s.stage='play';s.drawn=null;
    log(s,seat,'打出 '+label(card)+(card.color==='k'?'，选择'+names[s.color]+'色':'')+(s.hands[seat].length===1&&data.uno?' · UNO！':''));
    if(s.hands[seat].length===1&&!data.uno)s.unoSeat=seat;
    if(card.value==='reverse')s.direction*=-1;
    var victim=next(s);
    if(card.value==='draw4'){s.challenge={seat:seat,hand:prior,illegal:illegal};s.turn=victim;s.stage='challenge';return;}
    if(card.value==='draw2'){draw(s,victim,2);log(s,victim,'摸两张并跳过');s.turn=next(s,2);}
    else s.turn=next(s,card.value==='skip'?2:1);
    finish(s);
  }
  function publicView(s){return {phase:s.phase,stage:s.stage,turn:s.turn,players:s.players,direction:s.direction,color:s.color,top:s.discard[s.discard.length-1],counts:s.hands.map(function(h){return h.length;}),logs:s.logs,unoSeat:s.unoSeat,winner:s.winner,score:s.score,challenged:s.challenge?s.challenge.seat:null};}
  function privateView(s,seat){return {seat:seat,hand:s.hands[seat],playable:s.phase==='playing'&&s.turn===seat&&(s.stage==='play'||s.stage==='drawn')?s.hands[seat].filter(function(c){return matches(s,c)&&(s.stage!=='drawn'||c.id===s.drawn);}).map(function(c){return c.id;}):[],evidence:s.evidence&&s.evidence.seat===seat?s.evidence:null};}
  function ai(own,v){
    if(v.unoSeat!==null)return {action:'catch',data:{}};
    var count={r:0,y:0,g:0,b:0};own.hand.forEach(function(c){if(c.color!=='k')count[c.color]++;});var color=colors.slice().sort(function(a,b){return count[b]-count[a];})[0];
    if(v.stage==='color')return {action:'color',data:{color:color}};
    if(v.stage==='challenge')return {action:'accept',data:{}};
    var legal=own.hand.filter(function(c){return own.playable.indexOf(c.id)>=0;});
    // The AI never inspects opponents' hands, and does not bluff with an illegal +4.
    var honest=legal.filter(function(c){return c.value!=='draw4'||!own.hand.some(function(h){return h.color===v.color;});});
    var choice=honest.sort(function(a,b){function rank(c){return (c.color==='k'?-12:count[c.color]*3)+(c.value==='skip'||c.value==='draw2'?8:0)+points(c)/10;}return rank(b)-rank(a);})[0];
    if(choice)return {action:'play',data:{card:choice.id,color:color,uno:true}};
    return {action:v.stage==='drawn'?'pass':'draw',data:{}};
  }
  return {title:'UNO',seats:4,create:create,apply:apply,publicView:publicView,privateView:privateView,ai:ai,label:label,rules:'四人经典 108 张牌，每人 7 张。按颜色、数字或符号接牌，也可主动摸一张；摸后只能打出刚摸到的牌，或保留结束回合。+2 和 +4 不叠加。+4 仅在手中没有当前颜色时合法，下家可质疑：成功则出牌者摸 4 张，失败则质疑者摸 6 张并跳过。打到剩一张时勾选喊 UNO，漏喊可被下家抓到罚 2 张。反转改变顺序，跳过使下家停一回合。末张罚牌结算后结束。本模式为单局计分，数字按牌面、功能牌 20 分、万能牌 50 分，不进行累计 500 分赛。'};
})();
