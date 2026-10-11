var CardUI=(function(){
  var mode='move',axis='h',choice=null,revision='';
  function reset(){mode='move';axis='h';choice=null;revision='';}
  function render(root,v,own,api){
    var key=v.game+':'+v.ply;if(key!==revision){choice=null;mode='move';revision=key;}root.replaceChildren();root.className='qr-root';var el=api.el;
    function button(text,fn,disabled,cls){var b=el('button',text,cls||'aurai-button');b.type='button';b.disabled=disabled;b.onclick=fn;return b;}
    var info=el('div','','qr-info');v.players.forEach(function(p,i){var item=el('span',p.name+' · '+v.remaining[i]+' 面墙');item.dataset.side=i;info.append(item);});root.append(info);
    var board=el('div','','qr-board');board.setAttribute('aria-label','步步为营棋盘');
    for(var i=0;i<81;i++)(function(at){var seat=v.pawns.indexOf(at),allowed=api.canPlay&&mode==='move'&&own.moves.indexOf(at)>=0,b=button('',function(){api.act('move',{to:at});},!allowed,'qr-cell'+(allowed?' reachable':''));
      b.setAttribute('aria-label','第 '+(Math.floor(at/9)+1)+' 行，第 '+(at%9+1)+' 列'+(seat>=0?'，'+v.players[seat].name:''));
      if(seat>=0){var pawn=el('span','','qr-pawn side-'+seat);if(v.phase==='playing'&&v.turn===seat)pawn.classList.add('thinking');b.append(pawn);}board.append(b);
    })(i);
    function wall(w,preview){var node=el('span','','qr-wall '+w.axis+(preview?' preview':''));node.style.left=((w.x+1)/9*100)+'%';node.style.top=((w.y+1)/9*100)+'%';board.append(node);}
    v.walls.forEach(function(w){wall(w,false);});
    if(mode==='wall'&&api.canPlay){for(var y=0;y<8;y++)for(var x=0;x<8;x++)(function(x,y){var legal=own.walls.some(function(w){return w.x===x&&w.y===y&&w.axis===axis;}),b=button('',function(){choice={x:x,y:y,axis:axis};render(root,v,own,api);},!legal,'qr-anchor');b.style.left=((x+1)/9*100)+'%';b.style.top=((y+1)/9*100)+'%';b.setAttribute('aria-label','在第 '+(y+1)+' 行第 '+(x+1)+' 列后放'+(axis==='h'?'横墙':'竖墙'));board.append(b);})(x,y);}
    if(choice)wall(choice,true);root.append(el('div','你的终点','qr-goal'),board,el('div','电脑的终点','qr-goal'));
    if(v.phase==='finished'){root.append(el('strong',v.result,'qr-result'));return;}
    var actions=el('div','','qr-actions');
    if(own){actions.append(button('走棋',function(){mode='move';choice=null;render(root,v,own,api);},!api.canPlay,'aurai-button'+(mode==='move'?' aurai-button--primary':'')),button('放墙',function(){mode='wall';choice=null;render(root,v,own,api);},!api.canPlay||!v.remaining[own.seat],'aurai-button'+(mode==='wall'?' aurai-button--primary':'')));
      if(mode==='wall'){actions.append(button(axis==='h'?'横向 ↔':'纵向 ↕',function(){axis=axis==='h'?'v':'h';choice=null;render(root,v,own,api);},!api.canPlay),button('确认放墙',function(){api.act('wall',choice);},!api.canPlay||!choice));}root.append(actions);
    }
    root.append(el('p',!own?'正在观战':!api.canPlay?'等待电脑行动':mode==='move'?'点亮格前进，或选择放墙阻挡对手':'点交点预览围墙，再确认放置','aurai-muted qr-help'));
  }
  return {render:render,reset:reset};
})();
