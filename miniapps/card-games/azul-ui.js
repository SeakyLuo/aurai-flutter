var CardUI=(function(){
  var source=null,color=null,revision='',otherOpen=false;
  var marks=['✦','◆','✿','✧','◈'];
  function reset(){source=null;color=null;revision='';otherOpen=false;}
  function render(root,v,own,api){
    var next=v.game+':'+v.ply;if(next!==revision){source=null;color=null;revision=next;}
    var el=api.el;root.replaceChildren();root.className='azul-root';
    function tile(c,ghost){var node=el('span',c===-1?'1':marks[c],'azul-tile'+(ghost?' ghost':''));node.dataset.color=String(c);node.setAttribute('aria-label',c===-1?'先手标记':Cards.names[c]);return node;}
    function button(text,fn,disabled,primary){var b=el('button',text,'aurai-button'+(primary?' aurai-button--primary':''));b.type='button';b.disabled=disabled;b.onclick=fn;return b;}
    var summary=el('div','','azul-summary');
    summary.append(el('span','第 '+v.round+' 轮','aurai-muted'));
    v.boards.forEach(function(b,i){var p=el('div','','azul-score');p.append(el('span',v.players[i].name),el('strong',b.score+' 分'));summary.append(p);});root.append(summary);
    if(v.stage==='roundEnd'||v.phase==='finished'){
      var report=el('section','','azul-report');report.append(el('h2',v.phase==='finished'?v.result:'本轮铺墙完成'));
      v.roundResult.forEach(function(r,i){var row=el('div','','azul-result-row');row.append(el('strong',v.players[i].name),el('span','铺砖 +'+r.earned+' · 地板 −'+r.penalty));report.append(row);
        if(v.phase==='finished'){var b=v.bonuses[i];report.append(el('small','完成奖励：横行 +'+b.rows*2+' · 竖列 +'+b.columns*7+' · 同色 +'+b.colors*10,'aurai-muted'));}
      });root.append(report);
      if(v.stage==='roundEnd'&&own)root.append(button('开始下一轮',function(){api.act('nextRound',{});},!api.canPlay,true));
    }else{
      var factories=el('section','','azul-factories');factories.setAttribute('aria-label','五个工坊');
      v.factories.forEach(function(tiles,i){var factory=el('div','','azul-factory');factory.append(el('small','工坊 '+(i+1),'azul-factory-name'));var grid=el('div','','azul-factory-tiles');
        if(!tiles.length)factory.append(el('span','已取完','azul-empty'));
        tiles.forEach(function(c){var b=button('',function(){source=i;color=c;render(root,v,own,api);},!api.canPlay,false);b.className='azul-tile-pick';b.append(tile(c,false));b.classList.toggle('selected',source===i&&color===c);b.setAttribute('aria-label','工坊 '+(i+1)+'，取全部'+Cards.names[c]);grid.append(b);});factory.append(grid);factories.append(factory);});root.append(factories);
      var center=el('section','','azul-center');center.append(el('span','中央','azul-center-title'));
      if(v.marker){var marker=tile(-1,false);marker.title='首次从中央取砖，拿先手标记并占地板一格';center.append(marker);}
      [0,1,2,3,4].forEach(function(c){var n=v.center.filter(function(x){return x===c;}).length;if(!n)return;
        var b=button('',function(){source=-1;color=c;render(root,v,own,api);},!api.canPlay,false);b.className='azul-center-pick';b.append(tile(c,false),el('b','×'+n));b.classList.toggle('selected',source===-1&&color===c);b.setAttribute('aria-label','中央，取 '+n+' 块'+Cards.names[c]);center.append(b);});
      if(!v.center.length)center.append(el('span','工坊余砖会放在这里','azul-empty'));root.append(center);
    }
    if(!own){root.append(el('p','正在观战','aurai-muted'));v.boards.forEach(function(b,i){drawBoard(b,i,false);});return;}
    var chosen=source===null?[]:source===-1?v.center:v.factories[source];
    var count=chosen.filter(function(c){return c===color;}).length;
    if(v.stage==='draft')root.append(el('p',!api.canPlay?'等待对手取砖':color===null?'先选一个工坊或中央的颜色，再点准备行。':'已选 '+count+' 块'+Cards.names[color]+' · 点准备行放置'+(source===-1&&v.marker?'，同时拿先手标记':''),'azul-hint'));
    drawBoard(v.boards[own.seat],own.seat,true);
    var opponent=el('details','','azul-opponent');opponent.open=otherOpen;opponent.append(el('summary','查看'+v.players[1-own.seat].name+'的墙面'));opponent.ontoggle=function(){otherOpen=opponent.open;};root.append(opponent);drawBoard(v.boards[1-own.seat],1-own.seat,false,opponent);
    function drawBoard(board,seat,interactive,parent){
      var wrap=el('section','','azul-player-board'),labels=el('div','','azul-board-labels');labels.append(el('span',interactive?'你的准备行':v.players[seat].name+'的准备行'),el('span','彩墙'));wrap.append(labels);
      var boardGrid=el('div','','azul-board-grid');
      board.lines.forEach(function(line,row){
        var permitted=interactive&&api.canPlay&&v.stage==='draft'&&color!==null&&Cards.canPlace(board,color,row);
        var pattern=button('',function(){api.act('draft',{source:source,color:color,row:row});},!permitted,false);pattern.className='azul-pattern'+(permitted?' available':'');pattern.setAttribute('aria-label','第 '+(row+1)+' 准备行，已放 '+line.count+' / '+(row+1));
        for(var i=0;i<=row;i++){if(i>=row+1-line.count)pattern.append(tile(line.color,false));else pattern.append(el('span','','azul-space'));}
        boardGrid.append(pattern);
        var wallRow=el('div','','azul-wall-row');
        for(var col=0;col<5;col++){var index=row*5+col,c=(col-row+5)%5,filled=board.wall[index]!==null,t=tile(c,!filled);if(permitted&&c===color)t.classList.add('target');wallRow.append(t);}boardGrid.append(wallRow);
      });wrap.append(boardGrid);
      var floor=button('',function(){api.act('draft',{source:source,color:color,row:-1});},!interactive||!api.canPlay||v.stage!=='draft'||color===null,false);floor.className='azul-floor'+(interactive&&api.canPlay&&color!==null?' available':'');floor.setAttribute('aria-label','放入地板，扣分');
      var heading=el('span','地板','azul-floor-label');floor.append(heading);
      [1,1,2,2,2,3,3].forEach(function(p,i){var slot=el('span','','azul-floor-slot');slot.append(el('small','−'+p));slot.append(i<board.floor.length?tile(board.floor[i],false):el('span','','azul-space'));floor.append(slot);});wrap.append(floor);
      (parent||root).append(wrap);
    }
  }
  return {render:render,reset:reset};
})();
