const svgNS='http://www.w3.org/2000/svg';
let paintedPosition='',paintedScene='';
function node(tag,attrs,parent){const el=document.createElementNS(svgNS,tag);for(const [key,value]of Object.entries(attrs))el.setAttribute(key,String(value));if(parent)parent.append(el);return el;}
function boardLabel(el,x,y,value){const t=node('text',{x,y,class:'board-label','text-anchor':'middle','dominant-baseline':'central'},el);t.textContent=value;}
function marble(el,x,y,side,r,extra=''){
  const group=node('g',{class:'stone '+side+' '+extra},el);
  node('circle',{cx:x,cy:y+2,r,fill:'#000',opacity:.12},group);
  node('circle',{cx:x,cy:y,r,class:'stone-face'},group);
  node('ellipse',{cx:x-r*.23,cy:y-r*.35,rx:r*.38,ry:r*.2,fill:'#fff',opacity:.28},group);
  return group;
}
function starPoint(p){return [250+24*((p[0]-8)+(p[1]-8)/2),224+21*(p[1]-8)];}
function drawBoard(board,selected,pending,moves,last,winningLine){
  const scene=JSON.stringify([board,selected,pending,moves,last,winningLine]);
  if(scene===paintedScene&&$('board').childElementCount)return;
  paintedScene=scene;
  const el=$('board'),key=board.join(','),animate=paintedPosition!==''&&key!==paintedPosition;paintedPosition=key;
  el.replaceChildren();
  if(GAME==='halma'){
    el.setAttribute('viewBox','80 30 340 390');$('game').style.setProperty('--board-ratio',340/390);
    node('path',{d:'M250 45 L302 131 L407 131 L355 224 L407 317 L302 317 L250 403 L198 317 L93 317 L145 224 L93 131 L198 131 Z',class:'star-paper'},el);
    for(const i of Chess.holes){
      const p=[i%17,Math.floor(i/17)],[x,y]=starPoint(p),camp=p[1]<4?'home-b':p[1]>12?'home-w':'';
      node('circle',{cx:x,cy:y,r:8,class:'hole '+camp},el);
      if(board[i])marble(el,x,y,board[i],8.6,animate&&last?.to[0]===p[0]&&last?.to[1]===p[1]?'arrive':'');
      if(selected&&selected[0]===p[0]&&selected[1]===p[1])node('circle',{cx:x,cy:y,r:12,class:'selection'},el);
    }
    if(selected)for(const m of moves.filter(m=>m.from[0]===selected[0]&&m.from[1]===selected[1])){const [cx,cy]=starPoint(m.to);node('circle',{cx,cy,r:7,class:'legal-dot'},el);}
    if(last){const route=[last.from,...last.path].map(starPoint);node('polyline',{points:route.map(p=>p.join(',')).join(' '),class:'jump-trail'},el);}
    boardLabel(el,320,64,'薄 荷');boardLabel(el,180,392,'蜜 桃');
    return;
  }
  const w=Chess.width,h=Chess.height,cell=44,pad=24,sw=w*cell+pad*2,sh=h*cell+pad*2;
  el.setAttribute('viewBox',`0 0 ${sw} ${sh}`);$('game').style.setProperty('--board-ratio',sw/sh);
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const cx=pad+(x+.5)*cell,cy=pad+(y+.5)*cell,i=y*w+x;
    if(GAME==='reversi')node('rect',{x:pad+x*cell,y:pad+y*cell,width:cell,height:cell,rx:3,class:'felt-cell '+((x+y)%2?'alternate':'')},el);
    else node('circle',{cx,cy,r:17.5,class:'slot'},el);
    if(board[i]){
      const changed=GAME==='reversi'&&last?.flips.includes(i),latest=last?.to[0]===x&&last?.to[1]===y;
      const group=marble(el,cx,cy,board[i],17,animate?(changed?'flip':latest?(GAME==='connect4'?'fall':'arrive'):''):'');
      group.style.setProperty('--fall',`-${cy+24}px`);
      if(latest)node('circle',{cx,cy,r:3,class:'last-dot'},el);
    }else if(GAME==='reversi'&&moves.some(m=>m.to[0]===x&&m.to[1]===y))node('circle',{cx,cy,r:4,class:'legal-dot'},el);
    if(winningLine.some(p=>p[0]===x&&p[1]===y))node('circle',{cx,cy,r:20,class:'winner-ring'},el);
  }
  for(let x=0;x<w;x++)boardLabel(el,pad+(x+.5)*cell,sh-10,String.fromCharCode(65+x));
  if(GAME==='reversi')for(let y=0;y<h;y++)boardLabel(el,11,pad+(y+.5)*cell,y+1);
  if(GAME==='connect4')for(const m of moves){const cx=pad+(m.to[0]+.5)*cell;node('path',{d:`M${cx-4} 9 L${cx} 14 L${cx+4} 9`,class:'column-arrow'},el);}
}
function boardPoint(event){
  const box=$('board').getBoundingClientRect();
  if(GAME==='halma'){
    const x=80+(event.clientX-box.left)/box.width*340,y=30+(event.clientY-box.top)/box.height*390;
    let closest=null,distance=14;
    for(const i of Chess.holes){const p=[i%17,Math.floor(i/17)],v=starPoint(p),d=Math.hypot(x-v[0],y-v[1]);if(d<distance){closest=p;distance=d;}}
    return closest;
  }
  const w=Chess.width,h=Chess.height,x=Math.floor(((event.clientX-box.left)/box.width*(w*44+48)-24)/44),y=Math.floor(((event.clientY-box.top)/box.height*(h*44+48)-24)/44);
  if(x<0||x>=w||y<0||y>=h)return null;
  return [x,y];
}
