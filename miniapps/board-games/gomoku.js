var Chess = (function () {
  function coordinate(p) { return String.fromCharCode(65+p[0])+(p[1]+1); }
  function legal(board) {
    var moves=[];
    board.forEach(function (piece,i) { if (!piece) moves.push({to:[i%15,Math.floor(i/15)]}); });
    return moves;
  }
  function play(s,move) {
    var to=move.to; s.board[to[1]*15+to[0]]=s.turn;
    return {to:to,piece:s.turn,text:(s.turn==='b'?'黑棋':'白棋')+' '+coordinate(to)};
  }
  function winningLine(board,to) {
    var color=board[to[1]*15+to[0]],directions=[[1,0],[0,1],[1,1],[1,-1]];
    for (var i=0;i<directions.length;i++) {
      var dx=directions[i][0],dy=directions[i][1],line=[to];
      [-1,1].forEach(function (sign) {
        for (var x=to[0]+dx*sign,y=to[1]+dy*sign;x>=0&&x<15&&y>=0&&y<15&&board[y*15+x]===color;x+=dx*sign,y+=dy*sign) line.push([x,y]);
      });
      if (line.length>=5) return line;
    }
    return [];
  }
  return {width:15,height:15,first:'b',second:'w',sides:{b:'黑棋',w:'白棋'},initial:function(){return Array(225).fill(null);},legal:legal,play:play,winningLine:winningLine,coordinate:coordinate,
    rules:'15 × 15 棋盘，黑棋先行，双方轮流落子。横、竖或斜线连续五子及以上获胜；无禁手，满盘未分胜负判和。'};
})();
