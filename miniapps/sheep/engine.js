// Every deal starts with a legal topological removal order. Types are assigned
// along that order with at most three open triples, so its tray never overflows.
var Sheep=(()=>{
  const levels=[{name:'散步',size:4,layers:2,side:2,kinds:6},{name:'牧场',size:5,layers:3,side:4,kinds:9},{name:'山坡',size:6,layers:4,side:4,kinds:12}];
  const symbols=['🐑','🥕','🌽','🍎','🍀','🌻','🍄','🥦','🍇','🍓','🧶','🔔'];
  function rng(seed){return ()=>{seed|=0;seed=seed+0x6D2B79F5|0;let t=Math.imul(seed^seed>>>15,1|seed);t=t+Math.imul(t^t>>>7,61|t)^t;return ((t^t>>>14)>>>0)/4294967296;};}
  const pick=(items,random)=>items[Math.floor(random()*items.length)];
  function blockers(tiles){return tiles.map(a=>tiles.filter(b=>b.z>a.z&&Math.abs(a.x-b.x)<.95&&Math.abs(a.y-b.y)<.95).map(b=>b.id));}
  function available(s){const gone=new Set(s.removed);return s.tiles.filter(t=>!gone.has(t.id)&&s.blockers[t.id].every(id=>gone.has(id)));}
  function deal(level,seed){
    const config=levels[level],random=rng(seed),tiles=[];
    for(let z=0;z<config.layers;z++)for(let y=0;y<config.size-z;y++)for(let x=0;x<config.size-z;x++)tiles.push({id:tiles.length,x:1+(6-config.size)/2+z*.5+x,y:.45+(6-config.size)/2+z*.5+y,z,type:0});
    for(let i=0;i<config.side;i++)tiles.push({id:tiles.length,x:i%2?7:0,y:config.side===2?3:2+Math.floor(i/2)*2,z:0,type:0});
    const block=blockers(tiles),remaining=new Set(tiles.map(t=>t.id)),order=[];
    while(remaining.size){const next=pick(tiles.filter(t=>remaining.has(t.id)&&block[t.id].every(id=>!remaining.has(id))),random);order.push(next.id);remaining.delete(next.id);}
    const quota=Array(config.kinds).fill(0),partial=Array(config.kinds).fill(0);
    for(let i=0;i<tiles.length/3;i++)quota[i%quota.length]+=3;
    for(const id of order){
      const open=partial.filter(n=>n>0).length;
      const candidates=quota.map((n,type)=>type).filter(type=>quota[type]>0&&(partial[type]>0||open<3));
      const type=pick(candidates,random);tiles[id].type=type;quota[type]--;partial[type]=(partial[type]+1)%3;
    }
    return {level,seed,tiles,blockers:block,solution:order,removed:[],tray:[],history:[],phase:'playing'};
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
