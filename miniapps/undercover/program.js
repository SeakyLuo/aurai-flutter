var s=ctx.state,e=ctx.event,d=e.data,roster=ctx.members;
function check(ok,text){if(!ok)throw new Error(text);}
function member(id){return roster.find(function(m){return m.id===id;});}
function manager(){return e.actorId===ctx.ownerId||e.actorId==='user:local'||e.actorId===s.hostId;}
function alive(){return s.players.filter(function(p){return p.alive;});}
function player(id){return s.players.find(function(p){return p.id===id;});}
function name(p){return p.seat+'号 '+p.name;}
function announce(text){host.call('messages.send',{text:text});}
function record(title,text){s.timeline.push({round:s.round,title:title,text:text});}
function closeCards(){if(s.cardKey){host.call('cards.close',{keys:[s.cardKey]});s.cardKey=null;}}
function finish(winner){
  closeCards();s.phase='finished';s.winner=winner;s.seq++;
  var text=winner==='cancelled'?'本局已结束':winner==='civilian'?'平民获胜':'卧底获胜';
  if(s.words)text+='。平民词：'+s.words.civilian+'；卧底词：'+s.words.undercover+'。';
  record(text,'');announce(text);host.call('replies.release',{});
}
function victory(){
  var remaining=alive(),under=remaining.filter(function(p){return p.role==='undercover';}).length;
  if(!under){finish('civilian');return true;}
  if(under>=remaining.length-under){finish('undercover');return true;}
  return false;
}
function controls(){
  var states={};roster.filter(function(m){return m.kind==='agent'&&(m.id===s.hostId||!!player(m.id));}).forEach(function(m){
    states[m.id]=s.phase==='words'?m.id===s.hostId:s.phase==='speech'?m.id===s.order[s.index]:s.phase==='vote'&&!!player(m.id)&&player(m.id).alive&&s.votes[m.id]===undefined;
  });host.call('replies.set',{states:states});
}
function wake(id,text){if(member(id).kind==='agent')host.call('messages.send',{text:text,audience:[id],wakeAi:true,wakeMemberIds:[id]});}
function nextSpeaker(){
  s.seq++;var p=player(s.order[s.index]);s.cardKey='speech:'+s.seq;
  host.call('messages.send',{key:s.cardKey,event:'speechEnded',data:{seq:s.seq},audience:null,
    requirePublicMessage:true,wakeAi:member(p.id).kind==='agent',wakeMemberIds:member(p.id).kind==='agent'?[p.id]:[],
    card:{title:'轮到'+name(p)+'描述',body:'请直接在群里描述自己的词语，不要说出词语本身；说完后结束发言。',
      buttons:[{id:'done',label:'结束发言',action:'submit',repeatable:false}],
      interaction:{actors:[p.id],allowChange:false,reveal:'immediate',views:[]},
      participation:{visibility:'public',summaryVisibility:'public'}}});
}
function speech(order,pk){
  closeCards();s.phase='speech';s.order=order;s.index=0;s.pk=pk;s.spoken={};
  record(pk?'平票加赛':'第'+s.round+'轮描述',order.map(function(id){return name(player(id));}).join('、'));
  nextSpeaker();
}
function vote(){
  s.phase='vote';s.seq++;s.votes={};s.cardKey='vote:'+s.seq;
  var actors=alive().map(function(p){return p.id;}),options=s.candidates.map(function(id){return {id:id,label:name(player(id)),value:id};});
  options.push({id:'skip',label:'弃权',value:'skip'});
  record('投票',s.pk?'平票候选人再次投票':'投出你认为的卧底');
  host.call('messages.send',{key:s.cardKey,event:'vote',data:{seq:s.seq},audience:null,
    wakeAi:actors.some(function(id){return member(id).kind==='agent';}),wakeMemberIds:actors.filter(function(id){return member(id).kind==='agent';}),
    card:{title:'第'+s.round+'轮'+(s.pk?' · 平票重投':' · 找出卧底'),body:'票数收齐后公开；可以弃权。',showStatistics:true,
      buttons:[{id:'vote',label:'提交投票',action:'submit',repeatable:false,selection:{optionPrefix:'dot',mode:'single',options:options}}],
      interaction:{actors:actors,allowChange:false,reveal:'onComplete',completion:{op:'eq',args:[{ref:'submittedCount'},actors.length]},views:[{type:'distribution',unit:'票'}]},
      participation:{visibility:'public',summaryVisibility:'public'}}});
}
function tally(){
  closeCards();var counts={};Object.keys(s.votes).forEach(function(id){var target=s.votes[id];if(target!=='skip')counts[target]=(counts[target]||0)+1;});
  var max=Math.max.apply(null,[0].concat(Object.keys(counts).map(function(id){return counts[id];}))),top=s.candidates.filter(function(id){return counts[id]===max;});
  var detail=alive().map(function(p){return name(p)+' → '+(s.votes[p.id]==='skip'?'弃权':name(player(s.votes[p.id])));}).join('\n');
  record('投票结果',detail);announce(detail);
  if(max>0&&top.length===1){
    var out=player(top[0]);out.alive=false;out.eliminatedRound=s.round;
    var text=name(out)+'出局，身份是'+(out.role==='undercover'?'卧底':'平民');record('玩家出局',text);announce(text);
    if(victory())return;
  }else if(max>0&&!s.pk){
    s.candidates=top;announce('平票，候选人各补充一句描述后重新投票。');speech(top,true);return;
  }else{announce(max===0?'全员弃权，本轮无人出局。':'再次平票，本轮无人出局。');}
  s.round++;s.candidates=alive().map(function(p){return p.id;});speech(s.candidates.slice(),false);
}
if(e.action==='configure'){
  check(!s.phase,'本局已经创建');check(e.actorId===ctx.ownerId||e.actorId==='user:local','只有发起人可以开局');
  check(member(d.hostId)&&member(d.hostId).kind==='agent','请选择一位 AI 主持人');
  check(Array.isArray(d.players)&&d.players.length>=3&&d.players.length<=16,'请选择 3–16 位玩家');
  check(d.players.every(function(id,i){return !!member(id)&&id!==d.hostId&&d.players.indexOf(id)===i;}),'玩家必须在当前聊天中且不能重复，主持人不参赛');
  check(Number.isInteger(d.undercoverCount)&&d.undercoverCount>=1&&d.undercoverCount*2<d.players.length,'卧底至少 1 人，且人数须少于平民');
  s={phase:'words',hostId:d.hostId,players:d.players.map(function(id,i){return {id:id,name:member(id).name,seat:i+1,alive:true};}),undercoverCount:d.undercoverCount,round:1,seq:1,timeline:[],cardKey:null,words:null,winner:null};
  host.call('messages.setHost',{senderId:s.hostId});host.call('messages.mark',{});
  record('谁是卧底开始','等待主持人出题');
  wake(s.hostId,'请为谁是卧底准备一对相近但不同的词。只用 submitHtmlProgramEvent action:setWords data:{seq:1,civilian:平民词,undercover:卧底词} 私密提交，禁止在聊天正文、说明或公开消息中说出词语。程序负责随机发词和后续流程，不需要主持代玩家行动。');
}else{
  check(!!s.phase,'请先创建对局');
  if(e.action==='stop'){
    check(manager(),'只有主持人或发起人可以结束本局');check(s.phase!=='finished','本局已经结束');finish('cancelled');
  }else if(e.action==='setWords'){
    check(e.actorId===s.hostId&&s.phase==='words'&&d.seq===s.seq,'当前不能提交词语');
    check(typeof d.civilian==='string'&&typeof d.undercover==='string','请提供两组词语');
    var civilian=d.civilian.trim(),undercover=d.undercover.trim();
    check(civilian.length>=1&&civilian.length<=30&&undercover.length>=1&&undercover.length<=30&&civilian!==undercover,'两个词须不同，各 1–30 字');
    s.words={civilian:civilian,undercover:undercover};var shuffled=s.players.slice();
    for(var i=shuffled.length-1;i>0;i--){var j=Math.floor(Math.random()*(i+1)),temp=shuffled[i];shuffled[i]=shuffled[j];shuffled[j]=temp;}
    shuffled.forEach(function(p,i){p.role=i<s.undercoverCount?'undercover':'civilian';p.word=s.words[p.role];});
    s.players.forEach(function(p){host.call('messages.send',{text:'你的词语：'+p.word+'。不知道自己的阵营，请根据大家的描述推理；不要直接说出词语。',audience:[p.id],wakeAi:false});});
    announce('词语已私密发放，按座位顺序各描述一句；全部描述后投票。');
    s.candidates=alive().map(function(p){return p.id;});speech(s.candidates.slice(),false);
  }else if(e.action==='playerMessage'){
    check(s.phase==='speech'&&s.order[s.index]===e.actorId,'当前没有轮到你描述');
    check(s.spoken[e.actorId]===undefined,'本轮已经描述，请提交结束发言卡');
    check(typeof d.text==='string'&&d.text.trim().length>0&&d.text.length<=300,'请用 1–300 字描述自己的词语');
    var text=d.text.trim(),p=player(e.actorId);
    check(text.indexOf(p.word)<0,'描述不能直接包含自己的词语');
    record(name(p)+'描述',text);host.call('messages.send',{text:text,senderId:e.actorId,markdown:false});
    s.spoken[p.id]=text;
  }else if(e.action==='speechEnded'){
    check(s.phase==='speech'&&s.order[s.index]===e.actorId&&d.context.seq===s.seq,'发言卡已过期或还没有轮到你');
    if(member(e.actorId).kind==='agent')check(s.spoken[e.actorId]!==undefined,'请先在群里描述，再结束发言');
    else record(name(player(e.actorId))+'描述','已在群内发言');
    closeCards();s.index++;
    if(s.index<s.order.length)nextSpeaker();else vote();
  }else if(e.action==='vote'){
    check(s.phase==='vote'&&d.context.seq===s.seq,'投票已过期');
    var voter=player(e.actorId),value=d.value;
    check(voter&&voter.alive&&s.votes[voter.id]===undefined,'你不能重复投票或已出局');
    check(value==='skip'||s.candidates.indexOf(value)>=0,'请选择本轮候选人或弃权');s.votes[voter.id]=value;
    if(alive().every(function(p){return s.votes[p.id]!==undefined;}))tally();
  }else throw new Error('不支持的对局操作');
}
s.players.forEach(function(p){var current=member(p.id);if(current)p.name=current.name;});
if(s.phase!=='finished'){
  controls();host.call('messages.intercept',{actors:s.players.filter(function(p){return member(p.id)&&member(p.id).kind==='agent';}).map(function(p){return p.id;}),action:'playerMessage'});
}
var hostProtocol='你是主持人，不参赛。仅在 phase=words 时想一对相近但不同、有共同特征的词，用 setWords data:{seq,civilian,undercover} 提交。词语只能提交给程序，不得在公开正文中透露。程序随机分配、按顺序收集描述、投票、平票加赛、淘汰并判胜，之后无需主持推进，不轮询或代玩家操作。';
var playerProtocol='你是谁是卧底玩家，只知道自己的 word，不知道阵营。读取最新状态和群聊公开描述，不能读主持人视角或其他玩家词语。轮到你时用 sendGroupMessage 直接在群里描述一句，不含自己的词语，不要通过小程序事件提交描述；发送成功后用 clickInteractiveMessage 提交对应结束发言卡，才会轮到下一位。vote 阶段用对应原生投票卡 clickInteractiveMessage 投票；不要另发确认、私密词语或长篇思考。不轮询、不重复发言；出局后只观战，结束后才公开词语。';
var privateViews={};privateViews[s.hostId]={isHost:true,canEditData:true,words:s.words,players:s.players,protocol:hostProtocol};
s.players.forEach(function(p){privateViews[p.id]={word:p.word||null,alive:p.alive,canSpeak:s.phase==='speech'&&s.order[s.index]===p.id,seq:s.seq,protocol:playerProtocol};});
return {state:s,view:{title:'谁是卧底',phase:s.phase,hostId:s.hostId,round:s.round,seq:s.seq,undercoverCount:s.undercoverCount,
  players:s.players.map(function(p){return {id:p.id,name:name(p),alive:p.alive,role:!p.alive||s.phase==='finished'?p.role:null,word:s.phase==='finished'?p.word:null};}),
  speaker:s.phase==='speech'?s.order[s.index]:null,candidates:s.candidates||[],submittedCount:s.phase==='vote'?Object.keys(s.votes).length:0,
  timeline:s.timeline,winner:s.winner,words:s.phase==='finished'?s.words:null},privateViews:privateViews};
