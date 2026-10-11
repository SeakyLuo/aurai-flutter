// Two-player rules: https://export.gigamic.com/wp-content/uploads/2021/01/INS-RULES-QUORIDOR_10-2016.pdf
var Cards=(function(){
  function require(ok,message){if(!ok)throw Error(message);}
  function edge(a,b){return Math.min(a,b)*81+Math.max(a,b);}
  function graph(walls){
    var blocked=new Set();walls.forEach(function(w){var a=w.y*9+w.x;if(w.axis==='h'){blocked.add(edge(a,a+9));blocked.add(edge(a+1,a+10));}else{blocked.add(edge(a,a+1));blocked.add(edge(a+9,a+10));}});
    return Array.from({length:81},function(_,a){var x=a%9,y=Math.floor(a/9),out=[];if(x>0)out.push(a-1);if(x<8)out.push(a+1);if(y>0)out.push(a-9);if(y<8)out.push(a+9);return out.filter(function(b){return !blocked.has(edge(a,b));});});
  }
  function distances(g,seat){var dist=Array(81).fill(99),queue=[];for(var x=0;x<9;x++){var a=(seat===0?0:72)+x;dist[a]=0;queue.push(a);}for(var i=0;i<queue.length;i++){var a=queue[i];g[a].forEach(function(b){if(dist[b]===99){dist[b]=dist[a]+1;queue.push(b);}});}return dist;}
  function moves(v,seat,g){
    g=g||graph(v.walls);var from=v.pawns[seat],other=v.pawns[1-seat],out=[];
    g[from].forEach(function(to){if(to!==other){out.push(to);return;}var dx=to%9-from%9,dy=Math.floor(to/9)-Math.floor(from/9),x=to%9+dx,y=Math.floor(to/9)+dy,behind=y*9+x;
      if(x>=0&&x<9&&y>=0&&y<9&&g[to].indexOf(behind)>=0)out.push(behind);
      else g[to].forEach(function(side){if(side!==from&&(dx?side%9===to%9:Math.floor(side/9)===Math.floor(to/9)))out.push(side);});
    });return Array.from(new Set(out));
  }
  function fits(v,w){return !v.walls.some(function(a){return a.axis===w.axis?(w.axis==='h'?a.y===w.y&&Math.abs(a.x-w.x)<2:a.x===w.x&&Math.abs(a.y-w.y)<2):a.x===w.x&&a.y===w.y;});}
  function wallGraph(v,w){if(!fits(v,w))return null;var g=graph(v.walls.concat([w]));return distances(g,0)[v.pawns[0]]<99&&distances(g,1)[v.pawns[1]]<99?g:null;}
  function legalWalls(v,seat){var out=[];if(!v.remaining[seat])return out;for(var y=0;y<8;y++)for(var x=0;x<8;x++)['h','v'].forEach(function(axis){var w={x:x,y:y,axis:axis};if(wallGraph(v,w))out.push(w);});return out;}
  function create(players,seed){return {phase:'playing',players:players,turn:seed%2,pawns:[76,4],walls:[],remaining:[10,10],logs:[],winner:null,result:''};}
  function apply(s,seat,action,d){
    require(s.phase==='playing'&&s.turn===seat,'尚未轮到你');var text;
    if(action==='move'){require(moves(s,seat).indexOf(d.to)>=0,'请选择可到达的位置');s.pawns[seat]=d.to;text='前进一步';
      if(Math.floor(d.to/9)===(seat===0?0:8)){s.phase='finished';s.winner=seat;s.result=s.players[seat].name+'到达终点，获胜';}
    }else{require(action==='wall','请选择走棋或放墙');require(s.remaining[seat]>0,'围墙已用完');require(Number.isInteger(d.x)&&Number.isInteger(d.y)&&d.x>=0&&d.x<8&&d.y>=0&&d.y<8&&(d.axis==='h'||d.axis==='v'),'请选择有效的围墙位置');var w={x:d.x,y:d.y,axis:d.axis};require(wallGraph(s,w),'围墙不能交叉、重叠或封死道路');s.walls.push(w);s.remaining[seat]--;text='放置'+(d.axis==='h'?'横向':'纵向')+'围墙';}
    s.logs.push({seat:seat,text:text});s.logs=s.logs.slice(-12);if(s.phase==='playing')s.turn=1-seat;
  }
  function publicView(s){return {phase:s.phase,players:s.players,turn:s.turn,pawns:s.pawns,walls:s.walls,remaining:s.remaining,logs:s.logs,winner:s.winner,result:s.result};}
  function privateView(s,seat){var active=s.phase==='playing'&&s.turn===seat;return {seat:seat,moves:active?moves(s,seat):[],walls:active?legalWalls(s,seat):[]};}
  function ai(own,v){
    var seat=own.seat,g=graph(v.walls),ours=distances(g,seat),theirs=distances(g,1-seat),legal=own.moves;
    var best=legal.reduce(function(a,b){return ours[b]<ours[a]?b:a;});if(ours[best]===0)return {action:'move',data:{to:best}};
    var choice=null,benefit=1.25;
    own.walls.forEach(function(w){var next=graph(v.walls.concat([w])),a=distances(next,seat)[v.pawns[seat]]-ours[v.pawns[seat]],b=distances(next,1-seat)[v.pawns[1-seat]]-theirs[v.pawns[1-seat]],score=b-a*1.15;
      if(theirs[v.pawns[1-seat]]===1&&b>0)score+=2;
      if(score>benefit){benefit=score;choice=w;}
    });return choice?{action:'wall',data:choice}:{action:'move',data:{to:best}};
  }
  return {title:'步步为营',seats:2,create:create,apply:apply,publicView:publicView,privateView:privateView,ai:ai,moves:moves,legalWalls:legalWalls,graph:graph,distances:distances,
    rules:'双人玩法：双方各有 10 面墙，棋子从各自底线中央出发，先到达对面任意终点格者获胜。开局随机决定先手。\n每回合二选一：向上下左右移动一格，或放置一面横向、纵向的墙。墙占两格长度，不能重叠、交叉，也不能把任何一方通往终点的所有道路封死。\n相邻且中间无墙时，可以直线跳过对方；对方身后有墙或已到棋盘边缘时，才可以向对方左右侧跳。\n点亮格走棋；放墙时先选择方向，再点交点预览，确认放置。电脑只使用公开棋盘进行寻路和拦截。'};
})();
