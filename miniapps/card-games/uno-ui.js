var CardUI=(function(){
  var selected=null,shout=true,epoch='';
  var colors={r:'红色',y:'黄色',g:'绿色',b:'蓝色'},marks={skip:'⊘',reverse:'⇄',draw2:'+2',wild:'◇',draw4:'+4'};
  function reset(){selected=null;shout=true;epoch='';}
  function render(root,v,own,api){
    var key=v.game+':'+v.ply+':'+v.turn+':'+v.stage;if(key!==epoch){selected=null;epoch=key;}
    var oldHand=root.querySelector('.uno-hand'),scroll=oldHand?oldHand.scrollLeft:0;
    root.replaceChildren();root.className='uno-table';var el=api.el;
    function button(text,fn,cls){var b=el('button',text,'aurai-button '+(cls||''));b.type='button';b.disabled=!api.canPlay;b.onclick=fn;return b;}
    function card(c,interactive){var node=el(interactive?'button':'div','','uno-card uno-'+c.color);if(interactive)node.type='button';node.append(el('span',marks[c.value]||c.value,'uno-corner'),el('strong',marks[c.value]||c.value,'uno-face'),el('span',c.color==='k'?'万能':colors[c.color],'uno-color-name'));node.setAttribute('aria-label',Cards.label(c));return node;}
    var table=el('div','','uno-center');var deck=el('div','','uno-deck');deck.append(el('span','UNO','uno-deck-mark'));deck.setAttribute('aria-label','摸牌堆');table.append(deck,card(v.top,false));root.append(table);
    var current=el('div','','uno-current');current.append(el('i','','uno-dot uno-'+v.color),el('span',colors[v.color]||'选择颜色'),el('span',v.direction===1?'顺时针 ↻':'逆时针 ↺','uno-direction'));root.append(current);
    if(own&&own.evidence){var proof=el('details','','uno-evidence');proof.append(el('summary',own.evidence.illegal?'质疑成功 · 查看当时手牌':'质疑失败 · 查看当时手牌'));proof.append(el('p',own.evidence.hand.map(Cards.label).join('、')));root.append(proof);}
    if(v.phase==='finished'){root.append(el('p',v.players[v.winner].name+' 获胜 · 本局 '+v.score+' 分','uno-result'));}
    var hint=v.phase==='finished'?'本局已结束':!api.canPlay?'等待其他玩家':v.stage==='challenge'?'对方打出了 +4，你可以接受或质疑':v.stage==='color'?'选择起始牌的颜色':v.stage==='drawn'?'可以打出刚摸到的牌，或保留':'选择一张牌，再点击出牌';root.append(el('p',hint,'uno-hint'));
    if(api.canPlay&&v.unoSeat!==null)root.append(button('抓漏喊 UNO · '+v.players[v.unoSeat].name,function(){api.act('catch',{});}));
    if(api.canPlay&&v.stage==='challenge'){
      var challenge=el('div','','uno-actions');challenge.append(button('接受 · 摸 4 张',function(){api.act('accept',{});}),button('质疑 +4',function(){api.act('challenge',{});},'aurai-button--primary'));root.append(challenge);
    }
    if(!own)return;
    var hand=el('div','','uno-hand');own.hand.forEach(function(c){var b=card(c,true),legal=api.canPlay&&own.playable.indexOf(c.id)>=0;b.disabled=!legal;b.classList.toggle('uno-playable',legal);b.classList.toggle('uno-selected',selected===c.id);b.onclick=function(){selected=selected===c.id?null:c.id;render(root,v,own,api);};hand.append(b);});root.append(hand);hand.scrollLeft=scroll;
    if(!api.canPlay||v.phase==='finished')return;
    var choice=own.hand.find(function(c){return c.id===selected;});
    if(v.stage==='color'||choice&&choice.color==='k'){
      root.append(el('p',v.stage==='color'?'选择颜色':'选择颜色并出牌','uno-hint'));
      var palette=el('div','','uno-palette');Object.keys(colors).forEach(function(color){var b=button(colors[color],function(){api.act(v.stage==='color'?'color':'play',v.stage==='color'?{color:color}:{card:selected,color:color,uno:shout});},'uno-swatch uno-'+color);palette.append(b);});root.append(palette);
    }
    if(v.stage!=='play'&&v.stage!=='drawn')return;
    if(own.hand.length===2){var label=el('label','','uno-call');var check=document.createElement('input');check.type='checkbox';check.checked=shout;check.onchange=function(){shout=check.checked;};label.append(check,el('span','出牌时喊 UNO！'));root.append(label);}
    var actions=el('div','','uno-actions');
    if(v.stage==='drawn')actions.append(button('保留，结束回合',function(){api.act('pass',{});}));
    else actions.append(button('摸一张',function(){api.act('draw',{});}));
    var play=button('出牌',function(){api.act('play',{card:selected,uno:shout});},'aurai-button--primary');play.disabled=!choice||choice.color==='k';actions.append(play);root.append(actions);
  }
  return {render:render,reset:reset};
})();
