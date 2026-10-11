// Two-player flip Junqi. Variant rules are explicit in the in-game rules panel.
// Movement reference: https://www.gameabc.com/news/201704/3333.html
var Cards=(function(){
  var names=['军旗','工兵','排长','连长','营长','团长','旅长','师长','军长','司令','地雷','炸弹'];
  var numbers=[1,3,3,3,2,2,2,2,1,1,3,2],camps=[11,13,17,21,23,36,38,42,46,48];
  function require(ok,text){if(!ok)throw Error(text);}
  function camp(i){return camps.indexOf(i)>=0;}
  function road(a,b){var x=a%5,y=Math.floor(a/5),u=b%5,v=Math.floor(b/5),dx=Math.abs(x-u),dy=Math.abs(y-v);if((y===5&&v===6||y===6&&v===5))return x===u&&(x===0||x===2||x===4);return dx+dy===1||dx===1&&dy===1&&(camp(a)||camp(b));}
  function rail(a,b){if(!road(a,b))return false;var x=a%5,y=Math.floor(a/5),u=b%5,v=Math.floor(b/5);return y===v&&[1,5,6,10].indexOf(y)>=0||x===u&&(x===0||x===4)&&Math.min(y,v)>=1&&Math.max(y,v)<=10||x===2&&u===2&&Math.min(y,v)===5&&Math.max(y,v)===6;}
  var adjacent=Array.from({length:60},function(_,i){var out=[];for(var j=0;j<60;j++)if(road(i,j))out.push(j);return out;});
  function random(s){s.seed=(Math.imul(s.seed,1664525)+1013904223)>>>0;return s.seed/4294967296;}
  function create(players,seed){var s={phase:'playing',players:players,seed:seed>>>0,turn:0,colors:[null,null],board:Array(60).fill(null),logs:[],winner:null,result:'',quiet:0,last:null,trail:[]},pieces=[];for(var color=0;color<2;color++)numbers.forEach(function(n,rank){for(var k=0;k<n;k++)pieces.push({color:color,rank:rank,open:false});});for(var i=pieces.length-1;i>0;i--){var j=Math.floor(random(s)*(i+1)),p=pieces[i];pieces[i]=pieces[j];pieces[j]=p;}for(var q=0;q<60;q++)if(!camp(q))s.board[q]=pieces.pop();return s;}
  function visible(board){return board.map(function(p){return !p?null:p.open?{color:p.color,rank:p.rank,open:true}:{open:false};});}
  function combat(a,b){if(a.rank===11||b.rank===11)return 0;if(b.rank===0)return 1;if(b.rank===10)return a.rank===1?1:-1;return Math.sign(a.rank-b.rank);}
  function moves(board,color){
    var out=[],mineCount=[0,0];board.forEach(function(p){if(p&&p.open&&p.rank===10)mineCount[p.color]++;});
    // Flip variant: all pieces revealed and all defending mines cleared before flag capture.
    // https://www.jqh5.com/ explicitly documents both conditions.
    var hidden=board.some(function(p){return p&&!p.open;});
    board.forEach(function(p,from){if(!p||!p.open||p.color!==color||p.rank===0||p.rank===10)return;
      var targets=new Set(adjacent[from]);
      if(p.rank===1){var seen=new Set([from]),queue=[from];for(var k=0;k<queue.length;k++)adjacent[queue[k]].forEach(function(to){if(!rail(queue[k],to)||seen.has(to))return;seen.add(to);targets.add(to);if(!board[to])queue.push(to);});}
      else [[1,0],[-1,0],[0,1],[0,-1]].forEach(function(d){var at=from;while(true){var x=at%5+d[0],y=Math.floor(at/5)+d[1];if(x<0||x>4||y<0||y>11)break;var to=y*5+x;if(!rail(at,to))break;targets.add(to);if(board[to])break;at=to;}});
      targets.forEach(function(to){var target=board[to];if(!target){out.push({from:from,to:to});return;}if(!target.open||target.color===color||camp(to))return;if(target.rank===10&&p.rank!==1&&p.rank!==11)return;if(target.rank===0&&(hidden||mineCount[target.color]>0))return;out.push({from:from,to:to});});
    });return out;
  }
  function record(s,seat,text){s.logs.push({seat:seat,text:text});s.logs=s.logs.slice(-12);}
  function finish(s,winner,reason){s.phase='finished';s.winner=winner;s.result=winner===null?'和棋 · '+reason:s.players[winner].name+'获胜 · '+reason;}
  function apply(s,seat,action,data){
    require(s.phase==='playing'&&seat===s.turn,'尚未轮到你');
    if(action==='flip'){var at=data.at;require(Number.isInteger(at)&&at>=0&&at<60&&s.board[at]&&!s.board[at].open,'请选择一枚未翻开的棋子');var p=s.board[at];p.open=true;if(s.colors[seat]===null){s.colors[seat]=p.color;s.colors[1-seat]=1-p.color;}s.quiet=0;s.last={to:at};record(s,seat,'翻开'+(p.color===0?'红方':'蓝方')+names[p.rank]);}
    else {require(action==='move','请选择翻棋或走棋');var move=moves(visible(s.board),s.colors[seat]).find(function(m){return m.from===data.from&&m.to===data.to;});require(move,'这一步不符合走棋规则');var own=s.board[move.from],target=s.board[move.to];s.board[move.from]=null;s.last=move;s.quiet=target?0:s.quiet+1;
      if(!target)s.board[move.to]=own;else{var result=combat(own,target);s.board[move.to]=result>0?own:result===0?null:target;if(target.rank===0)finish(s,seat,'夺取军旗');}
      if(target)s.trail=[];else{s.trail.push({seat:seat,from:move.from,to:move.to});s.trail=s.trail.slice(-24);}
      record(s,seat,names[own.rank]+(target?'对阵'+names[target.rank]:'移动'));
    }
    if(s.phase==='finished')return;s.turn=1-seat;
    if(!s.board.some(function(p){return p&&!p.open;})&&!moves(visible(s.board),s.colors[s.turn]).length)finish(s,seat,'对方无棋可走');
    else if(s.quiet>=80)finish(s,null,'连续 80 步未吃子或翻棋');
  }
  function publicView(s){return {phase:s.phase,turn:s.turn,players:s.players,colors:s.colors,board:visible(s.board),logs:s.logs,winner:s.winner,result:s.result,quiet:s.quiet,last:s.last,trail:s.trail};}
  function privateView(s,seat){return {seat:seat,moves:s.phase==='playing'&&s.turn===seat?moves(visible(s.board),s.colors[seat]):[]};}
  function value(p){return p.rank===0?10000:p.rank===10?28:p.rank===11?36:p.rank===1?24:10+p.rank*5;}
  function ai(own,v){
    var routes={},hidden=v.board.some(function(p){return p&&!p.open;}),enemyMines=v.board.some(function(p){return p&&p.open&&p.color!==v.colors[own.seat]&&p.rank===10;});
    function route(from,p){if(routes[from])return routes[from];var costs=Array(60).fill(100),queue=[];
      v.board.forEach(function(q,i){if(q&&q.open&&q.color!==p.color&&!camp(i)&&(combat(p,q)>0||p.rank===11&&value(q)>=24)&&!(q.rank===0&&(hidden||enemyMines))){costs[i]=0;queue.push(i);}});
      for(var k=0;k<queue.length;k++){var at=queue[k];adjacent[at].forEach(function(i){if(costs[i]!==100||v.board[i]&&i!==from)return;costs[i]=costs[at]+1;queue.push(i);});}routes[from]=costs;return costs;
    }
    var choices=own.moves.map(function(m){var p=v.board[m.from],t=v.board[m.to],score=0,next=v.board.slice();next[m.from]=null;
      if(t){var result=combat(p,t);score=result>0?value(t):result===0?value(t)-value(p): -value(p);next[m.to]=result>0?p:result===0?null:t;}else{next[m.to]=p;score=camp(m.to)?.15:0;
        var costs=route(m.from,p);if(costs[m.to]<100)score+=(costs[m.from]-costs[m.to])*.8+2/(1+costs[m.to]);
        score-=v.trail.filter(function(r){return r.seat===own.seat&&r.to===m.to;}).length*2;
      }
      if(next[m.to]===p){var threats=moves(next,1-p.color).filter(function(r){return r.to===m.to;});if(threats.some(function(r){return combat(next[r.from],p)>=0;}))score-=value(p)*.85;}
      // Break quiet cycles without consulting hidden ranks or the shuffle seed.
      score+=Math.sin((m.from*61+m.to+v.quiet*17)*1.73)*.8;
      return {action:'move',data:m,score:score};
    });
    v.board.forEach(function(p,i){if(p&&!p.open){var danger=adjacent[i].filter(function(j){var q=v.board[j];return q&&q.open&&q.color!==v.colors[own.seat];}).length;choices.push({action:'flip',data:{at:i},score:2-danger*.4+Math.sin(i*2.31+v.quiet)*.2});}});
    choices.sort(function(a,b){return b.score-a.score;});return {action:choices[0].action,data:choices[0].data};
  }
  return {title:'军棋·翻棋',seats:2,create:create,apply:apply,publicView:publicView,privateView:privateView,ai:ai,names:names,camps:camps,road:road,rail:rail,
    rules:'双人翻棋变体：双方各 25 枚棋随机盖在行营以外的位置。你先翻棋，第一枚棋子的颜色成为你的阵营。每回合翻一枚暗棋，或移动一枚己方明棋；暗棋不能直接攻击。\n公路走一步；铁路无阻挡可直走多步，只有工兵可沿铁路转弯。中央只有左、中、右三条连接线。圆形行营内的棋子不能被攻击；本翻棋变体的大本营允许进出。\n司令＞军长＞师长＞旅长＞团长＞营长＞连长＞排长＞工兵；大吃小，同级同归于尽。炸弹与任何敌棋同归于尽。地雷和军旗不能移动；只有工兵可排雷，炸弹可与雷同归于尽，其他子不能主动碰雷。\n本局采用地雷护旗：所有暗棋都翻开且对方三枚地雷全被清除后，才可夺取其军旗。夺旗获胜（炸弹夺旗也结束对局）；全明后轮到的一方无棋可动判负。连续 80 步未吃子或翻棋判和。AI 只读取公开棋面，不查看暗棋身份。'};
})();
