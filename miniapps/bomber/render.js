function drawArena(canvas,s,clock){
  const c=canvas.getContext('2d'),n=Bomber.size,t=48,w=n*t;
  if(canvas.width!==w*2){canvas.width=w*2;canvas.height=w*2;}
  c.setTransform(2,0,0,2,0,0);c.clearRect(0,0,w,w);
  function round(x,y,width,height,r,fill,stroke){c.beginPath();c.roundRect(x,y,width,height,r);if(fill){c.fillStyle=fill;c.fill();}if(stroke){c.strokeStyle=stroke;c.lineWidth=1.5;c.stroke();}}
  function circle(x,y,r,color){c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fillStyle=color;c.fill();}
  round(0,0,w,w,20,'#142839');
  for(let i=0;i<n*n;i++){
    const[x,y]=Bomber.xy(i),px=x*t,py=y*t,v=s.board[i];
    round(px+2,py+2,t-4,t-4,7,(x+y)%2?'#193244':'#1b3648');
    if(v===1){round(px+3,py+6,t-6,t-9,8,'#0b1c2b');round(px+3,py+3,t-6,t-10,8,'#345066','#486478');round(px+9,py+8,t-18,5,2,'#567086');}
    if(v===2){round(px+5,py+9,t-10,t-12,7,'#8d4d47');round(px+5,py+5,t-10,t-13,7,'#c67d67','#dea387');c.strokeStyle='#99584e';c.lineWidth=3;c.beginPath();c.moveTo(px+12,py+12);c.lineTo(px+36,py+34);c.moveTo(px+36,py+12);c.lineTo(px+12,py+34);c.stroke();}
    const closing=BomberRules.collapseAt(s,i)-s.time;
    if(closing>0&&closing<=3){c.globalAlpha=.4+Math.sin(clock*.012)*.2;round(px+2,py+2,t-4,t-4,7,'#efaa48');c.globalAlpha=1;}
  }
  for(const item of s.items){
    const[x,y]=Bomber.xy(item.i),cx=x*t+24,cy=y*t+24,config=BomberRules.items[item.type];round(cx-15,cy-15,30,30,9,config.color,'#ffffff77');
    c.fillStyle='#244a44';c.font='bold 20px sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText(config.symbol,cx,cy);
  }
  for(const b of s.bombs){
    const x=b.x*t+24,y=b.y*t+25,pulse=1+Math.sin((b.fuse-(b.at-s.time))*12)*.04;
    c.save();c.translate(x,y);c.scale(pulse,pulse);circle(0,3,17,'#08121f');circle(0,0,16,b.pierce?'#66518a':b.fuse<2?'#a9762c':'#263448');circle(-5,-5,5,b.pierce?'#aa96cf':b.fuse<2?'#e4b765':'#526276');
    c.strokeStyle='#e4b970';c.lineWidth=3;c.beginPath();c.moveTo(4,-14);c.quadraticCurveTo(5,-24,12,-20);c.stroke();circle(13,-20,3+(Math.sin(clock*.025)+1),'#ffd27a');
    c.strokeStyle=BomberRules.colors[b.owner];c.lineWidth=2;c.beginPath();c.arc(0,0,19,-Math.PI/2,-Math.PI/2+Math.PI*2*Math.max(0,(b.at-s.time)/b.fuse));c.stroke();c.restore();
  }
  for(const f of s.flames){
    const[x,y]=Bomber.xy(f.i),life=Math.min(1,(f.end-s.time)/.16);c.globalAlpha=life;
    round(x*t+3,y*t+9,42,30,12,'#f89453');round(x*t+9,y*t+3,30,42,12,'#f89453');round(x*t+12,y*t+12,24,24,9,'#ffe5a5');c.globalAlpha=1;
  }
  s.players.forEach((p,index)=>{
    if(!p.alive)return;
    const progress=p.walk?Math.min(1,(s.time-p.walk.at)/.12):1,x=(p.walk?p.walk.x+(p.x-p.walk.x)*progress:p.x)*t+24,y=(p.walk?p.walk.y+(p.y-p.walk.y)*progress:p.y)*t+24;
    c.save();c.translate(x,y);c.fillStyle='#07192377';c.beginPath();c.ellipse(0,17,17,6,0,0,Math.PI*2);c.fill();
    const main=BomberRules.colors[index],edge=['#427f79','#a55f62','#71618e','#9e813f'][index];
    round(-13,5,26,15,6,edge);round(-16,-18,32,32,11,main);round(-12,-12,24,18,7,'#f5eddb');
    round(-7,-6,3,7,1.5,'#253648');round(4,-6,3,7,1.5,'#253648');
    round(-16,9,32,5,2,index===0?'#f4ab87':'#b8b1e9');circle(0,-23,3,main);c.strokeStyle=edge;c.lineWidth=2;c.beginPath();c.moveTo(0,-20);c.lineTo(0,-23);c.stroke();c.restore();
    if(p.shield>0||p.protectedUntil>s.time){c.strokeStyle=p.protectedUntil>s.time?'#fff5c4':'#8ecff0';c.lineWidth=p.protectedUntil>s.time?3:2;c.beginPath();c.arc(x,y,23,0,Math.PI*2);c.stroke();}
  });
}
