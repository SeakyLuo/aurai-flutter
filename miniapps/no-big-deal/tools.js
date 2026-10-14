const OfficeTools = (() => {
  const R=OfficeRules,B=OfficeBoard;
  const keys=['duplicator','paperKnife','stapler','requisition','dispatch'];
  const has=key=>keys.includes(key);
  const emptyTargets=s=>B.empty(s).filter(i=>!s.zones[i].types.includes('discard'));
  function sourceProblem(s,key,i){
    const o=s.board[i];
    if(!o||o.kind!=='file')return '请选择普通文件';
    if(key==='paperKnife'&&(o.value<2||o.value%2!==0))return '裁纸刀需要至少 2 份的偶数份普通文件';
    return null;
  }
  function availability(s,key){
    if(s.status!=='playing')return '当前阶段已结束';
    if(['duplicator','paperKnife','dispatch'].includes(key)&&!emptyTargets(s).length)return '请先留出一个非废弃区空格';
    if(['duplicator','paperKnife','stapler'].includes(key)&&!s.board.some((o,i)=>o&&!sourceProblem(s,key,i)))return key==='paperKnife'?'桌上没有可拆分的普通文件':'桌上没有普通文件';
    if(key==='requisition'&&s.forcedOnes)return '固定发放 1 份文件期间暂不能调阅';
    if(key==='requisition'&&!s.pool.length)return '本轮文件已全部调出，不能提前重新洗牌';
    return null;
  }
  function problem(s,key,source,target){
    const unavailable=availability(s,key);if(unavailable)return unavailable;
    if(['duplicator','paperKnife','stapler'].includes(key)){
      const invalid=sourceProblem(s,key,source);if(invalid)return invalid;
    }
    if(['duplicator','paperKnife','dispatch'].includes(key)&&!emptyTargets(s).includes(target))return '请选择非废弃区的空格';
    if(key==='requisition'&&(!Number.isInteger(target)||target<0||target>=s.pool.length))return '请选择本轮剩余的一份文件';
    return null;
  }
  function use(s,index,source,target){
    const entry=s.items[index],key=entry.key;
    if(!has(key))throw Error('请选择整理道具');
    if(entry.polluted)throw Error('先将受污染的道具放回桌面洗净');
    const invalid=problem(s,key,source,target);if(invalid)throw Error(invalid);
    const o=s.board[source];
    if(key==='duplicator'||key==='paperKnife'){
      const value=key==='paperKnife'?o.value/2:o.value;
      if(key==='paperKnife')o.value=value;
      // A new sheet copies the number only; notes, attachments and delayed events stay on the original.
      const fresh=B.object(s,value);s.board[target]=fresh;B.enter(s,target,fresh);B.discard(s);
    }
    if(key==='stapler')o.value*=2;
    if(key==='requisition'){
      const chosen=s.pool.splice(target,1)[0];s.pool.unshift(s.nextCard);s.nextCard=chosen;
      if(s.preview)s.preview.value=chosen.value;
    }
    if(key==='dispatch')s.preview={cell:target,value:s.forcedOnes?1:s.nextCard.value};
    s.items.splice(index,1);OfficeCampaign.used(s,key);
    s.notices.push('已使用 '+R.items[key].name+'。');
  }
  return {keys,has,availability,sourceProblem,emptyTargets,problem,use};
})();
