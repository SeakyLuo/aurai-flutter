var CardUI=(function(){
  var selected=null,key='';
  function reset(){selected=null;key='';}
  function render(root,v,own,api){
    var next=v.game+':'+v.ply;if(next!==key){selected=null;key=next;}
    var el=api.el;root.replaceChildren();root.className='junqi-root';
    var heading=el('div','','junqi-heading');heading.append(el('span','陆战棋 · 翻棋','junqi-kicker'),el('span',v.colors[0]===null?'翻棋定阵营':(v.colors[0]===0?'你执红方':'你执蓝方'),'junqi-side'));root.append(heading);
    var board=el('div','','junqi-board');var ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg');svg.setAttribute('viewBox','0 0 250 570');svg.setAttribute('aria-hidden','true');svg.classList.add('junqi-tracks');
    function y(i){return 25+Math.floor(i/5)*46+(i>=30?14:0);}
    for(var a=0;a<60;a++)for(var b=a+1;b<60;b++)if(Cards.road(a,b)){var line=document.createElementNS(ns,'line');line.setAttribute('x1',25+a%5*50);line.setAttribute('y1',y(a));line.setAttribute('x2',25+b%5*50);line.setAttribute('y2',y(b));line.setAttribute('class',Cards.rail(a,b)?'rail':'road');svg.append(line);}
    board.append(svg);var legal=own?own.moves:[],targets=selected===null?[]:legal.filter(function(m){return m.from===selected;}).map(function(m){return m.to;});
    v.board.forEach(function(p,i){var isCamp=Cards.camps.indexOf(i)>=0,target=targets.indexOf(i)>=0,canSelect=p&&p.open&&own&&p.color===v.colors[own.seat]&&legal.some(function(m){return m.from===i;}),canFlip=p&&!p.open;
      var button=el('button','','junqi-cell'+(isCamp?' camp':'')+(p?' occupied':'')+(p&&p.open?' color-'+p.color:'')+(p&&!p.open?' concealed':'')+(selected===i?' selected':'')+(target?' destination':'')+(v.last&&v.last.to===i?' last':''));button.type='button';button.style.left=(10+i%5*20)+'%';button.style.top=(y(i)/570*100)+'%';
      var text=p?(p.open?Cards.names[p.rank]:'✦'):isCamp?'营':'';button.append(el('span',text));button.disabled=!api.canPlay||!(canSelect||canFlip||target);button.setAttribute('aria-label','第 '+(Math.floor(i/5)+1)+' 排第 '+(i%5+1)+' 列，'+(p?p.open?(p.color===0?'红方':'蓝方')+text:'未翻开的棋子':isCamp?'行营':'空位')+(target?'，可到达':''));button.setAttribute('aria-pressed',String(selected===i));
      button.onclick=function(){if(target){api.act('move',{from:selected,to:i});return;}if(canFlip){api.act('flip',{at:i});return;}selected=selected===i?null:i;render(root,v,own,api);};board.append(button);
    });root.append(board);
    var hint=v.phase==='finished'?v.result:!own?'正在观战':!api.canPlay?v.players[v.turn].name+'正在行动':selected!==null?'点击标记位置走棋，也可以翻开暗棋':v.colors[own.seat]===null?'翻开任意一枚棋子，确定你的阵营':'翻开暗棋，或选择己方棋子移动';root.append(el('p',hint,'junqi-hint'));
    var legend=el('div','','junqi-legend');legend.append(el('span','◎ 行营免攻击'),el('span','━ 铁路可连走'),el('span','✦ 先翻再走'));root.append(legend);
  }
  return {render:render,reset:reset};
})();
