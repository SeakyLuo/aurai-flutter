// Coordinates are [file, rank], zero-based from the black side at the top.
var Chess = (function () {
  var width = 9, height = 10;
  var names = {rK:'帅',rA:'仕',rE:'相',rH:'马',rR:'车',rC:'炮',rP:'兵',bK:'将',bA:'士',bE:'象',bH:'馬',bR:'車',bC:'砲',bP:'卒'};
  function initial() {
    var board = Array(90).fill(null), back = ['R','H','E','A','K','A','E','H','R'];
    back.forEach(function (p,x) { board[x] = 'b'+p; board[81+x] = 'r'+p; });
    [1,7].forEach(function (x) { board[18+x]='bC'; board[63+x]='rC'; });
    [0,2,4,6,8].forEach(function (x) { board[27+x]='bP'; board[54+x]='rP'; });
    return board;
  }
  function inside(x,y) { return x>=0 && x<9 && y>=0 && y<10; }
  function side(p) { return p && p[0]; }
  function other(color) { return color==='r'?'b':'r'; }
  function palace(x,y,color) { return x>=3 && x<=5 && (color==='r'?y>=7&&y<=9:y>=0&&y<=2); }
  function pseudo(board,from,to) {
    var x=from[0],y=from[1],tx=to[0],ty=to[1];
    if (!inside(x,y)||!inside(tx,ty)||(x===tx&&y===ty)) return false;
    var piece=board[y*9+x],target=board[ty*9+tx];
    if (!piece||side(piece)===side(target)) return false;
    var dx=tx-x,dy=ty-y,ax=Math.abs(dx),ay=Math.abs(dy),color=side(piece),type=piece[1];
    if (type==='H') return ax===2&&ay===1?!board[y*9+x+dx/2]:ax===1&&ay===2?!board[(y+dy/2)*9+x]:false;
    if (type==='E') return ax===2&&ay===2&&(color==='r'?ty>=5:ty<=4)&&!board[(y+dy/2)*9+x+dx/2];
    if (type==='A') return ax===1&&ay===1&&palace(tx,ty,color);
    if (type==='P') return dx===0&&dy===(color==='r'?-1:1) || (color==='r'?y<=4:y>=5)&&ay===0&&ax===1;
    if (type==='K' && ax+ay===1 && palace(tx,ty,color)) return true;
    if (dx!==0&&dy!==0) return false;
    var sx=Math.sign(dx),sy=Math.sign(dy),count=0;
    for (var px=x+sx,py=y+sy;px!==tx||py!==ty;px+=sx,py+=sy) if (board[py*9+px]) count++;
    if (type==='R') return count===0;
    if (type==='C') return count===(target?1:0);
    return type==='K'&&dx===0&&target===other(color)+'K'&&count===0;
  }
  function check(board,color) {
    var index=board.indexOf(color+'K');
    if (index<0) return true;
    var king=[index%9,Math.floor(index/9)];
    for (var i=0;i<90;i++) if (side(board[i])===other(color)&&pseudo(board,[i%9,Math.floor(i/9)],king)) return true;
    return false;
  }
  function moved(board,from,to) {
    var next=board.slice(); next[to[1]*9+to[0]]=next[from[1]*9+from[0]]; next[from[1]*9+from[0]]=null; return next;
  }
  function legal(board,color) {
    var moves=[];
    for (var i=0;i<90;i++) if (side(board[i])===color) {
      var from=[i%9,Math.floor(i/9)];
      for (var j=0;j<90;j++) {
        var to=[j%9,Math.floor(j/9)];
        if (pseudo(board,from,to)&&!check(moved(board,from,to),color)) moves.push({from:from,to:to});
      }
    }
    return moves;
  }
  function play(s,move) {
    var from=move.from,to=move.to,piece=s.board[from[1]*9+from[0]],captured=s.board[to[1]*9+to[0]];
    var text=notation(s.board,from,to);
    s.board=moved(s.board,from,to); s.quiet=captured?0:s.quiet+1;
    return {from:from,to:to,piece:piece,captured:captured,text:text};
  }
  function notation(board,from,to) {
    var piece=board[from[1]*9+from[0]],red=piece[0]==='r';
    function number(n) { return '一二三四五六七八九'[n-1]; }
    function file(x) { return number(red?9-x:x+1); }
    var ranks=[];
    for(var y=0;y<10;y++) if(board[y*9+from[0]]===piece) ranks.push(y);
    if(!red) ranks.reverse();
    var prefix=names[piece]+file(from[0]);
    if(ranks.length>1){
      var index=ranks.indexOf(from[1]);
      var order=ranks.length===2?['前','后']:ranks.length===3?['前','中','后']:ranks.length===4?['前','二','三','后']:['前','二','三','四','后'];
      prefix=order[index]+names[piece];
    }
    if(from[1]===to[1]) return prefix+'平'+file(to[0]);
    var forward=red?to[1]<from[1]:to[1]>from[1];
    return prefix+(forward?'进':'退')+('HEA'.includes(piece[1])?file(to[0]):number(Math.abs(to[1]-from[1])));
  }
  function coordinate(p) { return String.fromCharCode(65+p[0])+(p[1]+1); }
  function positionKey(board,turn) { return turn+':'+board.map(function(p){return p||'.';}).join(','); }
  function canCapture(board,from,to) {
    return pseudo(board,from,to)&&!check(moved(board,from,to),side(board[from[1]*9+from[0]]));
  }
  // Track physical pieces, not piece codes: two horses are not the same chase target.
  // Captures cannot belong to a repetition cycle, so only reconstruct the quiet suffix.
  function repetitionFrames(s,move) {
    var start=s.history.length;
    while(start>0&&!s.history[start-1].captured)start--;
    var records=s.history.slice(start),board=s.board.slice();
    for(var i=records.length-1;i>=0;i--){var m=records[i];board[m.from[1]*9+m.from[0]]=m.piece;board[m.to[1]*9+m.to[0]]=null;}
    var ids=board.map(function(p,i){return p?i:null;}),turn=records.length?records[0].side:s.turn;
    var frames=[{board:board,ids:ids,turn:turn}];
    if(move)records.push({from:move.from,to:move.to,piece:s.board[move.from[1]*9+move.from[0]],side:s.turn});
    records.forEach(function(m){
      board=moved(board,m.from,m.to);ids=ids.slice();ids[m.to[1]*9+m.to[0]]=ids[m.from[1]*9+m.from[0]];ids[m.from[1]*9+m.from[0]]=null;
      turn=other(m.side);frames.push({board:board,ids:ids,turn:turn});
    });
    return frames;
  }
  function chaseThreats(frame,color) {
    var board=frame.board,threats=[];
    for(var i=0;i<90;i++)if(side(board[i])===color&&!['K','P'].includes(board[i][1])){
      var from=[i%9,Math.floor(i/9)];
      for(var j=0;j<90;j++)if(side(board[j])===other(color)&&board[j][1]!=='K'){
        var to=[j%9,Math.floor(j/9)];
        if(!canCapture(board,from,to))continue;
        // A legal same-kind exchange is not a chase; pinned pieces cannot exchange.
        if(board[i][1]===board[j][1]&&canCapture(board,to,from))continue;
        var captured=moved(board,from,to),protectedPiece=false;
        for(var k=0;k<90;k++)if(side(captured[k])===other(color)&&canCapture(captured,[k%9,Math.floor(k/9)],to)){protectedPiece=true;break;}
        // Horse/cannon chasing a rook is the exception to the protected-piece rule.
        if(protectedPiece&&!(board[j][1]==='R'&&['H','C'].includes(board[i][1])))continue;
        threats.push({attacker:frame.ids[i],target:frame.ids[j]});
      }
    }
    return threats;
  }
  function repeatingAttack(frames,start,color) {
    var allCheck=true,targets=null,count=0;
    for(var i=start+1;i<frames.length;i++)if(frames[i-1].turn===color){
      count++;
      if(check(frames[i].board,other(color))) { targets=[];continue; }
      allCheck=false;
      var before=chaseThreats(frames[i-1],color),after=chaseThreats(frames[i],color);
      var chased=after.filter(function(t){return !before.some(function(p){return p.attacker===t.attacker&&p.target===t.target;});}).map(function(t){return t.target;});
      targets=targets===null?chased:targets.filter(function(t){return chased.includes(t);});
    }
    return count&&allCheck?2:targets&&targets.length?1:0;
  }
  function repetition(s,move) {
    var board=move?moved(s.board,move.from,move.to):s.board,turn=move?other(s.turn):s.turn;
    if(move&&s.board[move.to[1]*9+move.to[0]])return null;
    var key=positionKey(board,turn),needed=move?2:3;
    if((s.positions[key]||0)<needed)return null;
    var frames=repetitionFrames(s,move),matches=[];
    frames.forEach(function(f,i){if(positionKey(f.board,f.turn)===key)matches.push(i);});
    if(matches.length<3)return null;
    var start=matches[matches.length-3],red=repeatingAttack(frames,start,'r'),black=repeatingAttack(frames,start,'b');
    var offender=red===black?null:red>black?'r':'b';
    return {offender:offender,reason:Math.max(red,black)===2?'长将':'长捉'};
  }
  function allowed(s) {
    return legal(s.board,s.turn).filter(function(move){var repeat=repetition(s,move);return !repeat||repeat.offender!==s.turn;});
  }
  return {width:width,height:height,first:'r',second:'b',sides:{r:'红方',b:'黑方'},names:names,initial:initial,legal:legal,allowed:allowed,repetition:repetition,play:play,check:check,coordinate:coordinate,
    rules:'红方先行。遵循蹩马腿、塞象眼、九宫、过河、炮隔子及将帅照面规则；将死或无合法走法均判负。同局面同走方第三次出现时，单方长将、长捉同一棋子的走法禁止，必须变招；长将对长捉由长将方变招。双方同等重复或均未犯例判和。将帅、兵卒追捉、合法兑子和追捉真有根子不算长捉，马炮追有根车除外。连续 120 步未吃子或达到 400 步判和。'};
})();
