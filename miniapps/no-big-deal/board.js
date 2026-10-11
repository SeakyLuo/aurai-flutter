const OfficeBoard = (() => {
  const R = OfficeRules;
  function random(s, n) {
    s.rng = (Math.imul(s.rng, 1664525) + 1013904223) >>> 0;
    return Math.floor(s.rng / 4294967296 * n);
  }
  const empty = s => s.board.map((o,i)=>o ? -1 : i).filter(i=>i>=0);
  const neighbors = i => Array.from({length:16},(_,j)=>j).filter(j=>R.adjacent(i,j));
  function card(value=1,kind='file') {
    return {value, kind, wet:0, sticky:0, polluted:false, charge:0,
      burning:0, frozen:0, attach:kind==='stone'?['woodStand']:[], messy:0, urgent:kind==='urgent'?10:0,
      cancelled:false, note:null, timer:kind==='bomb'?8:0, brittle:0, direction:1};
  }
  function snapshot(o) {const {id,...fields}=o;return {...fields,attach:o.attach.slice()};}
  function fromCard(s,entry) {return {...snapshot(entry),id:++s.sequence};}
  function object(s,value=1,kind='file') {return fromCard(s,card(value,kind));}
  function zone(s, i, type, strong=false) {
    const z=s.zones[i];
    if(!z.types.includes(type)) z.types.push(type);
    if(type==='water'||type==='pollution'){
      z.types=z.types.filter(t=>t!==(type==='water'?'pollution':'water'));z.water=R.config.water;
      if(type==='water')z.types=z.types.filter(t=>t!=='fire');
    }
    if(type==='glue'){z.glue=R.config.glueUses;z.glueTurns=strong?R.config.strongGlue:R.config.weakGlue;}
    if(type==='danger') z.collapse=R.config.collapse;
    if(z.types.includes('fire')&&z.types.includes('danger')){
      z.collapse=0;z.types=z.types.filter(t=>t!=='danger');if(!z.types.includes('discard'))z.types.push('discard');
    }
  }
  function draw(s) {
    if(!s.pool.length){
      s.pool=s.deck.map(snapshot);
      if(!OfficeWelfare.active(s,'ordered'))for(let i=s.pool.length-1;i>0;i--){const j=random(s,i+1);[s.pool[i],s.pool[j]]=[s.pool[j],s.pool[i]];}
    }
    return s.pool.shift();
  }
  function preview(s) {
    const cells=empty(s);
    s.preview=cells.length?{cell:cells[random(s,cells.length)],value:s.forcedOnes?1:s.nextCard.value}:null;
  }
  function spawn(s) {
    const cells=empty(s);
    if(!cells.length){s.preview=null;return;}
    if(s.preview && s.board[s.preview.cell] && cells.length!==1){preview(s);return;}
    if(!s.preview)preview(s);
    const i=cells.length===1?cells[0]:s.preview.cell;
    s.board[i]=fromCard(s,s.forcedOnes?card(1):s.nextCard);if(s.forcedOnes)s.forcedOnes--;enter(s,i,s.board[i]);discard(s);s.nextCard=draw(s);preview(s);
  }
  function protect(o,type) {
    if(o.attach.includes('sleeve') && ['water','pollution','fire','ice'].includes(type))return true;
    if(o.attach.some(a=>['woodCage','metalCage'].includes(a)) && ['water','pollution','ice'].includes(type))return true;
    if(o.attach.includes('film')){o.attach.splice(o.attach.indexOf('film'),1);return true;}
    return false;
  }
  function water(s,i,o,polluted=false) {
    const z=s.zones[i];
    if(!polluted)o.polluted=false;
    if(protect(o,polluted?'pollution':'water'))return;
    const target=R.config.wetTurns+(s.phase===2?2:0);
    const add=Math.min(Math.max(0,target-o.wet),z.water);
    o.wet+=add;z.water-=add;o.burning=0;OfficeCampaign.wet(s,o);
    o.polluted=polluted;
    if(o.brittle){o.brittle-=2;if(o.brittle<=0)s.board[i]=null;}
    if(z.water<=0)z.types=z.types.filter(t=>!['water','pollution'].includes(t));
    if(o.charge){
      for(const j of [i-1,i+1])if(j>=0&&j<16&&Math.floor(j/4)===Math.floor(i/4)&&R.metal(s.board[j]))s.board[j].charge=Math.min(2,o.charge);
    }
    OfficeCampaign.washed(s,i,o);
  }
  function enter(s,i,o,types=s.zones[i].types) {
    const z=s.zones[i];
    if(types.includes('fire')){
      // Preserve the existing clear-wet / clear-sticky fire interaction.
      const wasWet=o.wet>0;o.wet=0;o.sticky=0;
      o.attach=o.attach.filter(a=>!['woodStand','woodCage'].includes(a));
      if(o.kind==='stone')o.brittle=5;
      else if(R.effect(o,'bomb')&&!o.frozen)o.timer=0;
      else if(!wasWet&&R.isFile(o)&&!OfficeWelfare.active(s,'fireSafety')&&!protect(o,'fire'))o.burning=R.config.burnTurns-(s.phase===2?2:0);
    }
    if(types.includes('water'))water(s,i,o);
    if(types.includes('pollution'))water(s,i,o,true);
    if(types.includes('glue')){
      if(o.attach.includes('sleeve')){
        o.attach.splice(o.attach.indexOf('sleeve'),1);z.types=z.types.filter(t=>t!=='glue');
      }else if(!protect(o,'glue')){
        o.sticky=z.glueTurns;z.glue--;
        if(z.glue<=0)z.types=z.types.filter(t=>t!=='glue');
      }
    }
    if(types.includes('electricity')&&R.metal(o))o.charge=2;
    if(types.includes('danger')){
      z.collapse-=z.types.includes('fire')||o.burning?z.collapse:[1,2,3,6][R.tier(o)];
      if(z.collapse<=0){z.types=z.types.filter(t=>t!=='danger');zone(s,i,'discard');}
    }
    if(R.effect(o,'bomb')&&o.timer===0&&!o.wet&&!o.frozen)blast(s,i,R.tier(o));
  }
  function tip(s,i) {
    if(s.props[i]==='tea'){
      s.props[i]=null;OfficeCampaign.spill(s);
      for(const j of [i,...neighbors(i).filter(j=>j%4===i%4||Math.floor(j/4)===Math.floor(i/4))])zone(s,j,'water');
      s.notices.push('茶杯打翻了，周围洒上清水。');
    }
  }
  function linked(s,i) {
    const found=new Set([i]),queue=[i];
    for(let k=0;k<queue.length;k++)for(const j of neighbors(queue[k])){
      if(s.board[queue[k]]?.sticky>0 && s.board[j]?.sticky>0 && !crossesBarrier(s,queue[k],j) && !found.has(j)){found.add(j);queue.push(j);}
    }
    return [...found];
  }
  function crossesBarrier(s,from,to) {
    const ax=from%4+.5,ay=Math.floor(from/4)+.5,bx=to%4+.5,by=Math.floor(to/4)+.5;
    return s.barriers.some(([a,b])=>{
      const vertical=b===a+1,line=vertical?a%4+1:Math.floor(a/4)+1;
      const delta=vertical?bx-ax:by-ay;if(!delta)return false;
      const t=(line-(vertical?ax:ay))/delta;if(t<=0||t>=1)return false;
      const cross=vertical?ay+t*(by-ay):ax+t*(bx-ax),low=vertical?Math.floor(a/4):a%4;
      return cross>=low&&cross<=low+1;
    });
  }
  function spark(s,i) {
    for(const j of neighbors(i)){
      const o=s.board[j];
      if(o&&R.effect(o,'bomb')&&!o.wet&&!o.frozen)blast(s,j,R.tier(o));
      else if(R.isFile(o)&&!o.wet&&!o.frozen&&!o.burning&&!OfficeWelfare.active(s,'fireSafety')&&!protect(o,'fire'))o.burning=R.config.burnTurns-(s.phase===2?2:0);
    }
    s.notices.push('带电物品碰撞，电火花点燃了附近的可燃物。');
  }
  function conduct(s) {
    const charges=new Map(s.board.flatMap((o,i)=>R.metal(o)&&o.charge>0?[[i,o.charge]]:[]));
    const transfers=new Map(),sparks=new Set(),machines=new Set(),consumed=new Set();
    for(const [i,charge] of charges){
      let destinations=neighbors(i).filter(j=>R.metal(s.board[j]));
      if(s.zones[i].types.includes('metal')){
        const region=new Set([i]),queue=[i];
        for(let k=0;k<queue.length;k++)for(const j of neighbors(queue[k]).filter(j=>j%4===queue[k]%4||Math.floor(j/4)===Math.floor(queue[k]/4))){
          if(s.zones[j].types.includes('metal')&&!region.has(j)){region.add(j);queue.push(j);}
        }
        const candidates=[...region].filter(j=>j!==i&&R.metal(s.board[j]));
        candidates.sort((a,b)=>(Math.abs(a%4-i%4)+Math.abs(Math.floor(a/4)-Math.floor(i/4)))-(Math.abs(b%4-i%4)+Math.abs(Math.floor(b/4)-Math.floor(i/4))));
        if(candidates.length)destinations.push(candidates[0]);
      }
      for(const j of new Set(destinations)){
        if(R.effect(s.board[j],'machine')){machines.add(j);consumed.add(i);}
        else if(charges.has(j)){sparks.add(i);sparks.add(j);}
        else transfers.set(j,Math.max(transfers.get(j)||0,charge));
      }
    }
    // Read the whole electrical network before consuming charge or triggering explosions.
    for(const i of new Set([...consumed,...machines,...sparks]))s.board[i].charge=0;
    for(const [i,charge] of transfers)if(!consumed.has(i)&&!machines.has(i)&&!sparks.has(i))s.board[i].charge=Math.max(s.board[i].charge,charge);
    for(const i of machines){s.score+=R.config.machineScore;s.stats.organized+=R.config.machineScore;s.notices.push('整理机启动，完成 '+R.config.machineScore+' 份整理。');}
    for(const i of sparks)spark(s,i);
  }
  function magneticSources(s) {
    return s.board.flatMap((o,i)=>o&&R.effect(o,'magnet')?[{cell:i,direction:o.direction}]:[]).concat(s.outsideMagnets);
  }
  function ray(source) {
    const [dx,dy]=[[0,-1],[1,0],[0,1],[-1,0]][source.direction];
    let x=source.cell!==null?source.cell%4:source.x,y=source.cell!==null?Math.floor(source.cell/4):source.y;
    const cells=[];
    for(x+=dx,y+=dy;x>=0&&x<4&&y>=0&&y<4;x+=dx,y+=dy)cells.push(y*4+x);
    return cells;
  }
  function cutField(s,from,to,o) {
    if(!R.metal(o)||from===to)return;
    for(const source of magneticSources(s)){
      if(source.cell===from)continue;
      if(source.direction%2===0&&from%4===to%4)continue;
      if(source.direction%2===1&&Math.floor(from/4)===Math.floor(to/4))continue;
      const beam=ray(source);
      const crossed=beam.some(i=>{
        const x=i%4+.5,y=Math.floor(i/4)+.5,ax=from%4+.5,ay=Math.floor(from/4)+.5,dx=to%4-from%4,dy=Math.floor(to/4)-Math.floor(from/4);
        const t=((x-ax)*dx+(y-ay)*dy)/(dx*dx+dy*dy);
        return t>=0&&t<=1&&Math.hypot(ax+t*dx-x,ay+t*dy-y)<.51;
      });
      if(crossed){o.charge=Math.max(1,o.charge);o.induced=true;return;}
    }
  }
  function discard(s) {
    const seen=new Set();
    for(let i=0;i<16;i++){
      if(!s.board[i]||seen.has(i))continue;
      const group=linked(s,i);group.forEach(j=>seen.add(j));
      const falling=group.filter(j=>s.zones[j].types.includes('discard'));
      if(!falling.length)continue;
      const supported=group.some(j=>!falling.includes(j)&&falling.every(k=>R.weight(s.board[j])>R.weight(s.board[k])));
      if(supported)continue;
      for(const j of group){
        const o=s.board[j];
        if(R.effect(o,'waste')){s.score+=o.value;s.stats.waste+=o.value;s.stats.organized+=o.value;}
        s.board[j]=null;
      }
      s.notices.push('文件掉进了废弃区。');
    }
  }
  function blast(s,i,size) {
    const nearby=neighbors(i).filter(j=>s.board[j]);
    nearby.sort((a,b)=>(Math.abs(a%4-i%4)+Math.abs(Math.floor(a/4)-Math.floor(i/4)))-(Math.abs(b%4-i%4)+Math.abs(Math.floor(b/4)-Math.floor(i/4))));
    const cells=nearby.slice(0,size===0?1:size===1?4:8);
    s.board[i]=null;
    for(const j of cells){
      const o=s.board[j];
      if(o?.kind==='bomb'&&!o.wet&&!o.frozen&&!o.polluted)blast(s,j,R.tier(o));
      else if(o?.kind==='stone'){o.brittle=5;}
      else s.board[j]=null;
    }
    if(size>=2)zone(s,i,'discard');
    s.notices.push('炸弹爆炸，清空了附近的物品。');
  }
  function tick(s) {
    conduct(s);
    const extinguish=[],ignite=[];
    for(let i=0;i<16;i++){
      const z=s.zones[i],o=s.board[i];
      if(z.types.includes('danger')&&--z.collapse<=0){z.types=z.types.filter(t=>t!=='danger');zone(s,i,'discard');}
      if(o){
        if(z.types.includes('water'))water(s,i,o);
        if(z.types.includes('pollution'))water(s,i,o,true);
        const paused=o.wet>0||o.frozen>0;
        if(o.wet)o.wet=Math.max(0,o.wet-1);
        if(o.sticky)o.sticky--;
        if(o.frozen)o.frozen--;
        if(o.charge&&!o.induced)o.charge--;o.induced=false;
        if(R.effect(o,'urgent')){if(o.urgent>0)o.urgent--;else s.patience=Math.max(0,s.patience-1);}
        if(o.temporary){o.temporary--;if(!o.temporary)extinguish.push(i);}
        if(o.burning){
          o.burning--;
          if(o.burning>0&&o.burning%2===0)ignite.push(...neighbors(i));
          if(!o.burning)extinguish.push(i);
        }
        if(R.effect(o,'bomb')&&!paused){if(z.types.includes('fire'))o.timer=0;o.timer--;if(o.timer<=0)blast(s,i,R.tier(o));}
      }
      if(z.types.some(t=>t==='water'||t==='pollution')){
        z.water=Math.max(0,z.water-1);
        if(!z.water)z.types=z.types.filter(t=>!['water','pollution'].includes(t));
      }
    }
    for(const i of new Set(ignite)){
      const o=s.board[i];
      if(o&&R.effect(o,'bomb')&&!o.wet&&!o.frozen)blast(s,i,R.tier(o));
      else if(o&&R.isFile(o)&&!o.wet&&!o.frozen&&!o.burning&&!OfficeWelfare.active(s,'fireSafety')&&!protect(o,'fire'))o.burning=R.config.burnTurns-(s.phase===2?2:0);
    }
    for(const i of extinguish)s.board[i]=null;
    for(const change of s.delayed){
      change.turns--;
      if(change.turns===0){const o=s.board.find(o=>o?.id===change.id);if(o)o.value=change.value;}
    }
    s.delayed=s.delayed.filter(change=>change.turns>0);
    discard(s);magnets(s);discard(s);
  }
  function magnets(s) {
    for(const source of magneticSources(s)){
      const cells=ray(source);if(!cells.length)continue;
      const target=cells[0];if(s.board[target])continue;
      for(const j of cells){
        const o=s.board[j];
        if(!R.metal(o))continue;
        if(!o.frozen&&!o.attach.some(a=>['woodStand','metalStand','tape'].includes(a))&&!crossesBarrier(s,j,target)){
          s.board[j]=null;s.board[target]=o;enter(s,target,o);
        }
        break;
      }
    }
  }
  return {random,empty,neighbors,card,snapshot,fromCard,object,zone,draw,preview,spawn,protect,water,enter,tip,linked,discard,tick,blast,crossesBarrier,cutField,spark,conduct,magnets};
})();
