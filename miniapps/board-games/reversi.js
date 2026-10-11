// Rules: https://www.worldothello.org/about/about-othello/othello-rules
var Chess=(function(){
  var width=8,height=8,first='b',second='w',dirs=[[-1,-1],[0,-1],[1,-1],[-1,0],[1,0],[-1,1],[0,1],[1,1]];
  function other(side){return side==='b'?'w':'b';}
  function coordinate(p){return String.fromCharCode(65+p[0])+(p[1]+1);}
  function initial(){var b=Array(64).fill(null);b[27]='w';b[28]='b';b[35]='b';b[36]='w';return b;}
  function flips(b,p,side){
    if(b[p[1]*8+p[0]])return [];
    var out=[];
    dirs.forEach(function(d){
      var line=[],x=p[0]+d[0],y=p[1]+d[1];
      while(x>=0&&x<8&&y>=0&&y<8&&b[y*8+x]===other(side)){line.push(y*8+x);x+=d[0];y+=d[1];}
      if(line.length&&x>=0&&x<8&&y>=0&&y<8&&b[y*8+x]===side)out=out.concat(line);
    });return out;
  }
  function legal(b,side){var out=[];for(var i=0;i<64;i++)if(!b[i]&&flips(b,[i%8,Math.floor(i/8)],side).length)out.push({to:[i%8,Math.floor(i/8)]});return out;}
  function moved(b,m,side){var n=b.slice();flips(b,m.to,side).forEach(function(i){n[i]=side;});n[m.to[1]*8+m.to[0]]=side;return n;}
  function play(s,m){var changed=flips(s.board,m.to,s.turn);s.board=moved(s.board,m,s.turn);return {to:m.to,flips:changed,text:coordinate(m.to)+' · 翻转'+changed.length+'子'};}
  function outcome(b,m,side){
    if(legal(b,'b').length||legal(b,'w').length)return null;
    var black=b.filter(function(p){return p==='b';}).length,white=b.filter(function(p){return p==='w';}).length;
    return {winner:black===white?null:black>white?'b':'w',reason:'黑 '+black+' · 白 '+white,line:[]};
  }
  function nextTurn(b,side){return legal(b,other(side)).length?other(side):side;}
  function evaluate(b,side){
    var value=0,empty=b.filter(function(p){return !p;}).length;
    for(var i=0;i<64;i++){
      if(!b[i])continue;var x=i%8,y=Math.floor(i/8),v=empty<16?8:1;
      if((x===0||x===7)&&(y===0||y===7))v+=160;
      else if(x===0||x===7||y===0||y===7)v+=8;
      [[0,0],[7,0],[0,7],[7,7]].forEach(function(c){if(!b[c[1]*8+c[0]]&&Math.abs(x-c[0])<=1&&Math.abs(y-c[1])<=1)v-=x!==c[0]&&y!==c[1]?60:25;});
      value+=b[i]===side?v:-v;
    }
    return value+10*(legal(b,side).length-legal(b,other(side)).length);
  }
  return {width:width,height:height,first:first,second:second,sides:{b:'黑棋',w:'白棋'},legend:{b:'●',w:'○'},initial:initial,legal:legal,moved:moved,play:play,outcome:outcome,nextTurn:nextTurn,evaluate:evaluate,coordinate:coordinate,searchDepth:[1,2,3,5,7],searchWidth:64,
    rules:'首局随机分配黑白，后续保持颜色、轮换先手，本局先手见玩家栏。落子必须在横、竖或斜线夹住对方棋子，夹住的棋子全部翻色。没有合法落点时自动让行；双方都不能落子时结束，棋子多的一方获胜。',hint:'点击小圆点落子，夹住的棋子会翻色'};
})();
