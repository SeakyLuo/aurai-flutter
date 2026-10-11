const Office = (() => {
  const R=OfficeRules,B=OfficeBoard,W=OfficeWork;
  function create(seed,carry=null,carriedItem=null) {
    const s={rng:seed>>>0,sequence:0,day:1,phase:0,status:'playing',moves:R.config.moves,score:0,
      patience:R.config.patience,coins:R.config.startingCoins,board:Array(16).fill(null),props:Array(16).fill(null),
      zones:Array.from({length:16},()=>({types:[],water:0,glue:0,glueTurns:5,collapse:6})),
      deck:[1,1,1,1,1,1,2,2,2,4].map(value=>B.card(value)),pool:[],nextCard:null,preview:null,barriers:[],
      stats:{organized:0,merges:0,dry:0,sticky:0,waste:0},phaseStats:{dry:0,sticky:0},
      turn:0,slacks:0,totalSlacks:0,slackEmpty:false,items:[],pendingItems:[],demands:[],fatigues:[],welfare:[],reward:null,completionReward:null,acceptedDemands:0,freeRemovals:0,forcedOnes:0,fatigueShield:0,coffeeRebound:false,energyRebound:false,
      stock:[],shopUnlocked:false,shopBlocked:false,deckPurchases:0,pending:null,
      campaign:OfficeCampaign.create(),notices:[],summary:null,log:[],cleanings:0,reason:null,outsideMagnets:[],delayed:[],demandSlots:2};
    s.board[0]=B.fromCard(s,B.draw(s));s.board[12]=B.fromCard(s,B.draw(s));s.props[5]='tea';
    if(carry)OfficeWelfare.add(s,carry);
    if(carriedItem)s.items.push({...carriedItem});
    s.nextCard=B.draw(s);B.preview(s);startPhase(s);return s;
  }
  const target=s=>Math.ceil(R.config.targets[s.day-1][s.phase]*(OfficeWelfare.active(s,'kpi')?.75:1));
  function startPhase(s) {
    const cells=B.empty(s);if(cells.length)B.zone(s,cells[B.random(s,cells.length)],'glue');
    s.zonePreview={cell:B.random(s,16),type:'glue',at:50};
    s.moves=R.config.moves;s.score=0;s.phaseStats={dry:0,sticky:0};s.slacks=0;s.slackEmpty=false;s.shopBlocked=false;s.demandSlots=2;
    const phase=s.day*3+s.phase;
    s.fatigues=s.fatigues.filter(f=>f.deadline?f.deadline>phase:s.phase!==0);
    if(s.phase===2&&!OfficeWelfare.active(s,'rest')&&!OfficeWelfare.active(s,'chair')){
      if(s.fatigues.length){for(const f of s.fatigues)if(!f.deadline)f.turns*=2;}
      else W.fatigue(s,null,R.config.nightFatigueTurns);
    }
    if(s.phase===2&&OfficeWelfare.active(s,'night'))s.demandSlots++;
    W.stock(s);OfficeCampaign.enterPhase(s);s.pending=null;

  }
  function checkEnd(s) {
    if(s.status==='lost'||s.patience<=0){s.patience=Math.max(0,s.patience);s.status='lost';OfficeInheritance.prepare(s);return;}
    if(s.status!=='playing')return;
    if(s.score>=target(s)||s.moves<=0){
      const success=s.score>=target(s);
      if(!success)s.patience=Math.max(0,s.patience-R.config.penalty);
      s.summary={day:s.day,phase:s.phase,score:s.score,target:target(s),success,
        patience:s.patience,dry:s.phaseStats.dry,sticky:s.phaseStats.sticky};
      s.log.push({...s.summary});
      s.status=s.patience===0?'lost':s.day===R.config.days&&s.phase===2?'won':'summary';
      OfficeCampaign.ended(s);if(s.status==='lost')OfficeInheritance.prepare(s);else OfficeWelfare.reward(s);
    }
  }
  function advance(s) {
    if(s.status!=='summary')throw Error('当前阶段尚未结束');
    if(s.reward)throw Error('请先领取阶段奖励');
    const oldPhase=s.day*3+s.phase,oldDay=s.day;
    OfficeWelfare.expire(s,oldPhase,oldDay);
    s.items=s.items.filter(a=>!(a.rental==='phase'&&a.expires<=oldPhase)&&!(a.rental==='day'&&s.phase===2&&a.expires<=oldDay));
    s.phase++;if(s.phase===3){s.day++;s.phase=0;}
    s.status='playing';startPhase(s);
  }
  function publish(s) {
    const notices=s.notices.slice();s.notices=[];
    return notices;
  }
  function usable(o,s) {
    return !o.frozen && (!o.charge||s.items.some(a=>a.key==='glove'&&!a.polluted)) &&
      (o.attach.includes('wheels')||o.attach.includes('booster')||!o.attach.some(a=>['woodStand','metalStand','tape'].includes(a)));
  }
  function compatible(a,b) {
    if(!R.isFile(a)||!R.isFile(b)||!!a.wet!==!!b.wet)return false;
    if(a.kind==='waste'||b.kind==='waste')return a.kind===b.kind&&a.value===b.value;
    return a.value===b.value||['copy','cancel'].some(kind=>R.effect(a,kind)||R.effect(b,kind));
  }
  function connection(s,from,to){
    if(from===to||B.crossesBarrier(s,from,to))return false;
    const dx=to%4-from%4,dy=Math.floor(to/4)-Math.floor(from/4),steps=Math.max(Math.abs(dx),Math.abs(dy));
    for(let n=1;n<steps;n++){
      const i=Math.round(Math.floor(from/4)+dy*n/steps)*4+Math.round(from%4+dx*n/steps);
      if(s.board[i])return false;
    }
    return true;
  }
  function blocked(s,a,b) {
    return B.crossesBarrier(s,a,b);
  }
  function pickupPlan(s,hosts,recipient){
    if(recipient.bossDelivery)throw Error('这是老板的道具，请用清水洗净后送回');
    const key=R.itemKey(recipient);
    if(recipient.kind==='parcel'&&!recipient.opened)throw Error('先将外卖袋移动到空格，再拆开收集');
    if(recipient.charge&&!s.items.some(a=>a.key==='glove'&&!a.polluted))throw Error('先准备绝缘手套再接触带电物品');
    const host={kind:hosts[0].kind,attach:[...new Set(hosts.flatMap(o=>o.attach))]};
    return {key,attach:!recipient.polluted&&R.canAttach(key,host)};
  }
  function receive(s,plan,recipient){
    if(!plan.attach){
      W.addItem(s,plan.key,{polluted:recipient.polluted,spoiled:recipient.spoiled});
      s.notices.push(recipient.polluted?'已收好受污染的道具，放回桌面用清水洗净后才能使用。':'已收好 '+R.items[plan.key].name+'。');
    }
  }
  function linkedMove(s,start,dest) {
    const group=B.linked(s,start),dx=dest%4-start%4,dy=Math.floor(dest/4)-Math.floor(start/4);
    const targets=group.map(i=>{const x=i%4+dx,y=Math.floor(i/4)+dy;return x<0||x>3||y<0||y>3?-1:y*4+x;});
    if(targets.includes(-1))throw Error('黏连体不能移出桌面');
    for(let k=0;k<group.length;k++){
      const i=group[k],j=targets[k],o=s.board[i];
      if(!usable(o,s))throw Error('黏连体中有固定、冰冻或无法接触的带电物品');
      const other=!group.includes(j)?s.board[j]:null;
      if(other&&!R.collectible(other)&&(!compatible(o,other)||!usable(other,s)))throw Error('黏连体遇到了无法合并的物品');
      if(other&&!R.collectible(other)&&R.fatigue(s,'noMerge'))throw Error('疲劳期间无法合并，请将黏连体移到空处');
      if(!R.isFile(o)&&R.tier(o)>=2&&!o.attach.some(a=>['wheels','booster'].includes(a))&&!R.adjacent(i,j))throw Error('黏连体中的重物每次只能移动一格');
      if(!R.isFile(o)&&R.tier(o)===3&&!o.attach.some(a=>['wheels','booster'].includes(a)))throw Error('黏连体中的超重物需要滚轮或助推器');
      if(B.crossesBarrier(s,i,j))throw Error('黏连体不能穿过挡板');
    }
    return {group,targets};
  }
  function selection(s,path,dest) {
    if(s.status!=='playing'||!path.length||dest<0||dest>15)return '请选择桌面上的文件';
    if(new Set(path).size!==path.length)return '连线不能重复经过同一个文件';
    const anchor=path.map(i=>s.board[i]).find(o=>o&&!['copy','cancel'].some(kind=>R.effect(o,kind)));
    for(let k=0;k<path.length;k++){
      const o=s.board[path[k]];
      if(!o)return '连线只能经过已有物品';
      if(!usable(o,s))return o.frozen?'物品还在冰冻中':o.charge?'先准备绝缘手套再移动带电物品':'先拆除固定物或加装滚轮';
      if(k>0&&!connection(s,path[k-1],path[k]))return '文件之间的路径须为空，且不能穿过挡板';
      if(k>0&&(!compatible(s.board[path[0]],o)||(anchor&&!compatible(anchor,o))))return '请连接同值、同湿润状态的文件';
    }
    if(path.length>1&&R.fatigue(s,'noMerge'))return '疲劳期间暂时无法合并，可以移动单个文件';
    if(path.length===1&&B.linked(s,path[0]).length>1&&dest!==path[0])linkedMove(s,path[0],dest);
    const occupied=s.board[dest];
    const sameGroup=path.length===1&&B.linked(s,path[0]).length>1;
    if(occupied&&!sameGroup&&!path.includes(dest)&&!R.collectible(occupied)&&!(occupied.kind==='stone'&&occupied.brittle>0))return '终点须是空格、选中的文件或可收集道具';
    if(path.length===1&&B.crossesBarrier(s,path[0],dest))return '物品不能穿过挡板';
    if(path.length===1&&path[0]===dest)return '拖到空格移动，或连选相邻同值文件合并';
    if(path.length===1&&R.fatigue(s,'heavy')&&!R.adjacent(path[0],dest))return '疲劳期间每次只能移动一格';
    if(path.length===1&&!R.isFile(s.board[path[0]])&&!s.board[path[0]].attach.some(a=>['wheels','booster'].includes(a))){
      if(R.tier(s.board[path[0]])===3)return '超重物需要滚轮或助推器才能移动';
      if(R.tier(s.board[path[0]])===2&&!R.adjacent(path[0],dest))return '重物每次只能移动一格';
    }
    return null;
  }
  function cleanup(s) {
    // A full desk is still playable if an adjacent compatible pair can merge.
    // Collectible objects can also free a cell without consuming a move.
    if(s.items.length<R.itemLimit(s)&&s.board.some(o=>R.collectible(o)&&(o.kind!=='parcel'||o.opened)&&(!o.charge||s.items.some(a=>a.key==='glove'&&!a.polluted))))return;
    if(B.empty(s).length||s.board.some((o,i)=>o&&usable(o,s)&&B.neighbors(i).some(j=>!blocked(s,i,j)&&compatible(o,s.board[j])&&usable(s.board[j],s))))return;
    s.patience=Math.max(0,s.patience-50);s.cleanings++;
    if(!s.patience){s.status='lost';return;}
    // The confirmed cleaner rule preserves seals, clears other objects and deals two files.
    s.board=s.board.map(o=>o?.attach.includes('seal')?o:null);s.props.fill(null);s.pending=null;
    const cells=B.empty(s).filter(i=>!s.zones[i].types.includes('discard'));
    if(cells.length<2){s.status='lost';s.reason='sealed';return;}
    for(let count=0;count<2;count++){
      const i=cells.splice(B.random(s,cells.length),1)[0];
      s.board[i]=B.fromCard(s,s.nextCard);s.nextCard=B.draw(s);B.enter(s,i,s.board[i]);
    }
    B.discard(s);B.preview(s);
    s.notices.push('桌面无法整理，忍耐度扣除 50；保洁保留封条，清空其他物品并发了两份文件。');
  }
  function finishTurn(s,elapsed=1) {
    for(let n=0;n<elapsed&&s.status==='playing';n++){
      s.moves--;s.turn++;B.tick(s);
      if(s.score>=target(s)||s.patience<=0){checkEnd(s);break;}
      for(const o of s.board.filter(Boolean))o.attach=o.attach.filter(a=>a!=='tape');
      s.fatigues=s.fatigues.filter(f=>f.deadline||--f.turns>0);
      if(s.moves===50&&s.zonePreview){B.zone(s,s.zonePreview.cell,s.zonePreview.type);s.zonePreview=null;}
      W.demands(s);OfficeCampaign.flush(s);W.offer(s);
      if(s.fatigueShield&&--s.fatigueShield===0&&s.energyRebound){s.energyRebound=false;W.fatigue(s);}
      checkEnd(s);
    }
    if(s.status==='playing'){B.spawn(s);OfficeCampaign.afterAction(s);checkEnd(s);if(s.status==='playing'){cleanup(s);checkEnd(s);}}
    OfficeWelfare.endAction(s);
  }
  function merge(s,objects,dest) {
      const base=objects.find(a=>!['copy','cancel'].some(kind=>R.effect(a,kind)))||objects[0];
      const copies=objects.filter(a=>R.effect(a,'copy')).length;
      const originals=objects.filter(a=>!R.effect(a,'copy'));
      const sum=(originals.length?originals.reduce((total,a)=>total+a.value,0):base.value)*2**(originals.length?copies:copies-1);
      const cancellations=objects.filter(a=>R.effect(a,'cancel')).length;
      const cancelled=objects.some(a=>a.cancelled&&!a.polluted)||cancellations>0;
      const score=cancelled?0:sum+objects.reduce((total,a)=>total+(a.polluted?0:a.messy),0);
      const o=B.object(s,R.fatigue(s,'noGrowth')?base.value:sum,base.kind==='waste'?'waste':base.kind==='metal'?'metal':'file');
      if(cancellations===objects.length)o.value=1;
      o.cancelled=(cancellations>0||objects.every(a=>a.cancelled))&&(cancellations+objects.filter(a=>a.cancelled&&!a.polluted).length)%2===1;
      o.attach=[...new Set(objects.flatMap(a=>a.attach))];
      o.wet=Math.max(...objects.map(a=>a.wet));o.sticky=Math.max(...objects.map(a=>a.sticky));
      o.polluted=objects.some(a=>a.polluted);o.charge=Math.max(...objects.map(a=>a.charge));
      const dry=objects.filter(a=>!a.wet).length,sticky=objects.filter(a=>a.sticky).length;
      s.stats.merges++;s.stats.dry+=dry;s.stats.sticky+=sticky;s.phaseStats.dry+=dry;s.phaseStats.sticky+=sticky;
      const gain=OfficeWelfare.merged(s,o,base.kind==='waste'?0:score,objects);
      if(s.coffeeRebound){s.coffeeRebound=false;W.fatigue(s);}
      s.score+=gain;s.stats.organized+=gain;
      if(s.zones[dest].types.includes('overtime'))s.patience=Math.min(100,s.patience+1);
      if(B.random(s,100)<(R.fatigue(s,'trouble')?35:R.config.noteChance*100))o.note=true;
      OfficeCampaign.merged(s,o);return o;
  }
  function leaveFatigue(s,vacated,targets){
    const cells=[...new Set([...vacated,...B.empty(s)])].filter(i=>!s.board[i]&&!targets.includes(i));
    for(const type of ['temporary','one']){
      if(!R.fatigue(s,type)||!cells.length)continue;
      const i=cells.shift();s.board[i]=B.object(s,1);
      if(type==='temporary')s.board[i].temporary=5;
    }
  }
  function moveObject(o,from,to) {
    if(R.effect(o,'messy'))o.messy++;
    if(o.kind==='parcel')o.opened=true;
    if(o.brittle){o.brittle-=Math.max(Math.abs(from%4-to%4),Math.abs(Math.floor(from/4)-Math.floor(to/4)));if(o.brittle<=0)return null;}
    return o;
  }
  function connect(s,path,dest) {
    if(R.fatigue(s,'reverse')){
      const start=path[0],x=2*(start%4)-dest%4,y=2*Math.floor(start/4)-Math.floor(dest/4);
      if(x<0||x>3||y<0||y>3)throw Error('反向疲劳：反向落点超出桌面');dest=y*4+x;
    }
    const problem=selection(s,path,dest);if(problem)throw Error(problem);
    if(path.length===1&&B.linked(s,path[0]).length>1){
      const {group,targets}=linkedMove(s,path[0],dest),objects=group.map(i=>s.board[i]);
      const recipients=targets.map(i=>group.includes(i)?null:s.board[i]);
      const pickups=recipients.map((o,k)=>R.collectible(o)?pickupPlan(s,[objects[k]],o):null);
      const collected=pickups.filter(p=>p&&!p.attach).length;
      if(collected&&s.items.length+collected>R.itemLimit(s))throw Error('文件柜空间不足，先为整组收集留出位置');
      const merging=recipients.map((o,k)=>!!o&&!pickups[k]),sparks=recipients.map((o,k)=>o&&o.charge>0&&objects[k].charge>0);
      if(targets.some((i,k)=>recipients[k]&&s.zones[i].types.includes('approval'))){
        const key='linked@'+objects.map(o=>o.id).join(',')+'@'+dest;
        if(s.pending!==key){s.pending=key;return {approval:true};}
      }
      group.forEach(i=>{B.tip(s,i);s.board[i]=null;});
      pickups.forEach((p,k)=>{if(p)receive(s,p,recipients[k]);});
      const results=objects.map((o,k)=>{
        const result=merging[k]?merge(s,[o,recipients[k]],targets[k]):moveObject(o,group[k],targets[k]);
        if(result&&pickups[k]?.attach)result.attach.push(pickups[k].key);return result;
      });
      targets.forEach((i,k)=>{s.board[i]=results[k];});
      targets.forEach((i,k)=>{
        const o=results[k];if(!o)return;if(!(pickups[k]?.attach&&pickups[k].key==='booster'))o.attach=o.attach.filter(a=>a!=='booster');
        B.cutField(s,group[k],i,o);B.enter(s,i,o);
        if(sparks[k]){o.charge=0;B.spark(s,i);}
      });
      group.forEach((i,k)=>{if(merging[k])leaveFatigue(s,[i],targets);});
      s.pending=null;B.discard(s);OfficeWelfare.flush(s);W.demands(s,0);checkEnd(s);
      for(let k=0;k<objects.length&&s.status==='playing';k++)if(merging[k]&&((objects[k].note&&!objects[k].polluted)||(recipients[k].note&&!recipients[k].polluted))){W.event(s,[objects[k],recipients[k]].some(o=>o.note==='notebook'&&!o.polluted)?'notebook':null);W.demands(s,0);checkEnd(s);}
      if(s.status==='playing')finishTurn(s);else{s.moves=Math.max(0,s.moves-1);s.turn++;OfficeWelfare.endAction(s);}
      return {approval:false};
    }
    if(s.board[dest]?.kind==='stone'&&s.board[dest].brittle>0&&!path.includes(dest)){
      if(--s.board[dest].brittle<=0)s.board[dest]=null;
      finishTurn(s);return {approval:false};
    }
    const objects=path.map(i=>s.board[i]),recipient=s.board[dest],pickup=recipient&&!path.includes(dest);
    const plan=pickup?pickupPlan(s,objects,recipient):null;
    if(plan&&!plan.attach&&s.items.length>=R.itemLimit(s))throw Error('文件柜已满，请先使用一个道具');
    const sparks=pickup?recipient.charge>0&&objects.some(o=>o.charge>0):objects.filter(o=>o.charge>0).length>1;
    if((path.length>1||pickup)&&s.zones[dest].types.includes('approval')){
      const key=path.map(i=>s.board[i].id).sort((a,b)=>a-b).join(',')+'@'+dest;
      if(s.pending!==key){s.pending=key;return {approval:true};}
    }
    s.pending=null;
    if(objects.some(o=>!R.isFile(o))&&path.length>1)throw Error('只有文件可以连线合并');
    if(plan)receive(s,plan,recipient);
    for(const i of path){B.tip(s,i);s.board[i]=null;}
    let o=objects[0];
    const note=objects.length>1&&objects.some(a=>a.note&&!a.polluted);
    if(objects.length>1){
      o=merge(s,objects,dest);
      leaveFatigue(s,path.filter(i=>i!==dest),[dest]);
    }else{
      o=moveObject(o,path[0],dest);
    }
    if(o){o.attach=o.attach.filter(a=>a!=='booster');if(plan?.attach)o.attach.push(plan.key);s.board[dest]=o;B.cutField(s,path[0],dest,o);B.enter(s,dest,o);}
    if(o&&sparks){o.charge=0;B.spark(s,dest);}
    B.discard(s);OfficeWelfare.flush(s);W.demands(s,0);checkEnd(s);
    if(note&&s.status==='playing'){W.event(s,objects.some(o=>o.note==='notebook'&&!o.polluted)?'notebook':null);W.demands(s,0);checkEnd(s);}
    // The successful action counts toward the outgoing phase, never the next one.
    if(s.status==='playing')finishTurn(s);else{s.moves=Math.max(0,s.moves-1);s.turn++;OfficeWelfare.endAction(s);}
    return {approval:false};
  }
  function collect(s,cell) {
    const o=s.board[cell];
    if(!R.collectible(o))throw Error('这个物品不能收进文件柜');
    if(o.bossDelivery)throw Error('这是老板的道具，请用清水洗净后送回');
    if(o.kind==='parcel'&&!o.opened)throw Error('先把外卖袋移动一次再拆开');
    if(o.charge&&!s.items.some(a=>a.key==='glove'&&!a.polluted))throw Error('先准备绝缘手套再接触带电物品');
    const key=R.itemKey(o);
    if(s.items.length>=R.itemLimit(s))throw Error('文件柜已满，请先使用一个道具');
    if(s.zones[cell].types.includes('approval')){
      const pending='collect@'+o.id;
      if(s.pending!==pending){s.pending=pending;return {approval:true};}
    }
    s.pending=null;receive(s,{key,attach:false},o);s.board[cell]=null;return {approval:false};
  }
  function slack(s){W.slack(s);finishTurn(s,R.config.slackCost);}
  return {create,target,advance,publish,usable,compatible,connection,selection,connect,collect,slack,checkEnd,cleanup};
})();
