// Bounded iterative alpha-beta search shared by the three classic games.
// Evaluation and legal moves belong to each game's own rules module.
self.onmessage=function(event){
  var data=event.data,side=data.turn,level=data.level,deadline=performance.now()+[100,200,450,900,1600][level-1],expired=false;
  function other(s){return s===Chess.first?Chess.second:Chess.first;}
  function order(board,turn){
    return Chess.legal(board,turn).map(function(m){var b=Chess.moved(board,m,turn),end=Chess.outcome(b,m,turn);return {move:m,board:b,end:end,value:end&&end.winner===turn?1000000:Chess.evaluate(b,turn)};}).sort(function(a,b){return b.value-a.value;}).slice(0,Chess.searchWidth);
  }
  function search(board,turn,depth,alpha,beta){
    if(performance.now()>=deadline){expired=true;return 0;}
    if(!depth)return Chess.evaluate(board,turn);
    var moves=order(board,turn);
    if(!moves.length){
      if(Chess.nextTurn&&Chess.legal(board,other(turn)).length)return -search(board,other(turn),depth-1,-beta,-alpha);
      return Chess.evaluate(board,turn);
    }
    var best=-Infinity;
    for(var item of moves){
      var next=Chess.nextTurn?Chess.nextTurn(item.board,turn):other(turn);
      var value=item.end?(item.end.winner===turn?1000000+depth:item.end.winner===null?0:-1000000-depth):next===turn?search(item.board,turn,depth-1,alpha,beta):-search(item.board,next,depth-1,-beta,-alpha);
      if(expired)return 0;best=Math.max(best,value);alpha=Math.max(alpha,value);if(alpha>=beta)break;
    }return best;
  }
  var roots=order(data.board,side),best=roots[0].move;
  self.postMessage({type:'progress',move:best});
  for(var depth=1;depth<=Chess.searchDepth[level-1];depth++){
    var scored=[];
    for(var item of roots){
      var next=Chess.nextTurn?Chess.nextTurn(item.board,side):other(side);
      var value=item.end?(item.end.winner===side?1000000+depth:item.end.winner===null?0:-1000000-depth):next===side?search(item.board,side,depth-1,-Infinity,Infinity):-search(item.board,next,depth-1,-Infinity,Infinity);
      if(expired)break;scored.push({move:item.move,value:value});
    }
    if(expired)break;
    scored.sort(function(a,b){return b.value-a.value;});
    var pool=level===1?scored.filter(function(v){return v.value>=scored[0].value-25;}):[scored[0]];
    best=pool[Math.floor(Math.random()*pool.length)].move;
    self.postMessage({type:'progress',move:best});
  }
  self.postMessage({type:'done'});
};
