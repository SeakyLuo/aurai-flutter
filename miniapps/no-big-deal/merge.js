const OfficeMerge = (() => {
  const R=OfficeRules;
  const ordinary=objects=>objects.every(o=>o.kind==='file');
  const powerOfTwo=value=>Number.isInteger(Math.log2(value));
  // Equal-value pair reductions preserve the odd factor, including event-altered files.
  function unit(value){while(value%2===0)value/=2;return value;}
  function compatible(objects){
    if(!objects.every(R.isFile))return false;
    const first=objects[0];
    if(ordinary(objects))return objects.every(o=>unit(o.value)===unit(first.value));
    if(objects.some(o=>!!o.wet!==!!first.wet))return false;
    const anchor=objects.find(o=>!['copy','cancel'].some(kind=>R.effect(o,kind)));
    return objects.every(o=>Office.compatible(first,o)&&(!anchor||Office.compatible(anchor,o)));
  }
  function complete(objects){
    if(objects.length<2||!compatible(objects))return false;
    return !ordinary(objects)||powerOfTwo(objects.reduce((n,o)=>n+o.value,0)/unit(objects[0].value));
  }
  function result(s,objects){
    const base=objects.find(o=>!['copy','cancel'].some(kind=>R.effect(o,kind)))||objects[0];
    const copies=objects.filter(o=>R.effect(o,'copy')).length;
    const originals=objects.filter(o=>!R.effect(o,'copy'));
    const sum=(originals.length?originals.reduce((n,o)=>n+o.value,0):base.value)*2**(originals.length?copies:copies-1);
    const cancellations=objects.filter(o=>R.effect(o,'cancel')).length;
    const cancelled=objects.some(o=>o.cancelled&&!o.polluted)||cancellations>0;
    const multiplier=ordinary(objects)?objects.length-1:1;
    const score=cancelled?0:sum*multiplier+objects.reduce((n,o)=>n+(o.polluted?0:o.messy),0);
    const value=cancellations===objects.length?1:R.fatigue(s,'noGrowth')?base.value:sum;
    const kind=base.kind==='waste'?'waste':base.kind==='metal'?'metal':'file';
    return {value,kind,sum,multiplier,score:kind==='waste'?0:score,
      cancelled:(cancellations>0||objects.every(o=>o.cancelled))&&(cancellations+objects.filter(o=>o.cancelled&&!o.polluted).length)%2===1};
  }
  function preview(s,path){
    const objects=path.map(i=>s.board[i]),plan=result(s,objects);
    const ready=complete(objects)&&objects.every(o=>Office.usable(o,s))&&!R.fatigue(s,'noMerge');
    const deckSize=s.deck.length+(OfficeWelfare.active(s,'cycle')?1:0);
    return {...plan,ready,gain:ready?OfficeWelfare.mergeScore(s,plan,plan.score,deckSize):0};
  }
  function selector(s){
    const files=s.board.flatMap((o,i)=>R.isFile(o)&&Office.usable(o,s)?[i]:[]);
    const links=Array.from({length:16},(_,i)=>files.reduce((mask,j)=>Office.connection(s,i,j)?mask|1<<j:mask,0));
    const families=new Map(),optionsCache=new Map();
    function family(first){
      const factor=unit(first.value),key=factor;
      if(families.has(key))return families.get(key);
      const cells=files.filter(i=>s.board[i].kind==='file'&&unit(s.board[i].value)===factor);
      const mask=cells.reduce((m,i)=>m|1<<i,0),descending=cells.slice().sort((a,b)=>s.board[b].value-s.board[a].value);
      const memo=new Map();
      // With at most 16 cells, each subset/endpoint is searched once per board state.
      // A bounded subset-sum check prunes prefixes that cannot reach the next merge value.
      function canFill(sum,remaining){
        const total=descending.reduce((n,i)=>n+((remaining&1<<i)?s.board[i].value:0),sum);
        for(let target=2**Math.ceil(Math.log2(sum/factor))*factor;target<=total;target*=2){
          let missing=target-sum;
          for(const i of descending)if((remaining&1<<i)&&s.board[i].value<=missing)missing-=s.board[i].value;
          if(missing===0)return true;
        }
        return false;
      }
      function finishable(selected,last,sum){
        if((selected&(selected-1))!==0&&powerOfTwo(sum/factor))return true;
        const key=selected*16+last;
        if(memo.has(key))return memo.get(key);
        const remaining=mask&~selected;
        if(!canFill(sum,remaining)){memo.set(key,false);return false;}
        const next=links[last]&remaining;
        for(const i of cells)if((next&1<<i)&&finishable(selected|1<<i,i,sum+s.board[i].value)){
          memo.set(key,true);return true;
        }
        memo.set(key,false);return false;
      }
      const value={finishable};families.set(key,value);return value;
    }
    function options(path){
      if(!path.length||R.fatigue(s,'noMerge'))return [];
      const objects=path.map(i=>s.board[i]);
      if(!objects.every(o=>R.isFile(o)&&Office.usable(o,s)))return [];
      const mask=path.reduce((m,i)=>m|1<<i,0),last=path[path.length-1],key=mask*16+last;
      if(optionsCache.has(key))return optionsCache.get(key);
      const choices=files.filter(i=>{
        if((mask&1<<i)||!(links[last]&1<<i))return false;
        const next=[...objects,s.board[i]];
        if(!compatible(next))return false;
        if(!ordinary(next))return complete(next);
        return family(objects[0]).finishable(mask|1<<i,i,next.reduce((n,o)=>n+o.value,0));
      });
      optionsCache.set(key,choices);return choices;
    }
    return {options};
  }
  function hasMerge(s){
    const selection=selector(s);
    return s.board.some((o,i)=>R.isFile(o)&&selection.options([i]).length>0);
  }
  return {ordinary,compatible,complete,result,preview,selector,hasMerge};
})();
