const drawXiangqiBoard=drawBoard;
drawBoard=function(board,selected,pending,moves,last,winningLine,flip){
  if(Chess.mode!=='banqi'){$('board').setAttribute('aria-label',Chess.mode==='jieqi'?'揭棋棋盘':'中国象棋棋盘');drawXiangqiBoard(board,selected,pending,moves,last,winningLine,flip);return;}
  const el=$('board'),unit=40,margin=28,sw=176,sh=336;
  el.setAttribute('viewBox',`0 0 ${sw} ${sh}`);el.setAttribute('aria-label','暗棋棋盘');el.replaceChildren();$('game').style.setProperty('--board-ratio',sw/sh);
  const xy=p=>[margin+p[0]*unit,margin+p[1]*unit];
  for(let y=0;y<8;y++)for(let x=0;x<4;x++){
    const [cx,cy]=xy([x,y]);node('rect',{x:cx-20,y:cy-20,width:40,height:40,fill:(x+y)%2?'#cbb99622':'none',stroke:'#aa997b','stroke-width':.6},el);
  }
  for(let x=0;x<4;x++){const t=node('text',{x:xy([x,0])[0],y:sh-7,'text-anchor':'middle','font-size':10,fill:'#85765f'},el);t.textContent=String.fromCharCode(65+x);}
  for(let y=0;y<8;y++){const t=node('text',{x:4,y:xy([0,y])[1]+3,'font-size':9,fill:'#85765f'},el);t.textContent=y+1;}
  board.forEach((piece,i)=>{
    if(!piece)return;const p=[i%4,Math.floor(i/4)],[cx,cy]=xy(p),covered=piece==='uD',red=piece[0]==='r';
    const group=node('g',{'aria-label':(covered?'暗子':Chess.legend[piece])+' '+Chess.coordinate(p)},el);
    node('circle',{cx,cy:cy+1.5,r:17,fill:'#5b4d38',opacity:.14},group);
    node('circle',{cx,cy,r:17,fill:covered?'#c9b58f':'#f6f0e4',stroke:covered?'#827253':red?'#b96658':'#615b52','stroke-width':1.2},group);
    node('circle',{cx,cy,r:14.2,fill:'none',stroke:covered?'#a18c66':red?'#b96658':'#777068','stroke-width':.7},group);
    if(covered)node('path',{d:`M ${cx} ${cy-7} l 7 7 -7 7 -7 -7 Z`,fill:'none',stroke:'#827253','stroke-width':1.2,'stroke-linejoin':'round'},group);
    else {const text=node('text',{x:cx,y:cy,'text-anchor':'middle','dominant-baseline':'central','font-size':23,'font-family':'serif','font-weight':600,fill:red?'#a84035':'#3d3b37'},group);text.textContent=Chess.names[piece];}
  });
  if(last){const [cx,cy]=xy(last.to);node('circle',{cx,cy,r:19,fill:'none',stroke:'#bc7354','stroke-width':1.8},el);}
  if(pending){const [cx,cy]=xy(pending.to);node('circle',{cx,cy,r:18,fill:'#56816a','fill-opacity':.2,stroke:'#56816a','stroke-width':2,'stroke-dasharray':'4 3'},el);}
  if(selected){const [cx,cy]=xy(selected);node('circle',{cx,cy,r:19,fill:'none',stroke:'#56816a','stroke-width':2.4},el);moves.filter(m=>m.from&&m.from[0]===selected[0]&&m.from[1]===selected[1]).forEach(m=>{const [x,y]=xy(m.to),capture=!!board[m.to[1]*4+m.to[0]];node('circle',{cx:x,cy:y,r:capture?19:6,fill:capture?'none':'#56816a',stroke:capture?'#56816a':'none','stroke-width':2,opacity:.8},el);});}
};
