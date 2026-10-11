// SPDX-License-Identifier: GPL-2.0-or-later
// Runs XQWLight off the UI thread. Each job owns a fresh search position.
// Publish completed depths so the UI can stop the worker at its time budget.
self.onmessage=({data})=>{
  const {board,turn,level,legalMoves}=data;
  const pieces={K:'k',A:'a',E:'b',H:'n',R:'r',C:'c',P:'p'};
  const fen=board.map(row=>{
    let result='',empty=0;
    for(const piece of row){
      if(piece===null){empty++;continue;}
      if(empty){result+=empty;empty=0;}
      const letter=pieces[piece[1]];result+=piece[0]==='r'?letter.toUpperCase():letter;
    }
    return result+(empty||'');
  }).join('/')+' '+(turn==='r'?'w':'b');
  const position=new Position();position.fromFen(fen);
  const square=p=>(p[0]+3)+((p[1]+3)<<4);
  const allowed=new Set(legalMoves.map(m=>MOVE(square(m.from),square(m.to))));
  // Search starts from a FEN with no game history. Apply the host's repetition
  // restrictions at the root, including move ordering and opening-book moves.
  const makeMove=position.makeMove,bookMove=position.bookMove;
  position.makeMove=function(move){return this.distance===0&&!allowed.has(move)?false:makeMove.call(this,move);};
  position.bookMove=function(){const move=bookMove.call(this);return allowed.has(move)?move:0;};
  const search=new Search(position,16),root=search.searchRoot;
  search.searchRoot=function(depth){
    const score=root.call(this,depth),move=this.mvResult;
    self.postMessage({type:'progress',move:{from:[FILE_X(SRC(move))-3,RANK_Y(SRC(move))-3],to:[FILE_X(DST(move))-3,RANK_Y(DST(move))-3]}});
    return score;
  };
  const budgets=[200,400,800,1500,2500],depths=[1,2,4,6,12];
  search.searchMain(depths[level-1],budgets[level-1]);
  self.postMessage({type:'done'});
};
