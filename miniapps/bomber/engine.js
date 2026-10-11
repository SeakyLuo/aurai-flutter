const Bomber=(()=>{
  const size=11,dirs=[[0,-1],[1,0],[0,1],[-1,0]],key=(x,y)=>y*size+x;
  const xy=i=>[i%size,Math.floor(i/size)],inside=(x,y)=>x>=0&&x<size&&y>=0&&y<size;
  function random(s){let v=s.rng|0;v^=v<<13;v^=v>>>17;v^=v<<5;s.rng=v>>>0;return s.rng/4294967296;}
  function create(seed,mode,arenaMode='classic',playerCount=4){
    const config=BomberRules.modes[arenaMode];
    const s={rulesVersion:3,seed,rng:seed||1,mode,arenaMode,time:0,phase:'playing',winner:null,reason:null,board:[],bombs:[],flames:[],items:[],destroyed:0,serial:0};
    for(let y=0;y<size;y++)for(let x=0;x<size;x++)s.board.push(x===0||y===0||x===10||y===10||x%2===0&&y%2===0?1:0);
    const spawns=[[1,1],[9,9],[9,1],[1,9]].slice(0,playerCount),safe=new Set();
    for(const [sx,sy] of spawns)for(const [x,y] of [[1,1],[2,1],[3,1],[1,2],[1,3],[3,2],[2,3]])safe.add(key(sx===1?x:10-x,sy===1?y:10-y));
    s.board=s.board.map((v,i)=>v||safe.has(i)?v:random(s)<config.density?2:0);
    s.players=spawns.map(([x,y],i)=>({x,y,step:i===0?.16:.24,alive:true,range:arenaMode==='power'?3:1,capacity:arenaMode==='power'?3:1,next:0,walk:null,speed:0,shield:arenaMode==='power'?1:0,protectedUntil:0,glove:false,pierce:0,quick:0,score:0}));
    return s;
  }
  function blast(board,b){
    const cells=[key(b.x,b.y)];
    for(const [dx,dy] of dirs)for(let n=1;n<=b.range;n++){
      const x=b.x+dx*n,y=b.y+dy*n;if(!inside(x,y))break;
      const i=key(x,y);if(board[i]===1)break;cells.push(i);if(board[i]===2&&!b.pierce)break;
    }
    return cells;
  }
  function forecast(s){
    const board=s.board.slice(),pending=s.bombs.map(b=>({...b})),windows=new Map(),closures=s.arenaMode==='rush'?[45,65,85].filter(at=>at>s.time):[];
    function add(i,start,end){if(!windows.has(i))windows.set(i,[]);windows.get(i).push([start,end]);}
    for(const f of s.flames)add(f.i,s.time,f.end);
    for(let i=0;i<size*size;i++){const at=BomberRules.collapseAt(s,i);if(at!==Infinity)add(i,at,Infinity);}
    while(pending.length||closures.length){
      const close=closures[0];
      if(close!==undefined&&(!pending.length||close<=Math.min(...pending.map(b=>b.at)))){
        closures.shift();for(let i=0;i<board.length;i++)if(BomberRules.collapseAt(s,i)<=close)board[i]=1;
        for(let i=pending.length-1;i>=0;i--)if(board[key(pending[i].x,pending[i].y)]===1)pending.splice(i,1);
        continue;
      }
      pending.sort((a,b)=>a.at-b.at);const at=pending[0].at,group=pending.filter(b=>b.at===at),hit=new Set();
      for(const b of group)for(const i of blast(board,b))hit.add(i);
      let changed=true;
      while(changed){changed=false;for(const b of pending)if(b.at!==at&&hit.has(key(b.x,b.y))){b.at=at;group.push(b);for(const i of blast(board,b))hit.add(i);changed=true;}}
      for(const i of hit){add(i,at,at+.52);if(board[i]===2)board[i]=0;}
      for(let i=pending.length-1;i>=0;i--)if(pending[i].at===at)pending.splice(i,1);
    }
    return windows;
  }
  const danger=(windows,i,a,b)=> (windows.get(i)||[]).some(([start,end])=>start<=b&&end>a);
  function routes(s,who,extra=null){
    const sim=extra?{...s,bombs:[...s.bombs,extra]}:s,p=s.players[who],windows=forecast(sim),origin=key(p.x,p.y);
    const bombs=new Map(sim.bombs.map(b=>[key(b.x,b.y),b.at])),out=[],safeCells=new Set(),queue=[{i:origin,t:0,path:[]}],seen=new Set([origin+':0']);
    const end=Math.max(s.time+1,...sim.bombs.map(b=>b.at+.6));
    for(let q=0;q<queue.length;q++){
      const node=queue[q],at=s.time+node.t*p.step;
      if(!safeCells.has(node.i)&&!danger(windows,node.i,at,end)&&(!bombs.has(node.i)||bombs.get(node.i)<=at)){out.push(node);safeCells.add(node.i);}
      if(node.t>=18)continue;
      const [x,y]=xy(node.i);
      for(const [dx,dy] of [...dirs,[0,0]]){
        const nx=x+dx,ny=y+dy,i=key(nx,ny),arrival=at+p.step;
        if(!inside(nx,ny)||s.board[i]!==0||occupied(s,who,nx,ny))continue;
        if(bombs.has(i)&&bombs.get(i)+.52>arrival&&!(i===origin&&node.path.every(n=>n===origin)))continue;
        if(danger(windows,node.i,at,arrival)||danger(windows,i,at,arrival+.04))continue;
        const mark=i+':'+(node.t+1);if(seen.has(mark))continue;seen.add(mark);
        queue.push({i,t:node.t+1,path:[...node.path,i]});
      }
    }
    return out;
  }
  const occupied=(s,who,x,y)=>s.players.some((p,i)=>i!==who&&p.alive&&p.x===x&&p.y===y);
  const opponents=(s,who)=>s.players.filter((p,i)=>i!==who&&p.alive);
  function canBomb(s,who){const p=s.players[who];return p.alive&&s.bombs.filter(b=>b.owner===who).length<p.capacity&&!s.bombs.some(b=>b.x===p.x&&b.y===p.y);}
  function previewBomb(s,who){const p=s.players[who],fuse=p.quick>0?1.6:2.5;return{x:p.x,y:p.y,range:p.range,owner:who,at:s.time+fuse,fuse,pierce:p.pierce>0};}
  function place(s,who){
    if(s.phase!=='playing'||!canBomb(s,who))return false;
    const b=previewBomb(s,who),p=s.players[who];b.id=++s.serial;s.bombs.push(b);if(p.pierce>0)p.pierce--;if(p.quick>0)p.quick--;return true;
  }
  function move(s,who,dir){
    const p=s.players[who];if(s.phase!=='playing'||!p.alive||s.time+.0001<p.next)return false;
    const [dx,dy]=dirs[dir],x=p.x+dx,y=p.y+dy;
    if(!inside(x,y)||s.board[key(x,y)]!==0||occupied(s,who,x,y))return false;
    const bomb=s.bombs.find(b=>b.x===x&&b.y===y);
    if(bomb){
      const bx=x+dx,by=y+dy;
      if(!p.glove||!inside(bx,by)||s.board[key(bx,by)]!==0||s.bombs.some(b=>b.x===bx&&b.y===by)||occupied(s,who,bx,by))return false;
      bomb.x=bx;bomb.y=by;
    }
    p.walk={x:p.x,y:p.y,at:s.time};p.x=x;p.y=y;p.next=s.time+p.step;
    const item=s.items.findIndex(v=>v.i===key(x,y));
    if(item>=0)BomberRules.collect(s,who,s.items.splice(item,1)[0].type);
    BomberRules.finish(s);
    return true;
  }
  function step(s,dt){
    if(s.phase!=='playing')return;
    s.time+=dt;s.flames=s.flames.filter(f=>f.end>s.time);
    for(let i=0;i<s.board.length;i++)if(BomberRules.collapseAt(s,i)<=s.time){s.board[i]=1;for(const p of s.players)if(key(p.x,p.y)===i)p.alive=false;}
    s.bombs=s.bombs.filter(b=>s.board[key(b.x,b.y)]!==1);s.items=s.items.filter(item=>s.board[item.i]!==1);
    const hit=new Set(),owners=new Map(),exploding=s.bombs.filter(b=>b.at<=s.time);
    for(let q=0;q<exploding.length;q++){
      for(const i of blast(s.board,exploding[q])){
        hit.add(i);if(!owners.has(i))owners.set(i,exploding[q].owner);for(const b of s.bombs)if(key(b.x,b.y)===i&&!exploding.includes(b))exploding.push(b);
      }
    }
    if(hit.size){
      s.bombs=s.bombs.filter(b=>!exploding.includes(b));s.items=s.items.filter(v=>!hit.has(v.i));
      for(const i of hit){
        s.flames.push({i,end:s.time+.52});
        if(s.board[i]===2){s.board[i]=0;s.destroyed++;s.players[owners.get(i)].score++;if(random(s)<BomberRules.modes[s.arenaMode].drop){const types=Object.keys(BomberRules.items);s.items.push({i,type:types[Math.floor(random(s)*types.length)]});}}
      }
    }
    for(const p of s.players)if(p.alive&&p.protectedUntil<=s.time&&s.flames.some(f=>f.i===key(p.x,p.y))){if(p.shield>0){p.shield--;p.protectedUntil=s.time+1;}else p.alive=false;}
    BomberRules.finish(s);
  }
  function nearCrates(s,i){const [x,y]=xy(i);return dirs.filter(([dx,dy])=>s.board[key(x+dx,y+dy)]===2).length;}
  function tactics(s,who){
    const p=s.players[who],enemies=opponents(s,who),safe=routes(s,who),distance=i=>{const[x,y]=xy(i);return Math.min(...enemies.map(e=>Math.abs(x-e.x)+Math.abs(y-e.y)));};
    return {arenaMode:s.arenaMode,modeRules:BomberRules.modes[s.arenaMode].description,self:{x:p.x,y:p.y,range:p.range,bombCapacity:p.capacity,shield:p.shield,glove:p.glove,piercingBombs:p.pierce,quickBombs:p.quick,score:p.score},opponents:s.players.flatMap((e,i)=>i!==who&&e.alive?[{name:BomberRules.playerName(s,i),x:e.x,y:e.y,shield:e.shield,score:e.score}]:[]),remainingSeconds:Math.ceil(BomberRules.modes[s.arenaMode].duration-s.time),
      nearbyCrates:nearCrates(s,key(p.x,p.y)),visiblePowerups:s.items.length,opponentDistance:distance(key(p.x,p.y)),safeDestinations:new Set(safe.map(v=>v.i)).size,
      instructions:'Choose a tactical intention. Local controls execute movement and escape explosions. No hidden player inputs are available.'};
  }
  function bot(s,who,tactic){
    const p=s.players[who],enemies=opponents(s,who);if(s.phase!=='playing'||!p.alive||s.time<p.next)return;
    let paths=routes(s,who);if(!paths.length)return;
    if(tactic==='power'&&!s.items.some(item=>paths.some(node=>node.i===item.i)))tactic='break';
    const origin=key(p.x,p.y),windows=forecast(s),urgent=danger(windows,origin,s.time,s.time+.9);
    const distance=i=>{const[x,y]=xy(i);return Math.min(...enemies.map(e=>Math.abs(x-e.x)+Math.abs(y-e.y)));};
    if(p.glove&&!urgent&&tactic==='hunt'){
      const direction=dirs.findIndex(([dx,dy])=>s.bombs.some(b=>b.x===p.x+dx&&b.y===p.y+dy)&&distance(key(p.x+dx,p.y+dy))<distance(origin));
      if(direction>=0){const[dx,dy]=dirs[direction],b=s.bombs.find(b=>b.x===p.x+dx&&b.y===p.y+dy),sim=structuredClone(s);sim.bombs.find(v=>v.id===b.id).x+=dx;sim.bombs.find(v=>v.id===b.id).y+=dy;sim.players[who].x+=dx;sim.players[who].y+=dy;
        if(inside(b.x+dx,b.y+dy)&&s.board[key(b.x+dx,b.y+dy)]===0&&routes(sim,who).length&&move(s,who,direction))return;
      }
    }
    if(!urgent&&(tactic==='hunt'||tactic==='break')&&canBomb(s,who)){
      const b=previewBomb(s,who),cells=blast(s.board,b),useful=tactic==='hunt'?enemies.some(e=>cells.includes(key(e.x,e.y)))||nearCrates(s,origin)>0:nearCrates(s,origin)>0;
      const escape=useful?routes(s,who,b):[];
      if(escape.length){place(s,who);paths=escape;}
    }
    const score=node=>{
      if(urgent||s.bombs.some(b=>b.x===p.x&&b.y===p.y))return -node.t;
      if(tactic==='power'&&s.items.length){const[x,y]=xy(node.i);return -Math.min(...s.items.map(v=>{const[a,b]=xy(v.i);return Math.abs(a-x)+Math.abs(b-y);}))*4-node.t*.1;}
      if(tactic==='break')return nearCrates(s,node.i)*5-node.t*.25;
      if(tactic==='retreat')return distance(node.i)-node.t*.3;
      return -distance(node.i)-node.t*.15;
    };
    paths.sort((a,b)=>score(b)-score(a));const next=paths[0].path[0];
    if(next!==undefined&&next!==origin){const[x,y]=xy(next);move(s,who,dirs.findIndex(([dx,dy])=>p.x+dx===x&&p.y+dy===y));}else p.next=s.time+p.step;
  }
  function localTactic(s,who){const p=s.players[who];return s.items.length?'power':opponents(s,who).some(e=>Math.abs(p.x-e.x)+Math.abs(p.y-e.y)<=3)?'hunt':nearCrates(s,key(p.x,p.y))?'break':'hunt';}
  return{size,dirs,key,xy,create,blast,forecast,danger,routes,canBomb,place,move,step,bot,tactics,localTactic};
})();
