// Max-n evaluates each seat independently; multiplayer opponents are not one coalition.
self.onmessage=function(event){
  var data=event.data,sides=data.sides,level=data.level,deadline=performance.now()+[100,200,450,900,1600][level-1],expired=false;
  Chess.setSides(sides);
  function values(board){return sides.map(function(side){return Chess.progress(board,side);});}
  function order(board,turn){return Chess.legal(board,turn).map(function(move){var next=Chess.moved(board,move,turn);return {move:move,board:next,win:Chess.outcome(next,move,turn),score:Chess.progress(next,turn)};}).sort(function(a,b){return b.score-a.score;}).slice(0,12);}
  function search(board,turn,depth){
    if(performance.now()>=deadline){expired=true;return values(board);}if(!depth)return values(board);
    var moves=order(board,turn),best=null,index=sides.indexOf(turn);
    for(var item of moves){var score;if(item.win){score=sides.map(function(side){return side===turn?1000000+depth:-1000000-depth;});}else score=search(item.board,Chess.nextTurn(item.board,turn),depth-1);if(expired)break;if(best===null||score[index]>best[index])best=score;}
    return best===null?values(board):best;
  }
  var roots=order(data.board,data.turn),best=roots[0].move,index=sides.indexOf(data.turn);
  self.postMessage({type:'progress',move:best});
  for(var depth=1;depth<=[1,1,2,2,3][level-1];depth++){
    var scored=[];for(var item of roots){var score=item.win?1000000:search(item.board,Chess.nextTurn(item.board,data.turn),depth-1)[index];if(expired)break;scored.push({move:item.move,score:score});}
    if(expired)break;scored.sort(function(a,b){return b.score-a.score;});var pool=level===1?scored.filter(function(item){return item.score>=scored[0].score-24;}):[scored[0]];best=pool[Math.floor(Math.random()*pool.length)].move;self.postMessage({type:'progress',move:best});
  }
  self.postMessage({type:'done'});
};
