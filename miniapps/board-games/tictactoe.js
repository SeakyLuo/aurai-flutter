var Chess = (function () {
  var lines=[[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
  var order=[4,0,2,6,8,1,3,5,7];
  function coordinate(p) { return String.fromCharCode(65+p[0])+(p[1]+1); }
  function legal(board) {
    return order.filter(function(i){return board[i]===null;}).map(function(i){return {to:[i%3,Math.floor(i/3)]};});
  }
  function winner(board) {
    return lines.find(function(line){return board[line[0]]!==null&&line.every(function(i){return board[i]===board[line[0]];});});
  }
  function winningLine(board) {
    return (winner(board)||[]).map(function(i){return [i%3,Math.floor(i/3)];});
  }
  function other(side) { return side==='x'?'o':'x'; }
  // Negamax explores the complete remaining tree. Depth scores prefer quick
  // wins and delay forced losses; alpha-beta pruning skips irrelevant branches.
  function score(board,side,depth,alpha,beta) {
    if(winner(board))return depth-10;
    var moves=legal(board);
    if(!moves.length)return 0;
    var best=-Infinity;
    for(var i=0;i<moves.length;i++) {
      var p=moves[i].to,index=p[1]*3+p[0];board[index]=side;
      var value=-score(board,other(side),depth+1,-beta,-alpha);
      board[index]=null;best=Math.max(best,value);alpha=Math.max(alpha,value);
      if(alpha>=beta)break;
    }
    return best;
  }
  function bestMove(board,side) {
    var copy=board.slice(),best=-Infinity,chosen;
    legal(copy).forEach(function(move){
      var index=move.to[1]*3+move.to[0];copy[index]=side;
      var value=-score(copy,other(side),1,-Infinity,Infinity);copy[index]=null;
      if(value>best){best=value;chosen=move;}
    });
    return chosen;
  }
  function play(s,move) {
    var to=move.to;s.board[to[1]*3+to[0]]=s.turn;
    return {to:to,piece:s.turn,text:(s.turn==='x'?'X':'O')+' '+coordinate(to)};
  }
  return {width:3,height:3,first:'x',second:'o',sides:{x:'X',o:'O'},
    initial:function(){return Array(9).fill(null);},legal:legal,play:play,
    winningLine:winningLine,coordinate:coordinate,bestMove:bestMove,
    rules:'3 × 3 九宫格，X 先行，双方轮流在空格落子。横、竖或斜线连成三个即获胜；满盘未分胜负判和。支持与本地 AI 离线对弈。'};
})();
