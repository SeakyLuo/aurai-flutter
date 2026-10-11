const svgNS='http://www.w3.org/2000/svg';
function node(tag,attrs,parent) {
  const el=document.createElementNS(svgNS,tag);
  for(const [key,value] of Object.entries(attrs))el.setAttribute(key,String(value));
  if(parent)parent.append(el);return el;
}
function drawBoard(board,selected,pending,moves,last,winningLine) {
  const el=$('board');el.setAttribute('viewBox','0 0 336 336');el.replaceChildren();
  $('game').style.setProperty('--board-ratio',1);
  const xy=p=>[48+p[0]*120,48+p[1]*120];
  for(const position of [108,228]) {
    node('line',{x1:position,y1:12,x2:position,y2:324,class:'neon-grid'},el);
    node('line',{x1:12,y1:position,x2:324,y2:position,class:'neon-grid'},el);
  }
  board.forEach((piece,i)=>{
    const p=[i%3,Math.floor(i/3)],[cx,cy]=xy(p);
    const cell=node('g',{'aria-label':(piece?Chess.sides[piece]:'空格')+' '+Chess.coordinate(p)},el);
    if(!piece)return;
    const attrs={class:'neon-mark '+piece,fill:'none','stroke-linecap':'round','stroke-linejoin':'round','stroke-width':10};
    if(piece==='x')node('path',{...attrs,d:`M ${cx-23} ${cy-23} L ${cx+23} ${cy+23} M ${cx+23} ${cy-23} L ${cx-23} ${cy+23}`},cell);
    else node('circle',{...attrs,cx,cy,r:28},cell);
    if(last?.to[0]===p[0]&&last?.to[1]===p[1])node('circle',{cx,cy:cy+44,r:2.5,class:'last-mark'},cell);
  });
  if(winningLine.length) {
    const [a,b]=[xy(winningLine[0]),xy(winningLine[2])];
    node('line',{x1:a[0],y1:a[1],x2:b[0],y2:b[1],class:'winning-line'},el);
  }
  if(pending){const [cx,cy]=xy(pending.to);node('rect',{x:cx-44,y:cy-44,width:88,height:88,rx:20,class:'pending-cell'},el);}
}
function boardPoint(event) {
  const rect=$('board').getBoundingClientRect();
  const x=(event.clientX-rect.left)/rect.width*336,y=(event.clientY-rect.top)/rect.height*336;
  if(x<0||x>=336||y<0||y>=336)return null;
  return [x<108?0:x<228?1:2,y<108?0:y<228?1:2];
}
