var CardUI=(function(){
  var selected=null,revision='';function reset(){selected=null;revision='';}
  function render(root,v,own,api){var el=api.el,key=v.game+':'+v.ply;if(key!==revision){selected=null;revision=key;}root.replaceChildren();root.className='six-root';
    function button(text,fn,disabled,primary){var b=el('button',text,'aurai-button'+(primary?' aurai-button--primary':''));b.type='button';b.disabled=disabled;b.onclick=fn;return b;}
    function card(c){var box=el('span','','six-card');box.dataset.level=Cards.points(c);box.append(el('b',String(c)),el('small','罚 '+Cards.points(c)));return box;}
    root.append(el('div','第 '+v.round+' 轮 · '+v.trick+' / 10 次出牌','six-meta'));
    var scores=el('div','','six-scores');v.players.forEach(function(p,i){var box=el('div','','six-score');box.append(el('span',p.name),el('strong',v.scores[i]+' 分'),el('small',v.stage==='select'?(v.ready[i]?'已选好':'选牌中'):'本轮 +'+v.roundPoints[i]));scores.append(box);});root.append(scores);
    var choosing=v.stage==='choose';
    root.append(el('p',choosing?(v.players[v.pending.seat].name+'的 '+v.pending.card+' 比所有行尾都小，'+(own&&v.pending.seat===own.seat?'请选择收走一行':'正在选择收牌')):'每行最多五张，第六张会收走整行','six-hint'));
    var rows=el('div','','six-rows');v.rows.forEach(function(row,i){var line=el('div','','six-row'),label=el('span',String(i+1),'six-row-number'),strip=el('div','','six-row-cards');row.forEach(function(c){strip.append(card(c));});for(var n=row.length;n<5;n++)strip.append(el('span','','six-slot'));line.append(label,strip);
      if(choosing&&own&&v.pending.seat===own.seat)line.append(button('收取 · '+Cards.cost(row)+' 分',function(){api.act('take',{row:i});},!api.canPlay,false));
      else line.append(el('span',Cards.cost(row)+' 分','six-cost'));rows.append(line);});root.append(rows);
    if(v.revealed.length){var results=el('div','','six-revealed');v.revealed.forEach(function(p){var done=v.resolved.find(function(r){return r.seat===p.seat;}),item=el('div','','six-reveal');item.append(el('small',v.players[p.seat].name),card(p.card),el('small',done?(done.points?'罚 '+done.points+' 分':'第 '+(done.row+1)+' 行'):'待放置'));results.append(item);});root.append(results);}
    if(v.phase==='finished'){root.append(el('strong',v.result,'six-result'));showRemainingHands(root,v,card);return;}
    if(!own){root.append(el('p','正在观战','aurai-muted'));return;}
    if(v.stage==='trickEnd'||v.stage==='roundEnd'){root.append(button(v.stage==='trickEnd'?'继续出牌':'开始下一轮',function(){api.act(v.stage==='trickEnd'?'nextTrick':'nextRound',{});},!api.canPlay,true));return;}
    if(v.stage==='select'){
      var hand=el('div','','six-hand');own.hand.forEach(function(c){var b=button('',function(){selected=c;render(root,v,own,api);},!api.canPlay,false);b.className='six-pick'+(c===selected?' selected':'');b.append(card(c));b.setAttribute('aria-label',c+' 号，'+Cards.points(c)+' 分');b.setAttribute('aria-pressed',String(c===selected));hand.append(b);});root.append(hand);
      root.append(button(own.chosen!==null?'已选好，等待揭晓':selected===null?'选一张牌':'确认暗出 '+selected,function(){api.act('commit',{card:selected});},!api.canPlay||selected===null,true));
    }
  }
  return {render:render,reset:reset};
})();
