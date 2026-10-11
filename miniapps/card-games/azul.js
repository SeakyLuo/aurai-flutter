// Original colored-wall rules, two players: Michael Kiesling / Next Move Games.
// https://cdn.svc.asmodee.net/production-nextmove/uploads/sites/4/2024/06/EN-Azul-Rules-Next-Move-web.pdf
var Cards=(function(){
  var names=['钴蓝','金黄','珊瑚红','深青','象牙白'],penalties=[1,1,2,2,2,3,3];
  function require(ok,message){if(!ok)throw Error(message);}
  function random(s){s.seed=(Math.imul(s.seed,1664525)+1013904223)>>>0;return s.seed/4294967296;}
  function shuffle(s,a){for(var i=a.length-1;i>0;i--){var j=Math.floor(random(s)*(i+1)),v=a[i];a[i]=a[j];a[j]=v;}return a;}
  function log(s,seat,text){s.logs.push({seat:seat,text:text});s.logs=s.logs.slice(-12);}
  function cell(row,color){return row*5+(color+row)%5;}
  function blank(){return {score:0,wall:Array(25).fill(null),lines:Array.from({length:5},function(){return {color:null,count:0};}),floor:[]};}
  function refill(s){
    s.factories=Array.from({length:5},function(){return [];});s.center=[];s.marker=true;s.nextStarter=null;s.stage='draft';s.turn=s.starter;
    for(var f=0;f<5;f++)for(var n=0;n<4;n++){
      if(!s.bag.length){s.bag=shuffle(s,s.discard);s.discard=[];}
      if(s.bag.length)s.factories[f].push(s.bag.pop());
    }
  }
  function create(players,seed){
    var s={phase:'playing',stage:'draft',turn:0,players:players,seed:seed>>>0,round:1,starter:0,boards:[blank(),blank()],bag:[],discard:[],factories:[],center:[],marker:true,nextStarter:null,logs:[],winner:null,winners:[],result:'',roundResult:[],bonuses:[]};
    for(var c=0;c<5;c++)for(var n=0;n<20;n++)s.bag.push(c);shuffle(s,s.bag);refill(s);return s;
  }
  function canPlace(board,color,row){return row===-1||row>=0&&row<5&&board.wall[cell(row,color)]===null&&board.lines[row].count<row+1&&(board.lines[row].color===null||board.lines[row].color===color);}
  function scoreAt(wall,index){
    var x=index%5,y=Math.floor(index/5),horizontal=1,vertical=1;
    for(var a=x-1;a>=0&&wall[y*5+a]!==null;a--)horizontal++;
    for(var b=x+1;b<5&&wall[y*5+b]!==null;b++)horizontal++;
    for(var a=y-1;a>=0&&wall[a*5+x]!==null;a--)vertical++;
    for(var b=y+1;b<5&&wall[b*5+x]!==null;b++)vertical++;
    return horizontal===1&&vertical===1?1:(horizontal>1?horizontal:0)+(vertical>1?vertical:0);
  }
  function rows(wall){var n=0;for(var r=0;r<5;r++)if(wall.slice(r*5,r*5+5).every(function(c){return c!==null;}))n++;return n;}
  function bonus(wall){
    var rowCount=rows(wall),cols=0,colors=0;
    for(var x=0;x<5;x++)if([0,1,2,3,4].every(function(y){return wall[y*5+x]!==null;}))cols++;
    for(var c=0;c<5;c++)if(wall.filter(function(v){return v===c;}).length===5)colors++;
    return {rows:rowCount,columns:cols,colors:colors,points:rowCount*2+cols*7+colors*10};
  }
  function floorTile(s,b,color){if(b.floor.length<7)b.floor.push(color);else if(color!==-1)s.discard.push(color);}
  function settle(s){
    s.roundResult=s.boards.map(function(b,seat){
      var before=b.score,earned=0,placed=[];
      b.lines.forEach(function(line,row){if(line.count!==row+1)return;var index=cell(row,line.color);b.wall[index]=line.color;var points=scoreAt(b.wall,index);earned+=points;placed.push({row:row,color:line.color,points:points});for(var i=1;i<line.count;i++)s.discard.push(line.color);line.count=0;line.color=null;});
      var lost=b.floor.reduce(function(total,_,i){return total+penalties[i];},0);b.score=Math.max(0,b.score+earned-lost);
      b.floor.forEach(function(c){if(c!==-1)s.discard.push(c);});b.floor=[];
      log(s,seat,'本轮铺砖 +'+earned+'，地板扣 '+lost+'，总分 '+b.score);
      return {earned:earned,penalty:lost,delta:b.score-before,placed:placed};
    });
    if(s.boards.some(function(b){return rows(b.wall)>0;})){
      s.bonuses=s.boards.map(function(b){var result=bonus(b.wall);b.score+=result.points;return result;});
      var best=Math.max.apply(null,s.boards.map(function(b){return b.score;}));
      var tied=[0,1].filter(function(i){return s.boards[i].score===best;});
      var bestRows=Math.max.apply(null,tied.map(function(i){return s.bonuses[i].rows;}));
      s.winners=tied.filter(function(i){return s.bonuses[i].rows===bestRows;});s.winner=s.winners.length===1?s.winners[0]:null;
      s.phase='finished';s.stage='finished';s.result=s.winners.map(function(i){return s.players[i].name;}).join('、')+(s.winners.length>1?'并列获胜':'获胜');
    }else{s.stage='roundEnd';s.turn=0;}
  }
  function moves(view,seat){
    if(view.phase!=='playing'||view.stage!=='draft')return [];
    var out=[],sources=view.factories.concat([view.center]);
    sources.forEach(function(tiles,f){var source=f===5?-1:f;[0,1,2,3,4].forEach(function(color){var count=tiles.filter(function(c){return c===color;}).length;if(!count)return;for(var row=-1;row<5;row++)if(canPlace(view.boards[seat],color,row))out.push({source:source,color:color,row:row,count:count});});});return out;
  }
  function apply(s,seat,action,d){
    require(s.phase==='playing'&&s.turn===seat,'尚未轮到你');
    if(s.stage==='roundEnd'){
      require(action==='nextRound','请开始下一轮');s.round++;s.starter=s.nextStarter===null?s.starter:s.nextStarter;refill(s);return;
    }
    require(action==='draft','请选择花砖和放置行');
    require(Number.isInteger(d.source)&&d.source>=-1&&d.source<5&&Number.isInteger(d.color)&&d.color>=0&&d.color<5&&Number.isInteger(d.row)&&d.row>=-1&&d.row<5,'请选择有效的花砖和放置位置');
    var source=d.source===-1?s.center:s.factories[d.source],color=d.color;
    var count=source.filter(function(c){return c===color;}).length;require(count>0,'这里已经没有这个颜色的花砖');
    var b=s.boards[seat];require(canPlace(b,color,d.row),'这行不能放入该颜色，请选其他行或地板');
    if(d.source===-1){s.center=s.center.filter(function(c){return c!==color;});if(s.marker){s.marker=false;s.nextStarter=seat;floorTile(s,b,-1);}}
    else{s.center=s.center.concat(source.filter(function(c){return c!==color;}));s.factories[d.source]=[];}
    var placed=0;
    if(d.row!==-1){var line=b.lines[d.row];placed=Math.min(count,d.row+1-line.count);line.color=color;line.count+=placed;}
    for(var i=placed;i<count;i++)floorTile(s,b,color);
    log(s,seat,'取 '+count+' 块'+names[color]+'，'+(d.row===-1?'放入地板':'放入第 '+(d.row+1)+' 行'+(placed<count?'，'+(count-placed)+' 块落入地板':'')));
    if(!s.center.length&&s.factories.every(function(f){return !f.length;}))settle(s);else s.turn=1-seat;
  }
  function publicView(s){return {phase:s.phase,stage:s.stage,turn:s.turn,players:s.players,round:s.round,boards:s.boards,factories:s.factories,center:s.center,marker:s.marker,nextStarter:s.nextStarter,bagCount:s.bag.length,logs:s.logs,winner:s.winner,winners:s.winners,result:s.result,roundResult:s.roundResult,bonuses:s.bonuses};}
  function privateView(s,seat){return {seat:seat,legalMoves:s.turn===seat?moves(s,seat):[]};}
  function choiceValue(v,seat,m){
    var b=v.boards[seat],line=m.row===-1?null:b.lines[m.row],room=line?m.row+1-line.count:0,placed=Math.min(room,m.count),waste=m.count-placed;
    var marker=m.source===-1&&v.marker?1:0,penalty=0;
    for(var i=b.floor.length;i<Math.min(7,b.floor.length+waste+marker);i++)penalty+=penalties[i];
    if(!line)return -penalty*2.4-m.count*.4;
    var count=line.count+placed,complete=count===m.row+1,index=cell(m.row,m.color),wall=b.wall.slice();wall[index]=m.color;
    var progress=placed/(m.row+1),points=scoreAt(wall,index);
    var sameColor=b.wall.filter(function(c){return c===m.color;}).length;
    var urgency=v.boards.some(function(p){return [0,1,2,3,4].some(function(r){return p.wall.slice(r*5,r*5+5).filter(function(c){return c!==null;}).length===4;});});
    var rowTiles=b.wall.slice(m.row*5,m.row*5+5).filter(function(c){return c!==null;}).length;
    var value=complete?points+3+sameColor*.45+rowTiles*.4:progress*2.5;
    if(!complete&&urgency)value-=2;
    if(complete&&rowTiles===4)value+=b.score>=v.boards[1-seat].score?4:-3;
    // Deny a useful same-colour source without examining the unknown bag.
    var other=v.boards[1-seat];var denial=other.lines.some(function(l,r){return l.color===m.color&&l.count<r+1&&l.count+m.count>=r+1;});
    return value-penalty*2.4-waste*.25+(denial?.65:0)+(marker?.1:0);
  }
  function ai(own,v){
    var legal=own.legalMoves;
    var best=legal.reduce(function(a,b){return choiceValue(v,own.seat,b)>choiceValue(v,own.seat,a)?b:a;});
    return {action:'draft',data:{source:best.source,color:best.color,row:best.row}};
  }
  return {title:'花砖物语',seats:2,create:create,apply:apply,publicView:publicView,privateView:privateView,ai:ai,moves:moves,cell:cell,canPlace:canPlace,scoreAt:scoreAt,names:names,
    rules:'双人经典彩墙玩法：五个工坊每轮各有四块砖。每回合从一个工坊或中央区取走同色砖，放到自己一条准备行；工坊余下的颜色移入中央。首个从中央取砖的人拿先手标记，标记占地板一格并决定下一轮先手。\n准备行容量依次为 1—5，只能容纳一种颜色，且对应墙行不能已有该颜色。多余花砖落到地板，也可主动全部放地板。地板前七格依次扣 1、1、2、2、2、3、3 分，之后多余砖直接弃置。\n砖取完后，从上到下结算填满的准备行：一块移到墙上，其余弃置；未满行保留。新砖单独得 1 分，与横向或纵向相连时分别计算连续砖数（含自身），两方向都相连则相加。结算地板后分数最低为 0。\n有人完成墙面一整横行时，本轮铺墙后结束。完整横行另加 2 分、完整竖列加 7 分、同色五块加 10 分。总分高者胜，同分比较完成横行数，仍同分则共享胜利。'};
})();
