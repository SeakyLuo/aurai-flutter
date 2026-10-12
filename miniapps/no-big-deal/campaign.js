const OfficeCampaign = (() => {
  const R=OfficeRules,B=OfficeBoard,W=OfficeWork;
  function create(){return {mergedFour:false,spilled:false,sleeveGiven:false,sleeveUsed:false,protectedMoves:0,glueLesson:false,nightNote:false,notebookGiven:false,queue:[],parcelPending:false,dirtyPending:false,bossWashPending:false};}
  function safeCells(s){return B.empty(s).filter(i=>!s.zones[i].types.some(t=>['discard','danger','fire'].includes(t)));}
  function enterPhase(s){
    const c=s.campaign;
    if(s.day===1&&s.phase===1){
      const cells=safeCells(s);if(cells.length)B.zone(s,cells[B.random(s,cells.length)],'discard');
      if(!s.barriers.some(([a,b])=>a===5&&b===6))s.barriers.push([5,6]);
      W.giveItem(s,'glue');
    }
    if(s.day===1&&s.phase===2){c.parcelPending=true;c.queue.push('normal');}
    if(s.day===2&&s.phase===0){
      const holes=s.zones.flatMap((z,i)=>z.types.includes('discard')?[i]:[]);
      if(holes.length)for(const i of holes){s.zones[i].types=s.zones[i].types.filter(t=>t!=='discard');B.zone(s,i,'danger');}
      else {const cells=safeCells(s);if(cells.length)B.zone(s,cells[B.random(s,cells.length)],'danger');}
      c.queue.push('urgent');
    }
    if(s.day===2&&s.phase===1)c.queue.push('urgent','normal');
    if(s.day===2&&s.phase===2){c.queue.push('chain','urgent');c.bossWashPending=true;}
    flush(s);
  }
  function flush(s){
    const c=s.campaign;
    while(c.queue.length&&s.demands.length<s.demandSlots)W.offer(s,true,c.queue.shift());
    for(const [flag,kind,key] of [['parcelPending','parcel','coffee'],['dirtyPending','prop','film'],['bossWashPending','prop','water']]){
      if(!c[flag])continue;const cells=safeCells(s);if(!cells.length)continue;
      const i=cells[B.random(s,cells.length)],o=B.object(s,1,kind);o.item=key;
      if(flag==='parcelPending'){B.zone(s,i,'glue',true);o.sticky=R.config.strongGlue;}
      else {o.polluted=true;o.bossDelivery=flag==='bossWashPending';}
      s.board[i]=o;c[flag]=false;
    }
  }
  function spill(s){s.campaign.spilled=true;}
  function wet(s,o){
    const c=s.campaign;if(s.day!==1||s.phase!==0||c.sleeveGiven||!R.isFile(o)||!o.wet)return;
    c.sleeveGiven=true;W.giveItem(s,'sleeve');
  }
  function used(s,key){if(key==='sleeve')s.campaign.sleeveUsed=true;}
  function afterAction(s){
    const c=s.campaign;
    if(s.day===1&&s.phase===0){
      if(c.sleeveUsed&&!c.glueLesson&&++c.protectedMoves>=3){
        if(!s.zones.some(z=>z.types.includes('glue'))){const cells=safeCells(s);if(cells.length)B.zone(s,cells[B.random(s,cells.length)],'glue');}
        c.glueLesson=s.zones.some(z=>z.types.includes('glue'));
      }
    }
    flush(s);
  }
  function merged(s,o){
    const c=s.campaign;
    if(s.day===1&&s.phase===0&&o.value>=4)c.mergedFour=true;
    if(s.day===1&&s.phase===2&&!c.nightNote&&!c.notebookGiven){o.note='notebook';c.nightNote=true;}
  }
  function completed(s,d){
    if(s.day===2&&s.phase===1&&(d.category==='urgent'||d.rushed)){
      if(!s.campaign.queue.includes('favor')&&!s.demands.some(a=>a.category==='favor'))s.campaign.queue.unshift('favor');
      s.campaign.dirtyPending=true;
    }
  }
  function washed(s,i,o){
    if(!o.bossDelivery||o.polluted)return;
    s.board[i]=null;s.patience=Math.min(100,s.patience+1);
    s.notices.push('老板的道具洗干净并送回去了，忍耐度恢复 1。');
  }
  function ended(s){if(s.day===2&&s.phase===0)s.shopUnlocked=true;}
  function hint(s){
    if(s.status!=='playing')return null;
    const c=s.campaign;
    if(s.day===1&&s.phase===0){
      if(!c.mergedFour)return '连起能归并为一份的文件，先合出一份 4 份文件。';
      if(!c.spilled&&s.props.includes('tea'))return '把文件移到茶杯格，再挪开文件，看看洒出的清水。';
      if(!c.sleeveGiven)return '把文件移入清水区，体验湿润和重量变化。';
      if(!c.sleeveUsed)return '打开文件柜，选牛皮文件套，再点一份文件保护它。';
      if(c.glueLesson&&s.board.some(o=>o?.attach.includes('sleeve')))return '把套好文件套的文件移入胶水区：文件套和胶水会相互抵消。';
      return '文件套能防水；湿润文件需与湿润文件合并。继续完成整理目标。';
    }
    if(s.day===1&&s.phase===1)return '上午的桌面继续保留。黏着物会一起移动，只有区外更重的物品能拉住废弃区上的同伴；挡板会阻止通行。';
    if(s.day===1&&s.phase===2){
      if(!c.notebookGiven)return '夜里湿润和冰冻更久。移动胶水里的外卖袋后可收集咖啡；合并带便签的文件，领取加班记录本。';
      return '加班记录本让夜间合并得分增加 15%；咖啡可以消除一种疲劳。';
    }
    if(s.day===2&&s.phase===0)return '昨天的桌洞刚修好，危险区仍会塌陷，经过重物塌得更快。接受需求后开始计时；本阶段结束后开放后勤部。';
    if(s.day===2&&s.phase===1)return '普通与紧急需求同时送达。先比较时限和补给再接受；紧急需求完成后有人情需求，脏道具需先用清水洗净。';
    return '需求链每段都要重新接受。老板的脏道具洗净后会送回，恢复 1 点忍耐度，不会收入文件柜。';
  }
  return {create,enterPhase,flush,spill,wet,used,afterAction,merged,completed,washed,ended,hint};
})();
