const OfficeInheritance = (() => {
  function prepare(s){
    if(s.reward?.kind==='inheritance'||s.completionReward)return;
    const unique=new Map();
    for(const entry of s.items){
      if(entry.rental==='phase'||entry.rental==='day')continue;
      const key=entry.key+':'+!!entry.spoiled+':'+!!entry.polluted;
      if(!unique.has(key))unique.set(key,{...entry});
    }
    const pool=[...unique.values()],choices=[];
    while(pool.length&&choices.length<(OfficeWelfare.active(s,'vip')?4:3))choices.push(pool.splice(OfficeBoard.random(s,pool.length),1)[0]);
    s.reward=choices.length?{kind:'inheritance',choices}:null;
  }
  function choose(s,index){
    if(s.status!=='lost'||s.reward?.kind!=='inheritance')throw Error('当前没有可保留的道具');
    s.completionReward={...s.reward.choices[index]};s.reward=null;
    s.notices.push('已保留 '+OfficeRules.items[s.completionReward.key].name+'，下次上班时带上。');
  }
  function restart(s,seed){
    if(s.status==='lost'&&s.reward?.kind==='inheritance')throw Error('请先选择下一次上班要保留的道具');
    return Office.create(seed,s.status==='won'?s.completionReward:null,s.status==='lost'?s.completionReward:null);
  }
  return {prepare,choose,restart};
})();
