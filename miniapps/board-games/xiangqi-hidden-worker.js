// Information-set sampling: identities are sampled from the publicly unseen
// pool. The host never sends its actual hidden layout to this worker.
self.onmessage=function(event){
  var v=event.data,Chess=XiangqiModes.get(v.mode),level=v.level,deadline=performance.now()+[100,200,450,900,1600][level-1];
  var actor=v.players.find(function(p){return p.side===v.turn;}).id;
  var values=v.mode==='banqi'?{K:550,A:500,E:400,R:350,H:280,C:450,P:220}:{K:15000,A:250,E:250,R:900,H:430,C:450,P:120,D:350};
  function other(side){return side==='r'?'b':'r';}
  function shuffle(a){for(var i=a.length-1;i>0;i--){var j=Math.floor(Math.random()*(i+1)),t=a[i];a[i]=a[j];a[j]=t;}return a;}
  function sample(){
    var bags={r:shuffle(v.unseenPieces.filter(function(p){return p[0]==='r';})),b:shuffle(v.unseenPieces.filter(function(p){return p[0]==='b';})),all:shuffle(v.unseenPieces.slice())};
    return {mode:v.mode,board:v.board.slice(),hidden:v.board.map(function(p){return p&&p[1]==='D'?(v.mode==='banqi'?bags.all.pop():bags[p[0]].pop()):null;}),players:v.players.map(function(p){return Object.assign({},p);}),turn:v.turn,quiet:v.quiet,colorsAssigned:v.colorsAssigned,revealed:[],winner:null,phase:'playing'};
  }
  function after(s,m){
    var n=Object.assign({},s,{board:s.board.slice(),hidden:s.hidden.slice(),revealed:s.revealed.slice(),players:s.players.map(function(p){return Object.assign({},p);})});
    Chess.play(n,m);var side=n.turn;n.turn=other(side);
    if(Chess.judge){var end=Chess.judge(n,m,side);if(end){n.phase='finished';n.winner=end.winner;}}
    else if(n.board.indexOf(n.turn+'K')<0){n.phase='finished';n.winner=side;}
    return n;
  }
  function evaluate(s){
    var side=s.players.find(function(p){return p.id===actor;}).side;
    if(s.phase==='finished')return s.winner===null?0:s.winner===side?100000:-100000;
    var score=0;
    s.board.forEach(function(p,i){if(!p||p==='uD')return;var value=values[p[1]],x=i%Chess.width,y=Math.floor(i/Chess.width);if(v.mode==='jieqi'){value+=Math.min(x,8-x)*3;if(p[1]==='P')value+=(p[0]==='r'?9-y:y)*9;}score+=p[0]===side?value:-value;});
    return score;
  }
  function search(s,depth){
    if(!depth||s.phase==='finished'||performance.now()>=deadline)return evaluate(s);
    var side=s.players.find(function(p){return p.id===actor;}).side,maximize=s.turn===side,moves=Chess.legal(s.board,s.turn);
    if(!moves.length)return maximize?-100000:100000;
    var ranked=moves.map(function(m){var n=after(s,m);return {state:n,score:evaluate(n)};}).sort(function(a,b){return maximize?b.score-a.score:a.score-b.score;}).slice(0,[3,4,5,6,8][level-1]);
    var best=maximize?-Infinity:Infinity;
    for(var item of ranked){var score=search(item.state,depth-1);best=maximize?Math.max(best,score):Math.min(best,score);if(performance.now()>=deadline)break;}
    return best;
  }
  var roots=v.legalMoves.map(function(m){return {move:m,total:0};}),best=roots[0].move;
  self.postMessage({type:'progress',move:best});
  for(var trial=0;trial<[2,4,8,12,18][level-1];trial++){
    var state=sample(),scores=[];
    for(var root of roots){scores.push(search(after(state,root.move),trial===0?0:[0,0,1,1,2][level-1]));if(performance.now()>=deadline)break;}
    if(scores.length!==roots.length)break;
    roots.forEach(function(r,i){r.total+=scores[i];});
    var ranked=roots.slice().sort(function(a,b){return b.total-a.total;});
    var tied=ranked.filter(function(r){return Math.abs(r.total-ranked[0].total)<.01;});best=tied[Math.floor(Math.random()*tied.length)].move;
    self.postMessage({type:'progress',move:best});if(performance.now()>=deadline)break;
  }
  self.postMessage({type:'done'});
};
