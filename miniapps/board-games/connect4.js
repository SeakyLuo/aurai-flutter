// Original drop-only rules: https://instructions.hasbro.com/en-ca/instruction/connect-4-game-instructions
var Chess=(function(){
  function coordinate(p){return String.fromCharCode(65+p[0])+(p[1]+1);}
  function legal(b){var out=[];for(var x=0;x<7;x++)for(var y=5;y>=0;y--)if(!b[y*7+x]){out.push({to:[x,y]});break;}return out;}
  function moved(b,m,side){var n=b.slice();n[m.to[1]*7+m.to[0]]=side;return n;}
  function line(b,to){
    var side=b[to[1]*7+to[0]],ds=[[1,0],[0,1],[1,1],[1,-1]];
    for(var k=0;k<ds.length;k++){var d=ds[k],points=[to];[-1,1].forEach(function(sign){for(var x=to[0]+d[0]*sign,y=to[1]+d[1]*sign;x>=0&&x<7&&y>=0&&y<6&&b[y*7+x]===side;x+=d[0]*sign,y+=d[1]*sign)points.push([x,y]);});if(points.length>=4)return points;}return [];
  }
  function outcome(b,m,side){var win=line(b,m.to);return win.length?{winner:side,reason:'四子连线',line:win}:legal(b).length?null:{winner:null,reason:'棋盘已满',line:[]};}
  function evaluate(b,side){
    var value=0,weights=[0,1,12,140,10000];
    for(var y=0;y<6;y++)for(var x=0;x<7;x++){
      if(x===3&&b[y*7+x])value+=b[y*7+x]===side?5:-5;
      [[1,0],[0,1],[1,1],[1,-1]].forEach(function(d){
        if(x+d[0]*3>6||y+d[1]*3<0||y+d[1]*3>5)return;
        var own=0,opp=0;for(var k=0;k<4;k++){var p=b[(y+k*d[1])*7+x+k*d[0]];if(p===side)own++;else if(p)opp++;}
        if(!opp)value+=weights[own];if(!own)value-=weights[opp];
      });
    }return value;
  }
  return {width:7,height:6,first:'r',second:'y',sides:{r:'珊瑚棋',y:'金色棋'},legend:{r:'珊',y:'金'},initial:function(){return Array(42).fill(null);},legal:legal,moved:moved,play:function(s,m){s.board=moved(s.board,m,s.turn);return {to:m.to,text:coordinate(m.to)};},outcome:outcome,evaluate:evaluate,coordinate:coordinate,searchDepth:[1,2,4,6,9],searchWidth:7,
    rules:'首局随机分配珊瑚棋和金色棋，之后棋色固定、双方轮换先手。点击任意未满的列，棋子落到该列最低的空位。横、竖、斜线先连成四子获胜；棋盘填满仍未分胜负则和棋。',hint:'点击一列投下棋子，先连成四子获胜'};
})();
