var CardUI=(function(){
  var selected=[],scroll=0,lastHand='',handObserver=null,handFrame=0;
  function reset(){selected=[];scroll=0;lastHand='';}
  function render(root,v,own,api){
    var old=root.querySelector('.ddz-hand');if(old)scroll=old.scrollLeft;
    if(handObserver)handObserver.disconnect();
    cancelAnimationFrame(handFrame);
    var hand=own?own.hand.slice().reverse():[],key=hand.join(',');if(key!==lastHand){selected=[];lastHand=key;}
    root.replaceChildren();root.className='ddz-root';
    function el(tag,text,cls){return api.el(tag,text,cls);}
    function card(id,small){var r=Cards.rank(id),suit=id>=52?'★':['♣','♦','♥','♠'][id%4],node=el('span','',small?'ddz-card ddz-mini':'ddz-card');if(id%4===1||id%4===2||id===53)node.classList.add('ddz-red');node.append(el('b',Cards.labels[r],'ddz-rank'),el('span',suit,'ddz-suit'));return node;}
    var desk=el('section','','ddz-desk');
    function player(seat,side){var p=v.players[seat],box=el('div','', 'ddz-player '+side+(v.phase==='playing'&&v.turn===seat?' active':''));var badge=el('span',seat===v.landlord?'地':v.landlord===null?'候':'农','ddz-avatar');box.append(badge,el('strong',p.name,'ddz-player-name'),el('span',v.counts[seat]+' 张','ddz-count'));box.setAttribute('aria-label',p.name+'，'+v.counts[seat]+' 张'+(v.turn===seat?'，正在行动':''));return box;}
    var local=own?own.seat:0;
    desk.append(player((local+2)%3,'ddz-left'),player((local+1)%3,'ddz-right'));
    var top=el('div','','ddz-meta');top.append(el('span',v.stage==='bid'?'叫地主':'底分 '+v.bid+' · '+v.multiplier+' 倍',''));
    var bottom=el('div','','ddz-bottom');if(v.bottom.length)v.bottom.forEach(function(c){bottom.append(card(c,true));});else for(var i=0;i<3;i++)bottom.append(el('span','✦','ddz-back'));top.append(bottom);desk.append(top);
    var current=el('div','','ddz-current');
    if(v.stage==='bid'){current.append(el('strong','争当地主','ddz-result'));var bids=el('div','','ddz-bids');v.players.forEach(function(p,i){bids.append(el('span',p.name+' · '+(v.bids[i]===null?'待叫分':v.bids[i]?'叫 '+v.bids[i]+' 分':'不叫'),''));});current.append(bids);}
    else if(v.last){
      current.classList.add('ddz-trick');
      [ (local+2)%3,(local+1)%3,local ].forEach(function(seat,index){
        var t=v.table[seat],zone=el('div','','ddz-seat-play ddz-play-'+['left','right','self'][index]);
        if(t){zone.append(el('div',v.players[seat].name+(t.type?' · '+Cards.names[t.type]:''),'ddz-last-label'));
          if(t.cards){var played=el('div','','ddz-played');t.cards.slice().reverse().forEach(function(c){played.append(card(c,true));});zone.append(played);}
          else zone.append(el('strong',t.text,'ddz-pass'));
          if(v.last.seat===seat)zone.classList.add('latest');
        }current.append(zone);
      });
    }
    else current.append(el('strong',own&&v.turn===own.seat?'由你领出':'等待领出','ddz-result'));
    desk.append(current);root.append(desk);
    if(v.phase==='finished'){
      var settlement=el('div','','ddz-settlement');settlement.append(el('strong',v.result,'ddz-result'));
      var scores=el('div','','ddz-scores');v.players.forEach(function(p,i){scores.append(el('span',p.name+' '+(v.scores[i]>0?'+':'')+v.scores[i],''));});settlement.append(scores);desk.append(settlement);
      var remaining=el('section','','ddz-remaining');remaining.append(el('strong','剩余手牌','ddz-last-label'));
      v.players.forEach(function(p,i){if(own&&i===own.seat)return;var row=el('div','','ddz-revealed-hand');row.append(el('span',p.name+' · '+(i===v.landlord?'地主':'农民'),'ddz-last-label'));var cards=el('div','','ddz-played');v.hands[i].slice().reverse().forEach(function(c){cards.append(card(c,true));});if(!v.hands[i].length)cards.append(el('span','已出完','ddz-last-label'));row.append(cards);remaining.append(row);});root.append(remaining);
    }
    if(!own)return;
    var caption=player(own.seat,'ddz-self');root.append(caption);
    var strip=el('div','','ddz-hand');hand.forEach(function(c){var button=el('button','','ddz-pick');button.type='button';button.append(card(c,false));button.classList.toggle('selected',selected.indexOf(c)>=0);button.disabled=!api.canPlay||v.stage!=='play'||v.phase==='finished';button.setAttribute('aria-label',Cards.labels[Cards.rank(c)]+(c<52?['梅花','方块','红桃','黑桃'][c%4]:''));button.setAttribute('aria-pressed',String(selected.indexOf(c)>=0));button.onclick=function(){var i=selected.indexOf(c);if(i>=0)selected.splice(i,1);else selected.push(c);render(root,v,own,api);};strip.append(button);});root.append(strip);strip.scrollLeft=scroll;
    var drag=null,buttons=Array.from(strip.children);
    // Tap selection belongs to click alone; capturing on down redirects clicks away from the card.
    strip.onpointerdown=function(e){var b=e.target.closest('.ddz-pick');if(!b||b.disabled||e.button!==0)return;var at=buttons.indexOf(b);drag={id:e.pointerId,start:at,x:e.clientX,before:selected.slice(),add:selected.indexOf(hand[at])<0,moved:false};};
    strip.onpointermove=function(e){if(!drag||drag.id!==e.pointerId)return;if(Math.abs(e.clientX-drag.x)<7&&!drag.moved)return;if(!drag.moved){drag.moved=true;strip.setPointerCapture(e.pointerId);}
      var bounds=strip.getBoundingClientRect();if(e.clientX>bounds.right-22)strip.scrollLeft+=18;else if(e.clientX<bounds.left+22)strip.scrollLeft-=18;
      var at=0;buttons.forEach(function(b,i){if(e.clientX>=b.getBoundingClientRect().left)at=i;});
      var range=hand.slice(Math.min(at,drag.start),Math.max(at,drag.start)+1);selected=drag.add?Array.from(new Set(drag.before.concat(range))):drag.before.filter(function(c){return range.indexOf(c)<0;});
      buttons.forEach(function(b,i){var active=selected.indexOf(hand[i])>=0;b.classList.toggle('selected',active);b.setAttribute('aria-pressed',String(active));});
    };
    strip.onpointerup=function(e){if(!drag||drag.id!==e.pointerId)return;var moved=drag.moved;drag=null;if(!moved)return;strip.releasePointerCapture(e.pointerId);e.preventDefault();render(root,v,own,api);};
    strip.onpointercancel=function(){if(drag){selected=drag.before;drag=null;render(root,v,own,api);}};
    var slider=el('input','','ddz-hand-scroll');slider.type='range';slider.min=0;slider.max=100;slider.setAttribute('aria-label','左右查看手牌');
    slider.oninput=function(){strip.scrollLeft=Number(slider.value)/100*(strip.scrollWidth-strip.clientWidth);};
    // Keep the slider's grid track stable; hiding it changed the observed hand layout.
    function track(){var max=strip.scrollWidth-strip.clientWidth;slider.style.visibility=max>1?'visible':'hidden';slider.disabled=max<=1;slider.setAttribute('aria-hidden',String(max<=1));slider.value=max>0?String(strip.scrollLeft/max*100):'0';}
    function scheduleTrack(){cancelAnimationFrame(handFrame);handFrame=requestAnimationFrame(track);}
    strip.onscroll=scheduleTrack;root.append(slider);handObserver=new ResizeObserver(scheduleTrack);handObserver.observe(strip);
    if(v.phase==='finished')return;
    var controls=el('div','','ddz-controls');
    function button(text,action,data,disabled,primary){var b=el('button',text,primary?'ddz-action primary':'ddz-action');b.type='button';b.disabled=!api.canPlay||disabled;b.onclick=function(){api.act(action,data);};controls.append(b);return b;}
    if(v.stage==='bid'){button('不叫','bid',{score:0},false,false);for(var score=v.bid+1;score<=3;score++)button(score+' 分','bid',{score:score},false,score===3);}
    else {
      button('不出','pass',{},!v.last,false);
      var hint=button('提示','play',{},!own.legalMoves.length,false);hint.onclick=function(){var at=own.legalMoves.findIndex(function(m){return m.cards.join(',')===selected.join(',');});selected=own.legalMoves[(at+1)%own.legalMoves.length].cards.slice();render(root,v,own,api);};
      var valid=selected.length&&own.legalMoves.some(function(m){return m.cards.length===selected.length&&m.cards.map(Cards.rank).sort().join(',')===selected.map(Cards.rank).sort().join(',');});button('出牌'+(selected.length?' '+selected.length+' 张':''),'play',{cards:selected.slice()},!valid,true);
    }
    root.append(controls);
  }
  return {render:render,reset:reset};
})();
