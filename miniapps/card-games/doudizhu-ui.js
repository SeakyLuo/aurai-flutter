var CardUI=(function(){
  var selected=[],scroll=0,lastHand='';
  function reset(){selected=[];scroll=0;lastHand='';}
  function render(root,v,own,api){
    var old=root.querySelector('.ddz-hand');if(old)scroll=old.scrollLeft;
    var hand=own?own.hand:[],key=hand.join(',');if(key!==lastHand){selected=[];lastHand=key;}
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
    if(v.phase==='finished'){current.append(el('strong',v.result,'ddz-result'));var scores=el('div','','ddz-scores');v.players.forEach(function(p,i){scores.append(el('span',p.name+' '+(v.scores[i]>0?'+':'')+v.scores[i],''));});current.append(scores);}
    else if(v.stage==='bid'){current.append(el('strong','争当地主','ddz-result'));var bids=el('div','','ddz-bids');v.players.forEach(function(p,i){bids.append(el('span',p.name+' · '+(v.bids[i]===null?'待叫分':v.bids[i]?'叫 '+v.bids[i]+' 分':'不叫'),''));});current.append(bids);}
    else if(v.last){current.append(el('div',v.players[v.last.seat].name+' · '+Cards.names[v.last.type],'ddz-last-label'));var played=el('div','','ddz-played');v.last.cards.forEach(function(c){played.append(card(c,true));});current.append(played);var passes=v.table.map(function(t,i){return t&&t.text?v.players[i].name+' '+t.text:'';}).filter(Boolean);if(passes.length)current.append(el('div',passes.join(' · '),'ddz-last-label'));}
    else current.append(el('strong',own&&v.turn===own.seat?'由你领出':'等待领出','ddz-result'));
    desk.append(current);root.append(desk);
    if(!own)return;
    var caption=player(own.seat,'ddz-self');root.append(caption);
    var strip=el('div','','ddz-hand');hand.forEach(function(c){var button=el('button','','ddz-pick');button.type='button';button.append(card(c,false));button.classList.toggle('selected',selected.indexOf(c)>=0);button.disabled=!api.canPlay||v.stage!=='play';button.setAttribute('aria-label',Cards.labels[Cards.rank(c)]+(c<52?['梅花','方块','红桃','黑桃'][c%4]:''));button.setAttribute('aria-pressed',String(selected.indexOf(c)>=0));button.onclick=function(){var i=selected.indexOf(c);if(i>=0)selected.splice(i,1);else selected.push(c);render(root,v,own,api);};strip.append(button);});root.append(strip);strip.scrollLeft=scroll;
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
