const svgNS='http://www.w3.org/2000/svg';
function node(tag,attrs,parent) {
  const el=document.createElementNS(svgNS,tag);
  for(const [key,value] of Object.entries(attrs)) el.setAttribute(key,String(value));
  if(parent)parent.append(el);return el;
}
function drawBoard(board,selected,pending,moves,last,winningLine,flip) {
  const el=$('board'),w=Chess.width,h=Chess.height,unit=40,margin=28,sw=(w-1)*unit+margin*2,sh=(h-1)*unit+margin*2;
  el.setAttribute('viewBox',`0 0 ${sw} ${sh}`);el.replaceChildren();
  $('game').style.setProperty('--board-ratio',sw/sh);
  const xy=p=>[margin+(flip?w-1-p[0]:p[0])*unit,margin+(flip?h-1-p[1]:p[1])*unit];
  const line=(a,b,color='#a69780',stroke=1)=>node('line',{x1:a[0],y1:a[1],x2:b[0],y2:b[1],stroke:color,'stroke-width':stroke,'stroke-linecap':'round'},el);
  const label=(p,value,size,color)=>{const t=node('text',{x:p[0],y:p[1],'text-anchor':'middle','dominant-baseline':'central','font-size':size,fill:color,'font-family':'system-ui, sans-serif'},el);t.textContent=value;return t;};
  for(let y=0;y<h;y++)line(xy([0,y]),xy([w-1,y]));
  for(let x=0;x<w;x++) {
    if(GAME==='xiangqi'&&x>0&&x<8){line(xy([x,0]),xy([x,4]));line(xy([x,5]),xy([x,9]));}
    else line(xy([x,0]),xy([x,h-1]));
    label([xy([x,0])[0],sh-10],String.fromCharCode(65+x),10,'#85765f');
  }
  for(let y=0;y<h;y++)label([10,xy([0,y])[1]],y+1,10,'#85765f');
  if(GAME==='xiangqi') {
    [[3,0,5,2],[5,0,3,2],[3,7,5,9],[5,7,3,9]].forEach(p=>line(xy(p.slice(0,2)),xy(p.slice(2))));
    label([sw*.28,sh/2],'楚 河',16,'#a18c6e');label([sw*.72,sh/2],'汉 界',16,'#a18c6e');
  } else {
    [[3,3],[11,3],[7,7],[3,11],[11,11]].forEach(p=>{const [cx,cy]=xy(p);node('circle',{cx,cy,r:2.8,fill:'#94836a'},el);});
  }
  if(last?.from){const [cx,cy]=xy(last.from);node('circle',{cx,cy,r:5,fill:'#a9875b',opacity:.65},el);}
  board.forEach((piece,i)=>{
    if(!piece)return;const p=[i%w,Math.floor(i/w)],[cx,cy]=xy(p);
    const group=node('g',{'aria-label':(Chess.names?Chess.names[piece]:Chess.sides[piece])+' '+Chess.coordinate(p)},el);
    const red=piece[0]==='r',black=piece[0]==='b';
    node('circle',{cx,cy:cy+1.5,r:GAME==='xiangqi'?17:16.5,fill:'#5b4d38',opacity:.14},group);
    node('circle',{cx,cy,r:GAME==='xiangqi'?17:16.5,fill:GAME==='xiangqi'?'#f6f0e4':black?'#303438':'#faf8f2',stroke:GAME==='xiangqi'?(red?'#b96658':'#615b52'):black?'#222629':'#b7b0a5','stroke-width':1.2},group);
    if(GAME==='xiangqi'){
      node('circle',{cx,cy,r:14.2,fill:'none',stroke:red?'#b96658':'#777068','stroke-width':.7},group);
      const t=node('text',{x:cx,y:cy,'text-anchor':'middle','dominant-baseline':'central','font-size':23,'font-family':'serif','font-weight':600,fill:red?'#a84035':'#3d3b37'},group);t.textContent=Chess.names[piece];
    }
    if(winningLine.some(q=>q[0]===p[0]&&q[1]===p[1]))node('circle',{cx,cy,r:18,fill:'none',stroke:'#56816a','stroke-width':2.2},el);
  });
  if(last){
    const [cx,cy]=xy(last.to);
    if(GAME==='xiangqi')node('circle',{cx,cy,r:19,fill:'none',stroke:'#bc7354','stroke-width':1.8},el);
    else node('rect',{x:cx-4,y:cy-4,width:8,height:8,rx:1.5,fill:'#bc7354',stroke:'#faf3e7','stroke-width':1},el);
  }
  if(selected){const [cx,cy]=xy(selected);node('circle',{cx,cy,r:19,fill:'none',stroke:'#56816a','stroke-width':2.4},el);}
  if(selected)moves.filter(m=>m.from&&m.from[0]===selected[0]&&m.from[1]===selected[1]).forEach(m=>{
    const [cx,cy]=xy(m.to),capture=!!board[m.to[1]*w+m.to[0]];
    node('circle',{cx,cy,r:capture?19:6,fill:capture?'none':'#56816a',stroke:capture?'#56816a':'none','stroke-width':2,opacity:.8},el);
  });
  if(pending){const [cx,cy]=xy(pending.to);node('circle',{cx,cy,r:18,fill:'#56816a','fill-opacity':.2,stroke:'#56816a','stroke-width':2,'stroke-dasharray':'4 3'},el);}
}
function boardPoint(event,flip) {
  const r=$('board').getBoundingClientRect(),w=Chess.width,h=Chess.height,sw=(w-1)*40+56,sh=(h-1)*40+56;
  let x=Math.round(((event.clientX-r.left)/r.width*sw-28)/40),y=Math.round(((event.clientY-r.top)/r.height*sh-28)/40);
  if(x<0||x>=w||y<0||y>=h)return null;
  return flip?[w-1-x,h-1-y]:[x,y];
}
