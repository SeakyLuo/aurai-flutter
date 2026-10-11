var CardUI=(function(){
  var showHome=false;
  function reset(){showHome=false;}
  function render(root,v,own,api){
    var el=api.el;root.replaceChildren();root.className='battleship-root';
    function button(text,fn,disabled,primary){var b=el('button',text,'aurai-button'+(primary?' aurai-button--primary':''));b.type='button';b.disabled=disabled;b.onclick=fn;return b;}
    function board(shots,fleet,interactive){
      var grid=el('div','','sea-grid');grid.setAttribute('role','group');grid.setAttribute('aria-label',interactive?'选择射击坐标':'舰队海域');grid.append(el('span','','sea-axis'));
      for(var x=1;x<=10;x++)grid.append(el('span',String(x),'sea-axis'));
      for(var y=0;y<10;y++){
        grid.append(el('span','ABCDEFGHIJ'[y],'sea-axis'));
        for(var x=0;x<10;x++){
          var cell=y*10+x,n=shots[cell],ship=fleet&&fleet.some(function(cells){return cells.indexOf(cell)>=0;});
          var square=el(interactive?'button':'span',n===1?'·':n>=2?'×':'','sea-cell'+(ship?' sea-ship':'')+(n?' sea-shot-'+n:''));
          var desc=Cards.coordinate(cell)+(n===1?'，落空':n===2?'，命中':n===3?'，击沉':ship?'，舰船':'，未射击');square.setAttribute('aria-label',desc);
          if(interactive){square.type='button';square.disabled=!api.canPlay||n!==0;square.onclick=(function(c){return function(){api.act('fire',{cell:c});};})(cell);}
          grid.append(square);
        }
      }
      return grid;
    }
    function fleetStatus(){var row=el('div','','sea-fleet-status');v.players.forEach(function(p,i){row.append(el('span',p.name+' · '+v.remaining[i]+' 艘'));});return row;}
    if(!own){
      root.append(el('p',v.stage==='deploy'?'双方正在布置舰队':'观战 · 未击沉舰船的位置保持隐藏','aurai-muted'));
      if(v.phase==='finished')root.append(el('h2',v.result));
      v.players.forEach(function(p,i){var panel=el('section','','sea-panel');panel.append(el('h3',p.name+'的射击记录'),board(v.shots[i],null,false));root.append(panel);});return;
    }
    if(v.stage==='deploy'){
      var setup=el('section','','sea-panel');setup.append(el('div','部署舰队','sea-eyebrow'),el('h2',v.ready[own.seat]?'舰队准备就绪':'找到你的秘密阵形'),el('p','五艘舰船 · 确认后对手无法看到位置','sea-caption'),board(v.shots[1-own.seat],own.fleet,false));root.append(setup);
      var actions=el('div','','sea-actions');actions.append(button('随机布阵',function(){api.act('shuffle',{});},!api.canPlay,false),button('确认出航',function(){api.act('deploy',{});},!api.canPlay,true));root.append(actions);return;
    }
    var panel=el('section','','sea-panel');panel.append(el('div','目标海域','sea-eyebrow'));
    if(v.phase==='finished')panel.append(el('h2',v.result));
    else panel.append(el('p',api.canPlay?'点击海域，发射一枚炮弹':'等待对方行动','sea-caption'));
    panel.append(board(v.shots[own.seat],null,v.phase==='playing'));
    var legend=el('div','','sea-legend');legend.append(el('span','· 落空'),el('span','× 命中'),el('span','■ 击沉'));panel.append(legend);root.append(panel,fleetStatus());
    var toggle=button(showHome?'收起我的海域':'查看我的海域',function(){showHome=!showHome;render(root,v,own,api);},false,false);toggle.setAttribute('aria-expanded',String(showHome));root.append(toggle);
    if(showHome){var home=el('section','','sea-panel sea-home');home.append(el('h3','我的海域'),board(v.shots[1-own.seat],own.fleet,false));root.append(home);}
  }
  return {render:render,reset:reset};
})();
