// Every deal starts with a legal topological removal order. Types are assigned
// along that order with a level-specific tray budget, so its tray never overflows.
var Sheep=(()=>{
  const layouts=[[4],[5,4],[6,5,4],[6,5,6,4],[6,5,6,5,4],[6,5,6,5,6,4],
    [6,5,6,5,6,5],[6,5,6,5,6,5,4],[6,5,6,5,6,5,6],
    [6,5,6,5,6,5,6,5],[6,5,6,5,6,5,6,5,6],[6,5,6,5,6,5,6,5,6,5]];
  const levels=layouts.map((widths,index)=>({name:`第 ${index+1} 关`,widths,
    side:index===0?2:index<3?4:index<6?6:index<9?18:24,
    kinds:[4,6,8,10,12,13,14,14,15,15,16,16][index],pressure:Math.min(6,3+index),
    open:Math.min(5,2+index),shape:index<3?0:index%3}));
  const symbols=['🐑','🥕','🌽','🍎','🍀','🌻','🍄','🥦','🍇','🍓','🧶','🔔','🦋','🥁','☂️','🐟'];
  function rng(seed){return ()=>{seed|=0;seed=seed+0x6D2B79F5|0;let t=Math.imul(seed^seed>>>15,1|seed);t=t+Math.imul(t^t>>>7,61|t)^t;return ((t^t>>>14)>>>0)/4294967296;};}
  const pick=(items,random)=>items[Math.floor(random()*items.length)];
  function blockers(tiles){return tiles.map(a=>tiles.filter(b=>b.z>a.z&&Math.abs(a.x-b.x)<.95&&Math.abs(a.y-b.y)<.95).map(b=>b.id));}
  function available(s){const gone=new Set(s.removed);return s.tiles.filter(t=>!gone.has(t.id)&&s.blockers[t.id].every(id=>gone.has(id)));}
  function generate(level,seed){
    const config=levels[level],random=rng(seed),tiles=[];
    config.widths.forEach((width,z)=>{
      for(let y=0;y<width;y++)for(let x=0;x<width;x++){
        // Cut corners or open a central window to vary the excavation paths.
        if(config.shape===1&&width===6&&(x===0||x===5)&&(y===0||y===5))continue;
        if(config.shape===2&&z%2===1&&x===Math.floor(width/2)&&y===Math.floor(width/2))continue;
        tiles.push({id:tiles.length,x:1+(6-width)/2+x,y:.45+(6-width)/2+y,z,type:0});
      }
    });
    const side=config.side+(3-(tiles.length+config.side)%3)%3;
    for(let i=0;i<side;i++){
      const z=Math.floor(i/6);
      tiles.push({id:tiles.length,x:i%2?7:0,y:side===2?3:1+Math.floor(i/2)%3*1.55+z*.12,z,type:0});
    }
    const block=blockers(tiles),remaining=new Set(tiles.map(t=>t.id)),order=[];
    while(remaining.size){
      let choices=tiles.filter(t=>remaining.has(t.id)&&block[t.id].every(id=>!remaining.has(id)));
      if(level>=3&&order.length){
        // Follow excavation routes rather than scattering matching sets across
        // the entire exposed surface. Deeper matches require planning tray space.
        const last=tiles[order[order.length-1]];
        const distance=t=>(t.x-last.x)**2+(t.y-last.y)**2;
        // Higher levels alternate excavation regions, separating matches across
        // towers instead of letting a single local route clear the whole board.
        const direction=level>=5?-1:1;
        choices.sort((a,b)=>direction*(distance(a)-distance(b))||a.z-b.z);
        choices=choices.slice(0,level>=5?5:2);
      }
      const next=pick(choices,random);order.push(next.id);remaining.delete(next.id);
    }
    const quota=Array(config.kinds).fill(0),partial=Array(config.kinds).fill(0);
    for(let i=0;i<tiles.length/3;i++)quota[i%quota.length]+=3;
    for(const id of order){
      const open=partial.filter(n=>n>0).length;
      const held=partial.reduce((sum,n)=>sum+n,0);
      const candidates=quota.map((n,type)=>type).filter(type=>quota[type]>0&&
        (partial[type]>0||open<config.open)&&held+(partial[type]===2?-2:1)<=config.pressure);
      const type=pick(candidates,random);tiles[id].type=type;quota[type]--;partial[type]=(partial[type]+1)%3;
    }
    return {level,seed,tiles,blockers:block,solution:order,removed:[],tray:[],history:[],phase:'playing'};
  }
  function greedyProgress(s,mode){
    const gone=new Set(),held=Array(symbols.length).fill(0);let size=0;
    while(gone.size<s.tiles.length){
      const choices=s.tiles.filter(t=>!gone.has(t.id)&&s.blockers[t.id].every(id=>gone.has(id)));
      const exposed=Array(symbols.length).fill(0);choices.forEach(t=>exposed[t.type]++);
      const rank=t=>held[t.type]*100+(mode===0?exposed[t.type]*10:t.z);
      choices.sort((a,b)=>rank(b)-rank(a)||a.id-b.id);
      const tile=choices[0];gone.add(tile.id);held[tile.type]++;size++;
      if(held[tile.type]===3){held[tile.type]=0;size-=3;}
      if(size>=7)break;
    }
    return gone.size/s.tiles.length;
  }
  function deal(level,seed){
    let best=generate(level,seed);
    if(level<5)return best;
    // A bounded selection of solvable boards rejects easy greedy clear routes.
    const score=s=>Math.max(greedyProgress(s,0),greedyProgress(s,1));
    let difficulty=score(best);
    for(let attempt=1;attempt<5;attempt++){
      const candidate=generate(level,(seed+Math.imul(attempt,0x9e3779b9))>>>0),value=score(candidate);
      if(value<difficulty){best=candidate;difficulty=value;}
    }
    best.seed=seed;return best;
  }
  function collect(tray,tile,tiles){
    const next=tray.slice(),last=next.findLastIndex(id=>tiles[id].type===tile.type);
    next.splice(last<0?next.length:last+1,0,tile.id);
    const matches=next.filter(id=>tiles[id].type===tile.type);
    return matches.length===3?next.filter(id=>tiles[id].type!==tile.type):next;
  }
  function move(s,id){
    if(s.phase!=='playing'||!available(s).some(t=>t.id===id))throw Error('请选择没有被遮挡的牌');
    s.history.push({id,tray:s.tray.slice()});s.removed.push(id);s.tray=collect(s.tray,s.tiles[id],s.tiles);
    s.phase=s.removed.length===s.tiles.length?'won':s.tray.length>=7?'lost':'playing';return s;
  }
  function undo(s){const previous=s.history.pop();s.removed.pop();s.tray=previous.tray;s.phase='playing';return s;}
  function hint(s){
    // Reuse the construction witness whenever it still works after free play.
    const rest=s.solution.filter(id=>!s.removed.includes(id));let tray=s.tray.slice(),valid=true;
    for(const id of rest){tray=collect(tray,s.tiles[id],s.tiles);if(tray.length>=7){valid=false;break;}}
    if(valid)return {status:'solved',move:rest[0]};
    const bits=s.tiles.map(t=>1n<<BigInt(t.id)),all=(1n<<BigInt(s.tiles.length))-1n;
    const masks=s.blockers.map(ids=>ids.reduce((mask,id)=>mask|bits[id],0n)),seen=new Set();
    const started=performance.now();let nodes=0,limited=false;
    function search(gone,held){
      if(gone===all)return [];
      if(++nodes>120000||(nodes%256===0&&performance.now()-started>1200)){limited=true;return null;}
      const counts=Array(symbols.length).fill(0);held.forEach(id=>counts[s.tiles[id].type]++);
      const key=gone.toString(36)+':'+counts.join('');if(seen.has(key))return null;seen.add(key);
      const choices=s.tiles.filter(t=>(gone&bits[t.id])===0n&&(gone&masks[t.id])===masks[t.id]).sort((a,b)=>counts[b.type]-counts[a.type]||b.z-a.z);
      for(const tile of choices){
        const next=collect(held,tile,s.tiles);if(next.length>=7)continue;
        const route=search(gone|bits[tile.id],next);if(route)return [tile.id,...route];if(limited)return null;
      }
      return null;
    }
    const route=search(s.removed.reduce((mask,id)=>mask|bits[id],0n),s.tray);
    return route?{status:'solved',move:route[0]}:{status:limited?'limit':'deadend'};
  }
  return {levels,symbols,deal,available,move,undo,hint};
})();
