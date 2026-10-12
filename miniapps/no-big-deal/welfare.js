const OfficeWelfare = (() => {
  const definitions={
    kpi:{name:'指标下调',description:'每阶段目标整理份数减少 25%。',price:24},
    vip:{name:'VIP选购',description:'福利、零食和失败继承的选择项增加 1。',price:24},
    fireSafety:{name:'消防保障',description:'文件免疫燃烧，获得时熄灭文件上的火。',price:24},
    chair:{name:'加班椅',description:'夜间不会获得疲劳。',price:20},
    ordered:{name:'有序管理',description:'抽完后按牌库固定顺序发牌，不再随机打乱。',price:24},
    internal:{name:'内部消息',description:'接下来两个便签事件必为福利。',price:24,instant:true},
    guarantee:{name:'兜底分配',description:'每经过四个便签事件，下一个必为福利。',price:24},
    reuse:{name:'文件复用',description:'获得时随机复制两张文件牌，保留类型和状态。',price:24,instant:true},
    mirror:{name:'镜像处理',description:'获得时随机复制一张文件牌，保留类型和状态。',price:20,instant:true},
    adrenaline:{name:'肾上腺素',description:'完成紧急需求后，下次合并不会获得疲劳。',price:24},
    crossSupport:{name:'跨部支持',description:'每次完成需求或触发便签事件，必定获得道具。',price:24},
    parallel:{name:'并行审批',description:'一次连线合并至少三张文件，获得一台损坏的整理机。',price:24},
    contract:{name:'定价合同',description:'移除文件牌的价格固定为 50 金币，免费移除仍优先使用。',price:20},
    cabinet:{name:'收藏柜',description:'文件柜持有上限增加 2。',price:20},
    archive:{name:'标准归档',description:'每合成一个文件，获得 1 金币。',price:20},
    speed:{name:'流程提速',description:'合并得分提升 10%。',price:20},
    light:{name:'简化处理',description:'低数值文件（16 份及以下）合并得分翻倍。',price:24},
    cycle:{name:'循环混洗',description:'合成的新文件洗入文件牌库，下次洗牌生效。',price:24},
    quantity:{name:'以量取胜',description:'每添加一张文件牌，获得 9 金币。',price:24},
    thickness:{name:'牌库厚度',description:'牌库每有 5 张牌，每次合并额外得 10 分。',price:24},
    stress:{name:'压力转化',description:'每有一种疲劳，合并得分增加 50%。',price:24},
    notebook:{name:'加班记录本',description:'夜间合并得分增加 15%。',price:20},
    night:{name:'夜班补贴',description:'夜间增加一个需求位，合并得分增加 50%。',price:24},
    rest:{name:'弹性作息',description:'夜间不会获得或自然加重疲劳。',price:20},
    commission:{name:'提成制度',description:'完成需求的金币奖励增加 25%。',price:20},
    business:{name:'业务骨干',description:'每接受一次需求，本局合并得分增加 5%。',price:24},
    eventMoney:{name:'意外之财',description:'每次触发便签事件获得 1 金币。',price:20},
    cleanup:{name:'事后清理',description:'完成紧急需求后，可以免费删除一张文件牌。',price:24},
    clearance:{name:'清仓处理',description:'后勤商品半价。',price:24},
    supply:{name:'长期供货',description:'后勤商品不再售罄，价格降低 20%。',price:24},
    closed:{name:'封闭开发',description:'合并得分增加 50%，但不能再去后勤部。',price:20},
  };
  const active=(s,key)=>s.welfare.some(w=>w.key===key);
  function add(s,key,rental='permanent'){
    if(active(s,key))throw Error('已经获得'+definitions[key].name);
    s.welfare.push({key,rental,expires:rental==='phase'?s.day*3+s.phase:rental==='day'?s.day:null,charges:key==='internal'?2:0,events:0,protecting:false,pending:0});
    if(key==='fireSafety')for(const o of s.board)if(OfficeRules.isFile(o))o.burning=0;
    if(key==='reuse'||key==='mirror'){const pool=s.deck.slice();for(let n=0;n<(key==='reuse'?2:1);n++)addCard(s,pool[OfficeBoard.random(s,pool.length)]);}
    if(key==='night'&&s.phase===2)s.demandSlots++;
    s.notices.push('获得福利：'+definitions[key].name+'。');
  }
  function addCard(s,entry){s.deck.push(OfficeBoard.snapshot(entry));if(active(s,'quantity'))s.coins+=9;}
  function merged(s,result,baseScore,inputs){
    const adrenaline=s.welfare.find(w=>w.key==='adrenaline');
    if(adrenaline?.charges){adrenaline.charges=0;adrenaline.protecting=true;}
    if(active(s,'parallel')&&inputs.length>=3)s.welfare.find(w=>w.key==='parallel').pending++;
    if(active(s,'archive'))s.coins++;
    if(active(s,'cycle'))addCard(s,result);
    return mergeScore(s,result,baseScore);
  }
  function mergeScore(s,result,baseScore,deckSize=s.deck.length){
    if(!baseScore)return 0;
    let multiplier=1+(active(s,'speed')?.1:0)+(active(s,'stress')?s.fatigues.length*.5:0)+
      (active(s,'night')&&s.phase===2?.5:0)+(active(s,'notebook')&&s.phase===2?.15:0)+(active(s,'business')?s.acceptedDemands*.05:0)+(active(s,'closed')?.5:0);
    if(active(s,'light')&&result.value<=16)multiplier*=2;
    return Math.round(baseScore*multiplier)+(active(s,'thickness')?Math.floor(deckSize/5)*10:0);
  }
  function reward(s){
    if(s.phase===0)return;
    const keys=s.phase===1?['coffee','hamburger','energy']:Object.keys(definitions).filter(k=>!active(s,k));
    if(!keys.length)return;
    const choices=[],count=Math.min(active(s,'vip')?3:2,keys.length);
    while(choices.length<count){const i=OfficeBoard.random(s,keys.length);choices.push(keys.splice(i,1)[0]);}
    s.reward={kind:s.phase===1?'food':'welfare',choices};
  }
  function choose(s,key,consume=false){
    if(!s.reward||!s.reward.choices.includes(key))throw Error('请选择本次阶段奖励');
    if(s.reward.kind==='welfare'){add(s,key);if(s.status==='won')s.completionReward=key;}
    else if(consume){OfficeWork.addItem(s,key);OfficeWork.use(s,s.items.length-1,0);}
    else OfficeWork.giveItem(s,key);
    s.reward=null;
  }
  function fatigueBlocked(s){return (s.phase===2&&(active(s,'rest')||active(s,'chair')))||s.welfare.some(w=>w.key==='adrenaline'&&w.protecting);}
  function flush(s){const w=s.welfare.find(w=>w.key==='parallel');if(w)while(w.pending){w.pending--;OfficeWork.giveItem(s,'machine');}}
  function endAction(s){const w=s.welfare.find(w=>w.key==='adrenaline');if(w)w.protecting=false;}
  function demandComplete(s,d){
    if(d.category==='urgent'||d.rushed){const w=s.welfare.find(w=>w.key==='adrenaline');if(w)w.charges=1;}
    if(active(s,'crossSupport')&&d.category!=='favor')gift(s);
  }
  function gift(s){const keys=Object.keys(OfficeRules.items).filter(k=>OfficeRules.itemRarity[k]==='normal');OfficeWork.giveItem(s,keys[OfficeBoard.random(s,keys.length)]);}
  function eventType(s,type){
    const internal=s.welfare.find(w=>w.key==='internal'),guarantee=s.welfare.find(w=>w.key==='guarantee');
    const forced=internal?.charges>0||guarantee?.events===4;
    if(forced&&!Object.keys(definitions).some(k=>!active(s,k)))return 'welfare';
    if(internal?.charges>0)internal.charges--;
    if(guarantee)guarantee.events=guarantee.events===4?0:guarantee.events+1;
    return forced&&type!=='notebook'?'welfare':type;
  }
  function randomWelfare(s){
    const keys=Object.keys(definitions).filter(k=>!active(s,k));
    if(!keys.length){s.notices.push('办公福利已全部持有，福利保底保留至有可领取的福利。');return;}
    add(s,keys[OfficeBoard.random(s,keys.length)]);
  }
  function progress(w){
    if(w.key==='internal')return ' · 剩 '+w.charges+' 次福利便签';
    if(w.key==='guarantee')return ' · '+(w.events===4?'下次必为福利':w.events+'/4 次便签');
    if(w.key==='adrenaline')return w.charges?' · 下次合并已获得保护':' · 等待完成紧急需求';
    return '';
  }
  function deckPrice(s,action){return action==='remove'&&s.freeRemovals?0:action==='remove'&&active(s,'contract')?50:8+s.deckPurchases*4;}
  function expire(s,phase,day){
    s.welfare=s.welfare.filter(w=>!(w.rental==='phase'&&w.expires<=phase)&&!(w.rental==='day'&&s.phase===2&&w.expires<=day));
  }
  return {definitions,active,add,addCard,merged,mergeScore,reward,choose,expire,fatigueBlocked,flush,endAction,demandComplete,gift,eventType,randomWelfare,progress,deckPrice};
})();
