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
    function player(seat,side){
      var p=v.players[seat],active=v.phase==='playing'&&v.turn===seat,box=el('div','','uno-player '+side+(active?' active':''));
      box.append(el('span','UNO','uno-avatar'),el('strong',p.name,'uno-player-name'),el('span',v.counts[seat]===1?'UNO!':v.counts[seat]+' 张','uno-count'));
      box.setAttribute('aria-label',p.name+'，'+v.counts[seat]+' 张'+(active?'，正在行动':''));return box;
    }
    var local=own?own.seat:0,desk=el('section','','uno-desk');
    desk.append(player((local+2)%4,'uno-opposite'),player((local+3)%4,'uno-left'),player((local+1)%4,'uno-right'));
    var middle=el('div','','uno-middle'),table=el('div','','uno-center');var deck=el('div','','uno-deck');deck.append(el('span','UNO','uno-deck-mark'));deck.setAttribute('aria-label','摸牌堆');table.append(deck,card(v.top,false));middle.append(table);
    var current=el('div','','uno-current');current.append(el('i','','uno-dot uno-'+v.color),el('span',colors[v.color]||'选择颜色'),el('span',v.direction===1?'↻':'↺','uno-direction'));current.lastChild.setAttribute('aria-label',v.direction===1?'顺时针':'逆时针');middle.append(current);
    desk.append(middle);root.append(desk);
    if(own&&own.evidence){var proof=el('details','','uno-evidence');proof.append(el('summary',own.evidence.illegal?'质疑成功 · 查看当时手牌':'质疑失败 · 查看当时手牌'));proof.append(el('p',own.evidence.hand.map(Cards.label).join('、')));root.append(proof);}
    if(v.phase==='finished'){middle.append(el('p',v.players[v.winner].name+' 获胜 · 本局 '+v.score+' 分','uno-result'));}
    if(v.phase==='finished'){showRemainingHands(root,v,card);return;}
    var canJump=own&&api.canJump&&v.jumpOpen===true&&v.phase==='playing'&&v.stage==='play'&&v.turn!==own.seat&&own.hand.some(function(c){return c.color===v.top.color&&c.value===v.top.value;});
    var hint=v.phase==='finished'?'':canJump?'点击亮起的手牌抢出':!api.canPlay?'等待'+v.players[v.turn].name:v.stage==='challenge'?'对方打出了 +4，你可以接受或质疑':v.stage==='color'?'选择起始牌的颜色':v.stage==='drawn'?'打出刚摸的牌，或保留':'选择手牌出牌';if(hint)middle.append(el('p',hint,'uno-hint'));
    var controls=el('div','','uno-controls');root.append(controls);
    if(api.canPlay&&v.unoSeat!==null)controls.append(button('抓漏喊 UNO · '+v.players[v.unoSeat].name,function(){api.act('catch',{});}));
    if(api.canPlay&&v.stage==='challenge'){
      var challenge=el('div','','uno-actions');challenge.append(button('接受 · 摸 4 张',function(){api.act('accept',{});}),button('质疑 +4',function(){api.act('challenge',{});},'aurai-button--primary'));controls.append(challenge);
    }
    root.append(player(local,'uno-self'));
    if(!own)return;
    var hand=el('div','','uno-hand');hand.setAttribute('aria-label','我的手牌，左右滑动查看');own.hand.forEach(function(c){var b=card(c,true),jump=canJump&&c.color===v.top.color&&c.value===v.top.value,legal=jump||api.canPlay&&own.playable.indexOf(c.id)>=0;b.disabled=!legal;b.classList.toggle('uno-playable',legal);b.classList.toggle('uno-selected',selected===c.id);b.setAttribute('aria-pressed',String(selected===c.id));b.onclick=function(){if(jump){api.act('jump',{card:c.id,uno:shout});return;}selected=selected===c.id?null:c.id;render(root,v,own,api);};hand.append(b);});root.append(hand);hand.scrollLeft=scroll;
    if((api.canPlay||canJump)&&own.hand.length===2){var label=el('label','','uno-call');var check=document.createElement('input');check.type='checkbox';check.checked=shout;check.onchange=function(){shout=check.checked;};label.append(check,el('span','出牌时喊 UNO！'));controls.append(label);}
    if(!api.canPlay||v.phase==='finished')return;
    var choice=own.hand.find(function(c){return c.id===selected;});
    if(v.stage==='color'||choice&&choice.color==='k'){
      if(v.stage!=='color')controls.append(el('p','选择颜色并出牌','uno-hint'));
      var palette=el('div','','uno-palette');Object.keys(colors).forEach(function(color){var b=button(colors[color],function(){api.act(v.stage==='color'?'color':'play',v.stage==='color'?{color:color}:{card:selected,color:color,uno:shout});},'uno-swatch uno-'+color);palette.append(b);});controls.append(palette);
    }
    if(v.stage!=='play'&&v.stage!=='drawn')return;
    var actions=el('div','','uno-actions');
    if(v.stage==='drawn')actions.append(button('保留，结束回合',function(){api.act('pass',{});}));
    else actions.append(button('摸一张',function(){api.act('draw',{});}));
    var play=button('出牌',function(){api.act('play',{card:selected,uno:shout});},'aurai-button--primary');play.disabled=!choice||choice.color==='k';actions.append(play);controls.append(actions);
  }
  return {render:render,reset:reset};
})();
