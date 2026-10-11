// Two-player Chinese checkers on the 121-hole six-pointed star.
// Standard adjacent hops, plus the explicitly documented stay-in-goal house rule.
var Chess=(function(){
  var width=17,height=17,dirs=[[1,0],[0,1],[-1,1],[-1,0],[0,-1],[1,-1]],holes=[],camps={b:[],w:[]};
  function valid(x,y){var q=x-8,r=y-8,t=-q-r;return Math.max(Math.abs(q),Math.abs(r),Math.abs(t))<=8&&[q,r,t].filter(function(v){return Math.abs(v)>4;}).length<=1;}
  for(var y=0;y<17;y++)for(var x=0;x<17;x++)if(valid(x,y)){var i=y*17+x;holes.push(i);if(y<4)camps.b.push(i);if(y>12)camps.w.push(i);}
  function target(side){return camps[side==='b'?'w':'b'];}
  function coordinate(p){return String.fromCharCode(65+p[0])+(p[1]+1);}
  function initial(){var b=Array(289).fill(null);['b','w'].forEach(function(side){camps[side].forEach(function(i){b[i]=side;});});return b;}
  function legal(b,side){
    var out=[],goal=target(side);
    holes.forEach(function(start){
      if(b[start]!==side)return;
      var from=[start%17,Math.floor(start/17)],destinations=new Set(),visited=new Set([start]),queue=[{p:from,path:[]}];
      function allowed(p,fromGoal){return valid(p[0],p[1])&&(!fromGoal||goal.includes(p[1]*17+p[0]));}
      dirs.forEach(function(d){var p=[from[0]+d[0],from[1]+d[1]],i=p[1]*17+p[0];if(allowed(p,goal.includes(start))&&!b[i]){destinations.add(i);out.push({from:from,to:p,path:[p]});}});
      for(var head=0;head<queue.length;head++){
        var node=queue[head];
        dirs.forEach(function(d){
          var mid=[node.p[0]+d[0],node.p[1]+d[1]],p=[node.p[0]+2*d[0],node.p[1]+2*d[1]],mi=mid[1]*17+mid[0],i=p[1]*17+p[0];
          if(!valid(mid[0],mid[1])||mi===start||!b[mi]||!allowed(p,goal.includes(node.p[1]*17+node.p[0]))||b[i]||visited.has(i))return;
          visited.add(i);var path=node.path.concat([p]);queue.push({p:p,path:path});
          if(!destinations.has(i)){destinations.add(i);out.push({from:from,to:p,path:path});}
        });
      }
    });return out;
  }
  function moved(b,m,side){var n=b.slice();n[m.from[1]*17+m.from[0]]=null;n[m.to[1]*17+m.to[0]]=side;return n;}
  function play(s,m){s.board=moved(s.board,m,s.turn);return {from:m.from,to:m.to,path:m.path,text:coordinate(m.from)+' → '+coordinate(m.to)+(m.path.length>1?' · 连跳'+m.path.length+'次':'')};}
  function outcome(b,m,side){return target(side).every(function(i){return b[i]===side;})?{winner:side,reason:'十子全部入营',line:target(side).map(function(i){return [i%17,Math.floor(i/17)];})}:null;}
  function distance(a,b){var dx=a%17-b%17,dy=Math.floor(a/17)-Math.floor(b/17);return Math.max(Math.abs(dx),Math.abs(dy),Math.abs(dx+dy));}
  function nextTurn(b,side){var other=side==='b'?'w':'b';return legal(b,other).length?other:side;}
  function progress(b,side){
    var goal=target(side),empty=goal.filter(function(i){return b[i]!==side;}),pieces=holes.filter(function(i){return b[i]===side&&!goal.includes(i);});
    var score=(10-pieces.length)*120;
    pieces.sort(function(a,c){return Math.abs(Math.floor(c/17)-8)-Math.abs(Math.floor(a/17)-8);});
    pieces.forEach(function(i){var best=0;for(var k=1;k<empty.length;k++)if(distance(i,empty[k])<distance(i,empty[best]))best=k;score-=distance(i,empty[best])*12;empty.splice(best,1);});
    return score;
  }
  return {width:width,height:height,first:'b',second:'w',sides:{b:'薄荷棋',w:'蜜桃棋'},legend:{b:'薄',w:'桃'},holes:holes,camps:camps,valid:valid,initial:initial,legal:legal,moved:moved,play:play,outcome:outcome,nextTurn:nextTurn,evaluate:function(b,side){return progress(b,side)-progress(b,side==='b'?'w':'b');},coordinate:coordinate,searchDepth:[1,1,2,3,4],searchWidth:12,moving:true,repetition:true,
    rules:'双人中国跳棋，每方十子，薄荷棋先行。可移动到相邻空穴，或跳过一枚相邻棋子到其后的空穴，并可连续跳跃；不吃子。选中棋子后点击高亮终点，一次完成整条连跳。休闲规则：进入对面目标营后只可在营内移动，十子全部入营获胜；无合法走法时自动让行，双方均无法移动、三次重复局面或 400 步判和。',hint:'先选棋子，再点亮起的空穴；可直接选择连跳终点'};
})();
