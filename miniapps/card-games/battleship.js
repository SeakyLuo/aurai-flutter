// Classic alternating-shot naval combat. Fleet sizes follow Hasbro Battleship.
// https://instructions.hasbro.com/en-us/instruction/Battleship-Classic-Board-Game-Strategy-Game
var Cards=(function(){
  var sizes=[5,4,3,3,2],names=['航空母舰','战列舰','巡洋舰','潜艇','驱逐舰'];
  function require(ok,text){if(!ok)throw Error(text);}
  function random(s){s.seed=(Math.imul(s.seed,1664525)+1013904223)>>>0;return s.seed/4294967296;}
  function coordinate(cell){return 'ABCDEFGHIJ'[Math.floor(cell/10)]+(cell%10+1);}
  function placements(length){
    var result=[];
    for(var y=0;y<10;y++)for(var x=0;x<10;x++)for(var axis=0;axis<2;axis++){
      if(x+(axis===0?length:1)>10||y+(axis===1?length:1)>10)continue;
      var cells=[];for(var k=0;k<length;k++)cells.push(y*10+x+k*(axis===0?1:10));result.push(cells);
    }
    return result;
  }
  var patterns=sizes.map(placements);
  function fleet(s){
    var occupied=[],ships=[];
    sizes.forEach(function(length,i){var legal=patterns[i].filter(function(cells){return cells.every(function(c){return occupied.indexOf(c)<0;});});var cells=legal[Math.floor(random(s)*legal.length)];occupied=occupied.concat(cells);ships.push(cells.slice());});
    return ships;
  }
  function log(s,seat,text){s.logs.push({seat:seat,text:text});s.logs=s.logs.slice(-12);}
  function create(players,seed){var s={phase:'playing',stage:'deploy',players:players,seed:seed>>>0,turn:0,ready:[false,false],shots:[Array(100).fill(0),Array(100).fill(0)],sunk:[[],[]],logs:[],winner:null,result:''};s.fleets=[fleet(s),fleet(s)];return s;}
  function apply(s,seat,action,data){
    require(s.phase==='playing'&&s.turn===seat,'尚未轮到你');
    if(s.stage==='deploy'){
      if(action==='shuffle'){s.fleets[seat]=fleet(s);return;}
      require(action==='deploy','请确认舰队位置');s.ready[seat]=true;log(s,seat,'舰队准备就绪');
      if(s.ready.every(Boolean)){s.stage='battle';s.turn=0;}else s.turn=1-seat;return;
    }
    require(action==='fire','请选择目标海域');var cell=data.cell;
    require(Number.isInteger(cell)&&cell>=0&&cell<100,'请选择有效坐标');require(s.shots[seat][cell]===0,'这片海域已经射击过');
    var ship=s.fleets[1-seat].find(function(cells){return cells.indexOf(cell)>=0;});s.shots[seat][cell]=ship?2:1;
    if(ship&&ship.every(function(c){return s.shots[seat][c]===2;})){
      s.sunk[seat].push(ship.slice());ship.forEach(function(c){s.shots[seat][c]=3;});
      log(s,seat,coordinate(cell)+' · 击沉'+names[s.fleets[1-seat].indexOf(ship)]);
    }else log(s,seat,coordinate(cell)+(ship?' · 命中':' · 落空'));
    if(s.sunk[seat].length===5){s.phase='finished';s.stage='finished';s.winner=seat;s.result=s.players[seat].name+'的舰队获胜';}
    else s.turn=1-seat;
  }
  function publicView(s){return {phase:s.phase,stage:s.stage,players:s.players,turn:s.turn,ready:s.ready,shots:s.shots,sunk:s.sunk,remaining:[5-s.sunk[1].length,5-s.sunk[0].length],logs:s.logs,winner:s.winner,result:s.result};}
  function privateView(s,seat){return {seat:seat,fleet:s.fleets[seat]};}
  function ai(own,v){
    if(v.stage==='deploy')return {action:'deploy',data:{}};
    // Score only placements consistent with publicly observed shots. No opponent fleet enters this function.
    var shots=v.shots[own.seat],remaining=sizes.slice(),scores=Array(100).fill(0);
    v.sunk[own.seat].forEach(function(cells){remaining.splice(remaining.indexOf(cells.length),1);});
    remaining.forEach(function(length){placements(length).forEach(function(cells){
      if(cells.some(function(c){return shots[c]===1||shots[c]===3;}))return;
      var covered=cells.filter(function(c){return shots[c]===2;}).length;
      var weight=covered?Math.pow(16,covered):1;
      cells.forEach(function(c){if(shots[c]===0)scores[c]+=weight;});
    });});
    var candidates=shots.map(function(n,c){return n===0?c:-1;}).filter(function(c){return c>=0;});
    candidates.sort(function(a,b){return scores[b]-scores[a];});
    // Random tie-breaks avoid repeating a fixed opening without acquiring hidden information.
    var best=candidates.filter(function(c){return scores[c]===scores[candidates[0]];});
    return {action:'fire',data:{cell:best[Math.floor(Math.random()*best.length)]}};
  }
  return {title:'海战棋',seats:2,create:create,apply:apply,publicView:publicView,privateView:privateView,ai:ai,coordinate:coordinate,names:names,
    rules:'双方各有一片 10×10 海域，以及长度为 5、4、3、3、2 的五艘舰船。舰船只能横向或纵向布置，不能重叠，可以相邻。布阵时可随机重排，确认后位置固定。\n双方轮流选择对方海域中的一个坐标射击，每回合一发；命中也不追加行动。同一格不能重复射击。舰船全部格子被命中时击沉，并公开它的位置。最先击沉对方全部五艘舰船者获胜。\n对方未击沉舰船的位置始终隐藏。本地 AI 根据已知命中、落空和剩余舰长选择目标，不读取你的舰队位置。'};
})();
