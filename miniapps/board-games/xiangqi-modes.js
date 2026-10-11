// Hidden identities live only in reducer state; board, legal moves and history
// contain covered roles or revealed pieces, never the secret permutation.
var XiangqiModes=(function(base){
  var labels={normal:'中国象棋',jieqi:'揭棋',banqi:'暗棋'},legend={},names=Object.assign({},base.names);
  Object.keys(base.names).forEach(function(code){legend[code]=(code[0]==='r'?'红':'黑')+base.names[code];});
  ['r','b'].forEach(function(side){['A','E','H','R','C','P'].forEach(function(type){var code=side+'D'+type;names[code]='暗';legend[code]=(side==='r'?'红':'黑')+'暗'+base.names[side+type];});});
  names.uD='暗';legend.uD='暗';
  function other(side){return side==='r'?'b':'r';}
  function shuffle(a){for(var i=a.length-1;i>0;i--){var j=Math.floor(Math.random()*(i+1)),t=a[i];a[i]=a[j];a[j]=t;}return a;}
  function pool(mode){return base.initial().filter(function(p){return p&&(mode==='banqi'||p[1]!=='K');});}
  function initialize(s){
    var hidden=Array(s.board.length).fill(null);
    if(s.mode==='banqi'){hidden=shuffle(pool('banqi'));s.colorsAssigned=false;s.openingTurn=s.turn;s.initialPlayers=s.players.map(function(p){return p.side;});}
    else ['r','b'].forEach(function(side){var bag=shuffle(pool('jieqi').filter(function(p){return p[0]===side;}));s.board.forEach(function(p,i){if(p&&p[0]===side&&p[1]!=='K'){hidden[i]=bag.pop();s.board[i]=side+'D'+p[1];}});});
    s.hidden=hidden;s.revealed=[];s.initialBoard=s.board.slice();s.initialHidden=hidden.slice();
  }
  function restore(s){s.board=s.initialBoard.slice();s.hidden=s.initialHidden.slice();s.revealed=[];if(s.mode==='banqi'){s.colorsAssigned=false;s.turn=s.openingTurn;s.players.forEach(function(p,i){p.side=s.initialPlayers[i];});}}
  function unseen(s){var bag=pool(s.mode);s.revealed.forEach(function(p){bag.splice(bag.indexOf(p),1);});return bag;}
  function jieqiPlay(s,m){
    var from=m.from[1]*9+m.from[0],to=m.to[1]*9+m.to[0],identity=s.hidden[from],record=base.play(s,m);
    if(identity){s.board[to]=identity;s.revealed.push(identity);record.revealed=identity;s.quiet=0;record.text=base.coordinate(m.from)+' → '+base.coordinate(m.to)+' · 揭开'+legend[identity];}
    s.hidden[from]=null;s.hidden[to]=null;return record;
  }
  var jieqi=Object.assign({},base,{mode:'jieqi',names:names,legend:legend,initialize:initialize,restore:restore,unseen:unseen,play:jieqiPlay,
    rules:'将帅明置，其余棋子按各自颜色洗乱盖住。暗子第一步按原位置的棋种走，走后揭开；明子按真实棋种走，士、象可过河，士不受九宫限制。暗子被吃不公开身份。红方先行，将死或困毙判负；长将长捉、重复局面及步数判和沿用普通象棋规则，揭子清空未吃子计数。',hint:'先选棋子，再选择落点，暗子走后自动揭开'});
  var ranks={K:7,A:6,E:5,R:4,H:3,C:2,P:1};
  function coordinate(p){return String.fromCharCode(65+p[0])+(p[1]+1);}
  function capture(a,b){return a[1]==='P'?b[1]==='P'||b[1]==='K':a[1]==='K'?b[1]!=='P':ranks[a[1]]>=ranks[b[1]];}
  function legal(board,side){
    var moves=[];
    board.forEach(function(p,i){
      var from=[i%4,Math.floor(i/4)];
      if(p==='uD'){moves.push({to:from});return;}
      if(!p||p[0]!==side)return;
      [[1,0],[-1,0],[0,1],[0,-1]].forEach(function(d){var x=from[0]+d[0],y=from[1]+d[1];if(x<0||x>=4||y<0||y>=8)return;var target=board[y*4+x];
        if(!target||target!=='uD'&&target[0]!==side&&p[1]!=='C'&&capture(p,target))moves.push({from:from,to:[x,y]});
        if(p[1]!=='C')return;
        var screen=false;
        while(x>=0&&x<4&&y>=0&&y<8){target=board[y*4+x];if(target){if(screen){if(target!=='uD'&&target[0]!==side)moves.push({from:from,to:[x,y]});break;}screen=true;}x+=d[0];y+=d[1];}
      });
    });return moves;
  }
  function banqiPlay(s,m){
    var to=m.to[1]*4+m.to[0],record;
    if(!m.from){
      var piece=s.hidden[to];s.board[to]=piece;s.hidden[to]=null;s.revealed.push(piece);
      if(!s.colorsAssigned){var actor=s.players.find(function(p){return p.side===s.turn;});s.players.forEach(function(p){p.side=p===actor?piece[0]:other(piece[0]);});s.turn=piece[0];s.colorsAssigned=true;}
      record={to:m.to,revealed:piece,text:'翻开 '+coordinate(m.to)+' · '+legend[piece]};s.quiet=0;
    }else{var from=m.from[1]*4+m.from[0],moving=s.board[from],captured=s.board[to];s.board[to]=moving;s.board[from]=null;s.quiet=captured?0:s.quiet+1;record={from:m.from,to:m.to,piece:moving,captured:captured,text:legend[moving]+' '+coordinate(m.from)+' → '+coordinate(m.to)+(captured?' · 吃'+legend[captured]:'')};}
    return record;
  }
  function outcome(board,m,side){var next=other(side);return !legal(board,next).length?{winner:side,reason:'对方无合法走法',line:[]}:null;}
  function judge(s,m,side){
    var next=other(side),remaining=s.board.some(function(p,i){return p==='uD'?s.hidden[i][0]===next:p&&p[0]===next;});
    if(!remaining)return {winner:side,reason:'对方棋子已全部被吃',line:[]};
    var end=outcome(s.board,m,side);if(end)return end;
    return s.quiet>=60?{winner:null,reason:'连续 60 步未吃子或翻子',line:[]}:null;
  }
  var banqi={mode:'banqi',width:4,height:8,first:'r',second:'b',sides:base.sides,names:names,legend:legend,initial:function(){return Array(32).fill('uD');},initialize:initialize,restore:restore,unseen:unseen,legal:legal,play:banqiPlay,check:function(){return false;},outcome:outcome,judge:judge,repetition:true,maxPly:0,coordinate:coordinate,
    rules:'4 × 8 半盘暗棋，32 子洗乱盖住。首次翻出的颜色归先手。每回合翻一子，或移动己方明子：上下左右一格，大吃小、同级互吃；将帅不能吃兵卒，兵卒可以吃将帅。炮只隔一个棋子吃任意敌方明子，不能直接吃子；暗子不能被吃。棋子全失或无合法走法判负；同局面同走方三次重复、连续 60 步未吃子或翻子判和。',hint:'点击暗子翻开，或选己方明子走棋'};
  return {labels:labels,get:function(mode){if(['normal','jieqi','banqi'].indexOf(mode)<0)throw Error('请选择有效的象棋模式');base.setJieqi(mode==='jieqi');return mode==='normal'?base:mode==='jieqi'?jieqi:banqi;}};
})(Chess);
