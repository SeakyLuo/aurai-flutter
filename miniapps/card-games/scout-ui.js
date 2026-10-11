var CardUI=(function(){
  var stateKey='',anchor=null,end=null,orientation=false,recruiting=false,edge='left',flip=false,position=0,combo=false,scroll=0;
  function reset(){stateKey='';anchor=null;end=null;orientation=false;recruiting=false;edge='left';flip=false;position=0;combo=false;scroll=0;}
  function render(root,v,own,api){
    var old=root.querySelector('.scout-hand');if(old)scroll=old.scrollLeft;
    var key=v.game+':'+v.ply;
    if(key!==stateKey){reset();stateKey=key;}
    var el=api.el;root.replaceChildren();root.className='scout-root';
    function button(label,fn,disabled,primary){var b=el('button',label,'aurai-button'+(primary?' aurai-button--primary':''));b.type='button';b.disabled=disabled;b.onclick=fn;return b;}
    function card(c,selected){var node=el('span','','scout-card'+(selected?' selected':''));node.dataset.tone=String(c.top%3);node.append(el('b',String(c.top),'scout-number'),el('span','✦','scout-star'),el('small',String(c.bottom),'scout-back-number'));return node;}
    var desk=el('section','','scout-desk'),label=el('div','','scout-desk-label');
    label.append(el('span','SCOUT','scout-wordmark'),el('span','第 '+v.round+' / 3 轮'));desk.append(label);
    if(v.stage==='roundEnd'||v.phase==='finished'){
      desk.append(el('h2',v.phase==='finished'?v.result:'这一轮，谢幕！'));
      var board=el('div','','scout-scoreboard');
      v.players.forEach(function(p,i){var row=el('div','','scout-score');row.append(el('strong',p.name),el('span','本轮 '+(v.roundScores[i]>=0?'+':'')+v.roundScores[i]),el('b',String(v.scores[i])+' 分'));board.append(row);});desk.append(board);
    }else if(v.stage==='orient'){
      desk.append(el('h2','好戏，从选好方向开始'),el('p','每张牌有两个数字。整手翻转后，牌序也会反过来。','scout-subtle'));
    }else{
      desk.append(el('p',v.owner===null?'舞台已就绪':v.players[v.owner].name+'的演出','scout-subtle'));
      var active=el('div','','scout-active');v.active.forEach(function(c){active.append(card(c,false));});
      if(!v.active.length)active.append(el('span','自由演出 · 任意有效组合','scout-subtle'));desk.append(active);
      var group=Cards.combination(v.active);
      if(group)desk.append(el('div',group.count+' 张 · '+(group.count===1?'单张':group.type?'同数':'连续'),'scout-subtle'));
    }
    root.append(desk);
    if(!own){root.append(el('p','正在观战 · 手牌仅玩家本人可见','aurai-muted'));return;}
    var tally=el('div','','scout-tally');tally.append(el('span','总分 '+v.scores[own.seat]),el('span','赢牌 '+v.captured[own.seat]),el('span','招募奖励 '+v.tokens[own.seat]));root.append(tally);
    if(v.stage==='roundEnd'){
      root.append(button('开始下一轮',function(){api.act('nextRound',{});},!api.canPlay,true));return;
    }
    if(v.phase==='finished')return;
    var hand=orientation&&v.stage==='orient'?Cards.flipped(own.hand):own.hand;
    var change=null;
    if(recruiting){change=Cards.recruit(own.hand,v.active,{edge:edge,flip:flip,position:position});hand=change.hand;}
    var legal=Cards.shows(hand,recruiting?change.active:v.active);
    var start=anchor===null?0:Math.min(anchor,end===null?anchor:end),count=anchor===null?0:Math.abs((end===null?anchor:end)-anchor)+1;
    var valid=legal.some(function(m){return m.start===start&&m.count===count;});
    root.append(el('div',v.stage==='orient'?'选择手牌朝向':recruiting?'招募后的手牌预览':'你的手牌 · 顺序固定','scout-hand-label'));
    var strip=el('div','','scout-hand');
    hand.forEach(function(c,i){
      var b=button('',function(){if(anchor===null||end!==null){anchor=i;end=null;}else end=i;render(root,v,own,api);},!api.canPlay||v.stage!=='play'||recruiting&&!combo,false);
      b.className='scout-pick';b.append(card(c,!!count&&i>=start&&i<start+count));b.setAttribute('aria-label','第 '+(i+1)+' 张，'+c.top+'，背面 '+c.bottom);b.setAttribute('aria-pressed',String(!!count&&i>=start&&i<start+count));
      if(change&&c.id===change.card.id)b.classList.add('recruited');strip.append(b);
    });root.append(strip);strip.scrollLeft=scroll;
    if(v.stage==='orient'){
      var orient=el('div','','scout-actions');orient.append(button('翻转整手牌',function(){orientation=!orientation;render(root,v,own,api);},!api.canPlay,false),button('就用这面',function(){api.act('orient',{flip:orientation});},!api.canPlay,true));root.append(orient);return;
    }
    if(recruiting){
      var panel=el('div','','scout-recruit'),settings=el('div','','scout-actions');
      settings.append(button(edge==='left'?'取左端 ✓':'取左端',function(){edge='left';anchor=end=null;render(root,v,own,api);},!api.canPlay,false),button(edge==='right'?'取右端 ✓':'取右端',function(){edge='right';anchor=end=null;render(root,v,own,api);},!api.canPlay||v.active.length===1,false),button(flip?'已翻面 ✓':'翻面',function(){flip=!flip;anchor=end=null;render(root,v,own,api);},!api.canPlay,false));panel.append(settings);
      var insert=el('label','','aurai-field');insert.append(el('span','插入位置'));var select=el('select','');
      for(var i=0;i<=own.hand.length;i++){var option=el('option',i===0?'最左侧':i===own.hand.length?'最右侧':'第 '+i+' 张之后');option.value=String(i);select.append(option);}select.value=String(position);select.disabled=!api.canPlay;select.onchange=function(){position=Number(select.value);anchor=end=null;render(root,v,own,api);};insert.append(select);panel.append(insert);
      var choice=el('label','','scout-combo');var check=el('input','');check.type='checkbox';check.checked=combo;check.disabled=!api.canPlay||v.comboUsed[own.seat]||!legal.length;check.onchange=function(){combo=check.checked;anchor=end=null;render(root,v,own,api);};choice.append(check,el('span',v.comboUsed[own.seat]?'招募并演出 · 本轮已用':'招募并演出 · 每轮一次'));panel.append(choice);
      if(combo)panel.append(el('p','在预览手牌中选择相邻组合，再一起提交。','aurai-muted'));
      var actions=el('div','','scout-actions');actions.append(button('取消',function(){recruiting=false;anchor=end=null;render(root,v,own,api);},api.busy,false));
      if(combo)actions.append(button('提示',function(){var m=legal.slice().sort(function(a,b){return b.count-a.count;})[0];anchor=m.start;end=m.start+m.count-1;render(root,v,own,api);},!api.canPlay||!legal.length,false));
      actions.append(button(combo?'招募并演出':'确认招募',function(){api.act(combo?'scoutShow':'scout',{edge:edge,flip:flip,position:position,start:start,count:count});},!api.canPlay||combo&&!valid,true));panel.append(actions);root.append(panel);
    }else{
      root.append(el('p',count?'已选 '+count+' 张'+(valid?' · 可以演出':' · 请选择能压过桌面的组合'):'点击首尾两张，选择相邻组合；也可只选一张。','aurai-muted scout-hint'));
      var actions=el('div','','scout-actions');
      actions.append(button('招募',function(){recruiting=true;position=0;edge='left';flip=false;combo=false;anchor=end=null;render(root,v,own,api);},!api.canPlay||!v.active.length||v.owner===own.seat,false));
      actions.append(button('提示',function(){var m=legal.slice().sort(function(a,b){return b.count-a.count;})[0];anchor=m.start;end=m.start+m.count-1;render(root,v,own,api);},!api.canPlay||!legal.length,false));
      actions.append(button('演出',function(){api.act('show',{start:start,count:count});},!api.canPlay||!valid,true));root.append(actions);
    }
  }
  return {render:render,reset:reset};
})();
