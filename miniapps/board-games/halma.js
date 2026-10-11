// Chinese checkers on the 121-hole six-pointed star, with balanced 2/3/4/6-seat camps.
// Standard adjacent hops, plus the explicitly documented stay-in-goal house rule.
var Chess=(function(){
  var width=17,height=17,dirs=[[1,0],[0,1],[-1,1],[-1,0],[0,-1],[1,-1]],holes=[],camps={b:[],p:[],o:[],w:[],g:[],y:[]},active=['b','w'];
  var opposites={b:'w',w:'b',p:'g',g:'p',o:'y',y:'o'},seatSides={2:['b','w'],3:['b','o','g'],4:['b','p','w','g'],6:['b','p','o','w','g','y']};
  function valid(x,y){var q=x-8,r=y-8,t=-q-r;return Math.max(Math.abs(q),Math.abs(r),Math.abs(t))<=8&&[q,r,t].filter(function(v){return Math.abs(v)>4;}).length<=1;}
  for(var y=0;y<17;y++)for(var x=0;x<17;x++)if(valid(x,y)){var i=y*17+x,q=x-8,r=y-8,t=-q-r;holes.push(i);if(r<-4)camps.b.push(i);if(q>4)camps.p.push(i);if(t<-4)camps.o.push(i);if(r>4)camps.w.push(i);if(q<-4)camps.g.push(i);if(t>4)camps.y.push(i);}
  function target(side){return camps[opposites[side]];}
  function campAt(i){return Object.keys(camps).find(function(side){return camps[side].includes(i);});}
  function setSides(sides){active=sides.slice();}
  function coordinate(p){return String.fromCharCode(65+p[0])+(p[1]+1);}
  function initial(){var b=Array(289).fill(null);active.forEach(function(side){camps[side].forEach(function(i){b[i]=side;});});return b;}
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
  function nextTurn(b,side){var at=active.indexOf(side);for(var n=1;n<=active.length;n++){var next=active[(at+n)%active.length];if(legal(b,next).length)return next;}return side;}
  function progress(b,side){
    var goal=target(side),empty=goal.filter(function(i){return b[i]!==side;}),pieces=holes.filter(function(i){return b[i]===side&&!goal.includes(i);});
    var score=(10-pieces.length)*120;
    pieces.sort(function(a,c){return Math.abs(Math.floor(c/17)-8)-Math.abs(Math.floor(a/17)-8);});
    pieces.forEach(function(i){var best=0;for(var k=1;k<empty.length;k++)if(distance(i,empty[k])<distance(i,empty[best]))best=k;score-=distance(i,empty[best])*12;empty.splice(best,1);});
    return score;
  }
  return {width:width,height:height,first:'b',second:'w',sides:{b:'薄荷棋',p:'薰衣草棋',o:'杏橙棋',w:'蜜桃棋',g:'湖蓝棋',y:'奶黄棋'},legend:{b:'薄',p:'紫',o:'橙',w:'桃',g:'蓝',y:'黄'},seatSides:seatSides,target:target,campAt:campAt,setSides:setSides,progress:progress,holes:holes,camps:camps,valid:valid,initial:initial,legal:legal,moved:moved,play:play,outcome:outcome,nextTurn:nextTurn,evaluate:function(b,side){return progress(b,side)-Math.max.apply(null,active.filter(function(s){return s!==side;}).map(function(s){return progress(b,s);}));},coordinate:coordinate,searchDepth:[1,1,2,3,4],searchWidth:12,moving:true,repetition:true,
    rules:'支持 2、3、4、6 人，每方十子，按席位依次行动。可移动到相邻空穴，或跳过一枚相邻棋子到其后的空穴，并可连续跳跃；不吃子。选中棋子后点击高亮终点，一次完成整条连跳。休闲规则：进入对面目标营后只可在营内移动，最先十子全部入营者获胜；无合法走法时自动让行，所有人均无法移动、三次重复局面或 1200 步判和。认输者退出回合，棋子保留作为跳跃支点，最后一位未退出者获胜。再来一局保持颜色并轮换先手。',hint:'先选棋子，再点亮起的空穴；可直接选择连跳终点'};
})();
