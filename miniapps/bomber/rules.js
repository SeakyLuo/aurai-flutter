const BomberRules=(()=>{
  const modes={
    classic:{name:'经典对战',description:'炸箱成长，击败对手。三分钟内分出胜负。',duration:180,density:.68,drop:.38},
    rush:{name:'限时缩圈',description:'45 秒后开始缩圈，之后每 20 秒收紧一圈。别被困在边缘。',duration:120,density:.48,drop:.45},
    loot:{name:'道具争夺',description:'炸箱得 1 分，拾取道具得 2 分。先到 20 分，或击败对手获胜。',duration:120,density:.72,drop:.75},
    power:{name:'火力全开',description:'开局三枚炸弹、三格火力和一层护盾，更多道具、更快交锋。',duration:120,density:.36,drop:.65}
  };
  const items={
    range:{name:'火力',symbol:'✦',description:'爆炸范围增加一格，最多五格。',color:'#f6dfb7'},
    capacity:{name:'弹袋',symbol:'+',description:'可同时放置的炸弹增加一枚，最多三枚。',color:'#c5f1d6'},
    speed:{name:'加速鞋',symbol:'»',description:'永久提升移动速度，最多提升三次。',color:'#c9e7ff'},
    shield:{name:'护盾',symbol:'◇',description:'抵挡一次爆炸，并获得一秒保护；无法抵挡缩圈。最多两层。',color:'#bedff8'},
    glove:{name:'推弹手套',symbol:'↗',description:'朝炸弹移动可将它向前推一格，前方必须为空地。',color:'#f6d1bd'},
    pierce:{name:'穿透弹',symbol:'⇥',description:'接下来三枚炸弹穿透木箱，仍会被石墙阻挡。',color:'#e0cef6'},
    quick:{name:'快爆弹',symbol:'ϟ',description:'接下来三枚炸弹在 1.6 秒后爆炸，记得提前撤离。',color:'#ffe5a2'}
  };
  function collapseAt(s,i){const[x,y]=[i%11,Math.floor(i/11)],ring=Math.min(x,y,10-x,10-y);return s.arenaMode==='rush'&&ring>=1&&ring<=3?45+(ring-1)*20:Infinity;}
  function collect(s,who,type){
    const p=s.players[who];p.score+=2;
    if(type==='range')p.range=Math.min(5,p.range+1);
    if(type==='capacity')p.capacity=Math.min(3,p.capacity+1);
    if(type==='speed'){p.speed=Math.min(3,p.speed+1);p.step=(who===0?.16:.24)-p.speed*.016;}
    if(type==='shield')p.shield=Math.min(2,p.shield+1);
    if(type==='glove')p.glove=true;
    if(type==='pierce')p.pierce+=3;
    if(type==='quick')p.quick+=3;
  }
  function finish(s){
    const living=s.players.map((p,i)=>i).filter(i=>s.players[i].alive);
    if(living.length<=1){s.phase='ended';s.reason='elimination';s.winner=living.length?living[0]:null;return;}
    if(s.arenaMode==='loot'&&(living.some(i=>s.players[i].score>=20)||s.time>=modes.loot.duration)){
      const best=Math.max(...living.map(i=>s.players[i].score)),leaders=living.filter(i=>s.players[i].score===best);
      s.phase='ended';s.reason='score';s.winner=leaders.length===1?leaders[0]:null;return;
    }
    if(s.time>=modes[s.arenaMode].duration){s.phase='ended';s.reason='time';s.winner=null;}
  }
  const colors=['#80dfca','#f1a28e','#b8a5ed','#f0cc78'];
  const playerName=(s,i)=>i===0?'你':`${s.mode==='jev'?'Jev':'电脑'} ${i}`;
  return{modes,items,colors,playerName,collapseAt,collect,finish};
})();
