const OfficeWork = (() => {
  const R=OfficeRules,B=OfficeBoard;
  function addItem(s,key,options={}) {
    s.items.push({key,...options});
  }
  function giveItem(s,key) {
    if(s.items.length<R.itemLimit(s)){addItem(s,key);s.notices.push('获得 '+R.items[key].name+'。');return;}
    const cells=B.empty(s).filter(i=>!s.zones[i].types.some(t=>['discard','danger'].includes(t)));
    if(!cells.length){s.pendingItems.push({key});s.notices.push(R.items[key].name+'已暂存，文件柜留出位置后可领取。');return;}
    const i=cells[B.random(s,cells.length)],o=B.object(s,['magnet','machine'].includes(key)?32:1,'prop');o.item=key;s.board[i]=o;
    s.notices.push('文件柜已满，'+R.items[key].name+'留在桌面。');
    B.enter(s,i,o);B.discard(s);
  }
  function claimItem(s,index) {
    if(s.items.length>=R.itemLimit(s))throw Error('文件柜已满，先使用或放置一个道具');
    const entry=s.pendingItems.splice(index,1)[0];s.items.push(entry);
    s.notices.push('已收下 '+R.items[entry.key].name+'。');
  }
  function place(s,kind,value=1) {
    const cells=B.empty(s);if(!cells.length)return false;
    const i=cells[B.random(s,cells.length)];s.board[i]=B.object(s,value,kind);B.enter(s,i,s.board[i]);return true;
  }
  function fatigue(s,type=null,turns=R.config.fatigueTurns,scope='turns') {
    if(s.fatigueShield||OfficeWelfare.fatigueBlocked(s))return;
    const index=s.day*3+s.phase;
    const deadline=scope==='turns'?null:scope==='phase'?index+1:scope==='next'?index+2:(s.day+1)*3;
    const keys=deadline?['food','heavy','hidden','preview','trouble']:Object.keys(R.fatigues);
    type=type||keys[B.random(s,keys.length)];
    const existing=R.fatigue(s,type);
    if(existing){existing.turns=Math.max(turns,existing.turns);if(deadline)existing.deadline=Math.max(deadline,existing.deadline||0);}
    else s.fatigues.push({type,turns,deadline,mask:[B.random(s,16),B.random(s,16),B.random(s,16)]});
    s.notices.push('疲劳：'+R.fatigues[type]+'。');
  }
  function fatigueDuration(s,f){
    return f.deadline?'持续至第 '+Math.floor((f.deadline-1)/3)+' 天'+R.phases[(f.deadline-1)%3]+'结束':'剩 '+f.turns+' 步';
  }
  const demandTitles={organized:'整理一批文件',merges:'完成文件合并',dry:'合并干燥文件',sticky:'处理黏着文件',waste:'清理废弃文件'};
  function requirement(s,metric){
    return {metric,title:demandTitles[metric],target:metric==='organized'?(s.day===1?20:80):metric==='waste'?8:metric==='merges'?3:4};
  }
  function offer(s,force=false,assignedCategory=null) {
    if(s.day===1&&!force)return;
    if(s.demands.length>=s.demandSlots||(!force&&s.turn%R.config.demandEvery!==0))return;
    const categories=s.day===1?['normal']:s.phase===2?['urgent','chain']:['normal','urgent'];
    const category=assignedCategory||categories[B.random(s,categories.length)];
    const metrics=['organized','merges','dry','sticky','waste'],metric=metrics[B.random(s,metrics.length)];
    const consequence=['patience','event','phase','next','day'][B.random(s,5)];
    const plan=[requirement(s,metric)];
    if(category==='chain'){
      const rest=metrics.filter(key=>key!==metric);
      for(let n=0;n<2;n++)plan.push(requirement(s,rest.splice(B.random(s,rest.length),1)[0]));
    }
    s.demands.push({id:++s.sequence,category,...plan[0],plan,stage:0,status:'offered',
      turns:R.config.demandTurns[category],reward:category==='urgent'?R.config.urgentReward:R.config.demandReward,baseline:0,
      consequence:category==='favor'?null:consequence});
  }
  function supplyNeeds(s,d){
    const files=['waste','sticky'].includes(d.metric)?2:0;
    const itemCount=(d.metric==='sticky'?1:0)+(d.category==='favor'?1:0);
    return {files,terrain:d.metric==='waste'&&!s.zones.some(z=>z.types.includes('discard'))?1:0,
      props:Math.max(0,s.items.length+itemCount-R.itemLimit(s))};
  }
  function supplyDescription(s,d){
    const parts=[];
    if(d.metric==='waste')parts.push('两份 4 份废弃文件'+(s.zones.some(z=>z.types.includes('discard'))?'，使用现有废弃区':'，在另一个空格开辟废弃区'));
    if(d.metric==='sticky')parts.push('两份已黏着的 2 份文件和一瓶普通胶');
    if(d.category==='favor')parts.push('牛皮文件套');
    const need=supplyNeeds(s,d),space=need.files+need.terrain+need.props;
    return parts.length?'接受后送达：'+parts.join('；')+(space?'。桌面需留 '+space+' 个非废弃空格。':'。'):'';
  }
  function accept(s,id) {
    const d=s.demands.find(a=>a.id===id);
    if(d.status!=='offered')throw Error('这项需求已经接受');
    const need=supplyNeeds(s,d),cells=B.empty(s).filter(i=>!s.zones[i].types.includes('discard'));
    const count=need.files+need.terrain+need.props;
    if(cells.length<count)throw Error('请先留出 '+count+' 个非废弃空格，再接受这项需求');
    // Reserve every delivery cell before accepting; supplies never fall into their own new discard zone.
    const delivery=[];
    for(let n=0;n<count;n++)delivery.push(cells.splice(B.random(s,cells.length),1)[0]);
    let cursor=0;
    if(need.terrain)B.zone(s,delivery[cursor++],'discard');
    d.status='active';d.baseline=s.stats[d.metric];s.acceptedDemands++;
    for(let n=0;n<need.files;n++){
      const i=delivery[cursor++],o=B.object(s,d.metric==='waste'?4:2,d.metric==='waste'?'waste':'file');
      if(d.metric==='sticky')o.sticky=R.config.strongGlue;
      s.board[i]=o;B.enter(s,i,o);
    }
    const items=[...(d.metric==='sticky'?['glue']:[]),...(d.category==='favor'?['sleeve']:[])];
    for(const key of items){
      if(s.items.length<R.itemLimit(s))addItem(s,key);
      else{const i=delivery[cursor++],o=B.object(s,1,'prop');o.item=key;s.board[i]=o;B.enter(s,i,o);}
    }
    if(items.length)s.notices.push('需求补给已送达：'+items.map(key=>R.items[key].name).join('、')+'。');
    B.discard(s);demands(s,0);
  }
  function demands(s,elapsed=1) {
    for(const d of [...s.demands]){
      if(d.status!=='active')continue;
      if(s.stats[d.metric]-d.baseline>=d.target){
        OfficeCampaign.completed(s,d);OfficeWelfare.demandComplete(s,d);
        const reward=Math.round(d.reward*(s.phase===2?R.config.nightRewardMultiplier:1)*(OfficeWelfare.active(s,'commission')?1.25:1));s.coins+=reward;
        s.notices.push(d.title+'完成，获得 '+reward+' 金币。');
        if((d.category==='urgent'||d.rushed)&&OfficeWelfare.active(s,'cleanup'))s.freeRemovals++;
        if(d.category==='favor'){
          const key=['wheels','film','glove'][B.random(s,3)];
          giveItem(s,key);
          s.shopUnlocked=true;
        }
        if(d.category==='chain'&&d.stage<2){
          d.stage++;Object.assign(d,d.plan[d.stage]);d.baseline=0;d.turns=R.config.demandTurns.chain;d.status='offered';d.rushed=false;d.reward=R.config.demandReward;
          s.notices.push('连续需求第 '+(d.stage+1)+' 段已送达，接受后开始计时。');
        }
        else s.demands=s.demands.filter(a=>a!==d);
      }else{
        d.turns-=elapsed;
        if(d.turns<=0){
          if(d.category!=='favor'){
            if(d.consequence==='patience')s.patience=Math.max(0,s.patience-R.config.demandPenalty);
            else if(d.consequence==='event')event(s,['hazard','stone','bomb'][B.random(s,3)]);
            else if(['phase','next','day'].includes(d.consequence))fatigue(s,null,R.config.fatigueTurns,d.consequence);
          }
          s.notices.push(d.title+'到期'+(d.category==='favor'?'，没有惩罚。':d.consequence==='patience'?'，忍耐度扣除 '+R.config.demandPenalty+'。':d.consequence==='event'?'，触发桌面意外。':'，产生持续疲劳。'));
          s.demands=s.demands.filter(a=>a!==d);
        }
      }
    }
  }
  function event(s,type=null) {
    const types=['transform','swap','copy','remove','spawn','fatigue','demand','urgent','gift','loss','blocked','parcel','hazard','stone','magnet','machine','bomb','barrier','delay','temporary','mirror','rotate','deckRemove','deckAdd','decrement','pressure','spoil'];
    const supported=OfficeWelfare.active(s,'crossSupport');
    type=OfficeWelfare.eventType(s,type||types[B.random(s,types.length)]);
    if(type==='welfare')OfficeWelfare.randomWelfare(s);
    if(OfficeWelfare.active(s,'eventMoney'))s.coins++;
    const files=s.board.map((o,i)=>R.isFile(o)?i:-1).filter(i=>i>=0);
    const mode=B.random(s,3);
    const i=files.length?(mode===0?files[B.random(s,files.length)]:files.reduce((a,b)=>(mode===1?s.board[a].value>=s.board[b].value:s.board[a].value<=s.board[b].value)?a:b)):-1;
    if(type==='notebook'&&!s.campaign.notebookGiven){s.campaign.notebookGiven=true;if(!OfficeWelfare.active(s,'notebook'))OfficeWelfare.add(s,'notebook');}
    if(type==='transform'&&i>=0){s.board[i].value=Math.max(1,Math.floor(s.board[i].value/2));s.notices.push('便签：一份文件被拆分，份数减半。');}
    if(type==='decrement'&&i>=0){s.board[i].value=Math.max(1,s.board[i].value-1);s.notices.push('便签：弄丢一份文件，份数减一。');}
    if(type==='mirror'&&files.length>1){const j=files[(files.indexOf(i)+1)%files.length];s.board[i].value=s.board[j].value;s.notices.push('便签：一份文件变成了另一份的镜像。');}
    if(type==='delay'&&i>=0){s.delayed.push({id:s.board[i].id,value:Math.max(1,Math.floor(s.board[i].value/2)),turns:3});s.notices.push('便签：一份文件将在 3 步后减半。');}
    if(type==='temporary'&&i>=0){s.delayed.push({id:s.board[i].id,value:s.board[i].value,turns:5});s.board[i].value=Math.max(1,Math.floor(s.board[i].value/2));s.notices.push('便签：文件暂时减半，5 步后恢复；若先合并则不再恢复。');}
    if(type==='rotate'){
      const ring=[0,1,2,3,7,11,15,14,13,12,8,4],offset=B.random(s,2)?1:-1,objects=ring.map(j=>s.board[j]);
      ring.forEach((j,k)=>{s.board[j]=objects[(k-offset+ring.length)%ring.length];});
      ring.forEach(j=>{if(s.board[j])B.enter(s,j,s.board[j]);});s.notices.push('便签：桌面外圈文件'+(offset===1?'顺':'逆')+'时针换位。');
    }
    if(type==='deckRemove'&&s.deck.length>1){s.deck.splice(B.random(s,s.deck.length),1);s.notices.push('便签：牌库随机移除一张文件，下次洗牌生效。');}
    if(type==='deckAdd'){OfficeWelfare.addCard(s,B.card([1,2,4][B.random(s,3)]));s.notices.push('便签：牌库增加一张文件，下次洗牌生效。');}
    if(type==='pressure'){s.demandSlots++;offer(s,true);s.notices.push('便签：本阶段业务压力增加，需求位增加一个。');}
    if(type==='spoil'){
      const candidates=s.items.filter(a=>['water','strongGlue','coffee','snack','hamburger','energy'].includes(a.key)&&!a.spoiled);
      if(candidates.length){const a=candidates[B.random(s,candidates.length)];a.spoiled=true;s.notices.push('便签：'+R.items[a.key].name+'变质了，使用前请查看文件柜中的说明。');}
      else s.notices.push('便签：检查补给，现有道具没有变质。');
    }
    if(type==='swap'&&files.length>1){const j=files[(files.indexOf(i)+1)%files.length];[s.board[i],s.board[j]]=[s.board[j],s.board[i]];s.notices.push('便签：两份文件交换了位置。');}
    if(type==='copy'&&i>=0){
      const corners=[0,3,12,15].filter(j=>!s.board[j]);
      if(corners.length){const j=corners[B.random(s,corners.length)];s.board[j]=B.object(s,s.board[i].value,s.board[i].kind);B.enter(s,j,s.board[j]);s.notices.push('便签：复印了一份文件到桌角。');}
      else s.notices.push('便签：桌角都被占用，复印没有产生新文件。');
    }
    if(type==='remove'&&i>=0){s.board[i]=null;s.notices.push('便签：一份文件被移出了桌面。');}
    if(type==='spawn'){place(s,['urgent','copy','cancel','metal','messy','waste'][B.random(s,6)],2);s.notices.push('便签：一份特殊文件送到了桌上。');}
    if(type==='fatigue')fatigue(s);
    if(type==='demand'){offer(s,true);s.notices.push('便签：新需求已送达。');}
    if(type==='urgent'){
      const d=s.demands.find(a=>a.status==='active')||s.demands.find(a=>a.status==='offered');
      if(d){d.rushed=true;d.turns=Math.min(d.turns,8);d.reward=R.config.urgentReward;s.notices.push('便签：一个需求被催急了，限时缩至 8 步以内，金币奖励提高。');}else offer(s,true,'urgent');
    }
    if(type==='gift'){
      const rare=B.random(s,100)<R.config.rareGiftChance;
      const pool=Object.keys(R.items).filter(key=>rare?R.itemRarity[key]==='rare':['normal','event',...(s.phase===2?['night']:[])].includes(R.itemRarity[key]));
      const key=pool[B.random(s,pool.length)];
      giveItem(s,key);
    }
    if(type==='loss'&&s.items.length){const a=s.items.splice(B.random(s,s.items.length),1)[0];s.notices.push('便签：丢失了 '+R.items[a.key].name+'。');}
    if(type==='blocked'){s.shopBlocked=true;s.notices.push('便签：本阶段后勤部暂停营业。');}
    if(type==='parcel'){
      const cells=B.empty(s);if(cells.length){const j=cells[B.random(s,cells.length)],o=B.object(s,1,'parcel');o.item='coffee';s.board[j]=o;s.notices.push('便签：外卖袋到了，先移动一次再拆开。');}
    }
    if(type==='hazard'){
      const key=Object.keys(R.zones)[B.random(s,Object.keys(R.zones).length)];B.zone(s,B.random(s,16),key);s.notices.push('便签：桌面出现了'+R.zones[key][0]+'区。');
    }
    if(['stone','magnet','machine','bomb'].includes(type)){place(s,type,type==='stone'?1024:type==='bomb'?[8,64,1024][B.random(s,3)]:32);s.notices.push('便签：桌上出现了'+R.kinds[type][0]+'。');}
    if(type==='barrier'){
      const a=B.random(s,16),candidates=B.neighbors(a).filter(j=>j%4===a%4||Math.floor(j/4)===Math.floor(a/4));
      const b=candidates[B.random(s,candidates.length)];s.barriers.push([Math.min(a,b),Math.max(a,b)]);s.notices.push('便签：两个格子之间竖起了挡板。');
    }
    if(supported&&type!=='gift')OfficeWelfare.gift(s);
    B.discard(s);
  }
  function slack(s) {
    if(s.slacks>=R.config.slackLimit)throw Error('本阶段摸鱼次数已用完');
    s.slacks++;
    const guaranteed=s.totalSlacks===0;s.totalSlacks++;
    let roll=B.random(s,100);
    if(guaranteed||s.slackEmpty)roll=Math.min(roll,89);
    if(roll>=90){s.slackEmpty=true;s.notices.push('这次摸鱼无事发生。');}
    else {
      const files=s.board.map((o,i)=>R.isFile(o)?i:-1).filter(i=>i>=0);
      if(files.length){const i=roll<80?files.reduce((a,b)=>s.board[a].id>s.board[b].id?a:b):files[B.random(s,files.length)];s.board[i].note=true;s.notices.push('一张新便签夹进了文件，合并时会触发。');}
      else event(s);
    }
  }
  function stock(s) {
    const one=s.phase===2?['ice','lighter','strongGlue','coffee','snack','bomb']:['water','glue','film','coffee','snack','scissors'];
    const selected=[];
    while(selected.length<4){const key=one[B.random(s,one.length)];if(!selected.includes(key))selected.push(key);}
    s.stock=selected.map(key=>({key,sold:false,kind:'item'}));
    const welfareKeys=Object.keys(OfficeWelfare.definitions).filter(key=>!OfficeWelfare.active(s,key));
    for(let n=0;n<2&&welfareKeys.length;n++){const i=B.random(s,welfareKeys.length);s.stock.push({key:welfareKeys.splice(i,1)[0],kind:'welfare',sold:false});}
  }
  function price(s,slot,rental='permanent'){
    const info=slot.kind==='welfare'?OfficeWelfare.definitions[slot.key]:R.items[slot.key];
    return Math.ceil(info.price*(OfficeWelfare.active(s,'clearance')?.5:1)*(OfficeWelfare.active(s,'supply')?.8:1)/(rental==='phase'?4:rental==='day'?2:1));
  }
  function buy(s,index,rental='permanent') {
    if(s.shopBlocked||!s.shopUnlocked||OfficeWelfare.active(s,'closed'))throw Error('后勤部暂未开放');
    const slot=s.stock[index],welfare=slot.kind==='welfare';
    if(slot.sold)throw Error('这件商品已售出');
    if(welfare&&OfficeWelfare.active(s,slot.key))throw Error('已经获得这项福利');
    if(!welfare&&s.items.length>=R.itemLimit(s))throw Error('文件柜已满，先使用或放置一个道具');
    if(welfare&&OfficeWelfare.definitions[slot.key].instant&&rental!=='permanent')throw Error('立即生效的福利不能租用');
    const cost=price(s,slot,rental);if(s.coins<cost)throw Error('金币不足');
    s.coins-=cost;slot.sold=!OfficeWelfare.active(s,'supply');
    if(welfare)OfficeWelfare.add(s,slot.key,rental);
    else{addItem(s,slot.key);s.notices.push('已获得 '+R.items[slot.key].name+'。');}
  }
  function editDeck(s,action,index) {
    if(!s.shopUnlocked||s.shopBlocked||OfficeWelfare.active(s,'closed'))throw Error('后勤部暂未开放');
    const free=action==='remove'&&s.freeRemovals>0;
    const price=OfficeWelfare.deckPrice(s,action);if(s.coins<price)throw Error('金币不足');
    if(action==='remove'&&s.deck.length===1)throw Error('文件牌库至少保留一张');
    if(action==='upgrade'&&s.deck[index].value>=1024)throw Error('这张文件已经是最高份数');
    s.coins-=price;if(free)s.freeRemovals--;else s.deckPurchases++;
    if(action==='remove')s.deck.splice(index,1);
    if(action==='upgrade')s.deck[index].value*=2;
    if(action==='add')OfficeWelfare.addCard(s,B.card(4));
    s.notices.push('牌库已调整，下次洗牌生效。');
  }
  function use(s,index,cell) {
    const entry=s.items[index],key=entry.key,item=R.items[key],o=s.board[cell];
    const foodSpoiled=entry.spoiled||!!R.fatigue(s,'food');
    if(entry.polluted){
      if(o)throw Error('请选择一个空格放回受污染的道具');
      const prop=B.object(s,['magnet','machine'].includes(key)?32:1,'prop');prop.item=key;prop.polluted=true;prop.spoiled=entry.spoiled;s.board[cell]=prop;
      B.enter(s,cell,prop);s.items.splice(index,1);B.discard(s);s.notices.push('道具已放回桌面，用清水洗净后再收集。');return;
    }
    if(item.target==='passive')throw Error('这件道具放在文件柜中自动生效');
    if(item.target==='file'&&!R.isFile(o))throw Error('请选择一份文件');
    if(item.target==='object'&&!o)throw Error('请选择桌上的物品');
    if(item.attach&&o.attach.includes(key))throw Error('这个物品已经有'+item.name);
    if(item.attach){o.attach.push(key);}
    if(key==='water')B.zone(s,cell,entry.spoiled?'pollution':'water');
    if(key==='glue'||key==='strongGlue')B.zone(s,cell,'glue',key==='strongGlue'&&!entry.spoiled);
    if(key==='lighter')B.zone(s,cell,'fire');
    if(key==='ice'&&!B.protect(o,'ice')){o.frozen=3+(s.phase===2?2:0);o.burning=0;}
    if(key==='scissors')o.attach=o.attach.filter(a=>!['woodStand','metalStand','woodCage','metalCage','tape','seal'].includes(a));
    if(key==='coffee'){
      if(s.fatigues.length)s.fatigues.shift();
      if(foodSpoiled)s.coffeeRebound=true;
    }
    if(key==='hamburger'){
      s.forcedOnes=foodSpoiled?2:3;if(s.preview)s.preview.value=1;
      if(foodSpoiled){const cells=B.empty(s);if(cells.length){const i=cells[B.random(s,cells.length)];s.board[i]=B.object(s,1);s.board[i].temporary=5;}}
    }
    if(key==='energy'){s.fatigueShield=foodSpoiled?1:2;s.energyRebound=foodSpoiled;}
    if(key==='snack')s.patience=Math.min(100,s.patience+(entry.spoiled||R.fatigue(s,'food')?5:10));
    if(['magnet','bomb','machine'].includes(key)){
      if(o)throw Error('请选择一个空格放置道具');
      s.board[cell]=B.object(s,key==='bomb'?8:32,key);
    }
    if(o&&['water','glue','strongGlue','lighter'].includes(key))B.enter(s,cell,o,[key==='water'?(entry.spoiled?'pollution':'water'):key==='lighter'?'fire':'glue']);
    if(key==='sleeve'&&s.zones[cell].types.includes('glue'))B.enter(s,cell,o,['glue']);
    s.items.splice(index,1);OfficeCampaign.used(s,key);B.discard(s);s.notices.push('已使用 '+item.name+'。');
  }
  function outsideMagnet(s,index,side,lane){
    if(s.items[index].key!=='magnet')throw Error('请选择马蹄铁');
    if(s.outsideMagnets.some(m=>m.side===side&&m.lane===lane))throw Error('这个桌边已经放了磁铁');
    const [x,y,direction]=[[lane,-1,2],[4,lane,3],[lane,4,0],[-1,lane,1]][side];
    s.outsideMagnets.push({cell:null,x,y,direction,side,lane});s.items.splice(index,1);s.notices.push('磁铁已放在桌外，朝桌内吸引最近的金属。');
  }
  function collectOutside(s,index){
    if(s.items.length>=R.itemLimit(s))throw Error('文件柜已满，请先使用一个道具');
    addItem(s,'magnet');s.outsideMagnets.splice(index,1);s.notices.push('桌外磁铁已收进文件柜。');
  }
  return {price,giveItem,claimItem,addItem,place,offer,supplyNeeds,supplyDescription,accept,demands,event,fatigue,fatigueDuration,slack,stock,buy,editDeck,use,outsideMagnet,collectOutside};
})();
