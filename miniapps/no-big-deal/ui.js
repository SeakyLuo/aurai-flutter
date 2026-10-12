const $=id=>document.getElementById(id);
const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==null)n.textContent=text;if(cls)n.className=cls;return n;};
const R=OfficeRules,B=OfficeBoard,W=OfficeWork,F=OfficeFeedback;
function writeText(id,value){const n=$(id),text=String(value);if(n.textContent!==text)n.textContent=text;}
const sectionViews=new Map();let pageGeometry='';
function renderSection(key,value,paint){const view=JSON.stringify(value);if(sectionViews.get(key)===view)return;sectionViews.set(key,view);paint();}
function requestPageResize(){const page=$('officeGame').getBoundingClientRect(),board=$('board').getBoundingClientRect();const geometry=[page.width,page.height,board.x,board.y,board.width,board.height].join(',');if(geometry!==pageGeometry){pageGeometry=geometry;AuraiHTML.requestResize();}}
let soundEnabled=AuraiHTML.state?.soundEnabled===true;F.setEnabled(soundEnabled);
const art={paper:'{{PAPER}}',folder:'{{FOLDER}}',box:'{{BOX}}',coffee:'{{ART_COFFEE}}',sleeve:'{{ART_SLEEVE}}',cage:'{{ART_CAGE}}',lock:'{{ART_LOCK}}'};
let game=AuraiHTML.state?.version===7?AuraiHTML.state.game:null,busy=false,path=[],drop=null,drag=false,item=null,panel='demands',screen='desk',toastTimer=0,pointer=null,groupDrag=false,keyboardSelection=false,inspectOpen=false;
let selectionGame=null,selectionOptions=null;
function connectable(){
  if(!path.length||groupDrag||item!==null||busy)return [];
  if(selectionGame!==game){selectionGame=game;selectionOptions=OfficeMerge.selector(game);}
  return selectionOptions.options(path);
}
function toast(text){$('officeToast').textContent=text;$('officeToast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>{$('officeToast').hidden=true;},5000);}
function button(text,action,cls='aurai-button',disabled=false){const b=el('button',text,cls);b.type='button';b.disabled=disabled;b.onclick=()=>{if(!busy)action();};return b;}
function fileArt(o){return o.value<=16?art.paper:o.value<=512?art.folder:art.box;}
function hiddenValue(o,i){return o.polluted||(R.fatigue(game,'hidden')&&R.fatigue(game,'hidden').mask.includes(i));}
function fogged(i){return game.fatigues.some(f=>f.type==='fog'&&f.mask.includes(i));}
function statusTags(o){
  return [...(o.wet?['湿 '+o.wet]:[]),...(o.sticky?['黏 '+o.sticky]:[]),...(o.charge?['电 '+o.charge]:[]),
    ...(o.burning?['燃 '+o.burning]:[]),...(o.frozen?['冰 '+o.frozen]:[]),...(o.note?['签']:[]),
    ...(o.kind==='urgent'?['急 '+o.urgent]:[]),...(o.kind==='bomb'?['剩 '+o.timer]:[]),
    ...(o.cancelled?['撤销']:[]),...(o.attach.length?['套 '+o.attach.length]:[]),...(o.kind==='messy'?['整 '+o.messy]:[])];
}
const boardViews=[];
function renderBoard(){
  const cells=game.board.map((o,i)=>{
    const z=game.zones[i],pending=(game.pending!==null&&!game.pending.startsWith('attach@')&&!game.pending.startsWith('collect@')&&game.pending.endsWith('@'+i))||game.pending==='collect@'+o?.id||(game.pending!==null&&game.pending.startsWith('attach@')&&Number(game.pending.split('@')[2])===i);
    const view=JSON.stringify([o,z,game.props[i],game.preview?.cell===i&&!R.fatigue(game,'preview'),fogged(i),o?hiddenValue(o,i):false,game.barriers.filter(([a])=>a===i),pending,game.status]);
    if(boardViews[i]?.view===view)return boardViews[i].cell;
    const cell=el('button',null,'office-cell');cell.type='button';cell.dataset.cell=i;
    if(!fogged(i))z.types.forEach(t=>cell.classList.add('zone-'+t));
    if(fogged(i)){
      cell.append(el('span','雾','fog-cover'));cell.setAttribute('aria-label',`${Math.floor(i/4)+1}行${i%4+1}列，迷雾遮挡`);
    }else if(o){
      cell.classList.toggle('polluted',o.polluted);
      cell.classList.toggle('wet',o.wet>0);cell.classList.toggle('sticky',o.sticky>0);cell.classList.toggle('burning',o.burning>0);
      if(R.isFile(o)){
        const img=el('img',null,'file-art');img.src=fileArt(o);img.alt='';cell.append(img);
        cell.append(el('strong',hiddenValue(o,i)?['轻','中','重','超重'][R.tier(o)]:String(o.value),'file-number'+(o.value>=1000?' small':'')));
      }else{
        const signs={stone:'◆',rubble:'⋰',bomb:'●',magnet:'∩',machine:'⚙',parcel:'▱',prop:'◇'};
        cell.append(el('span',signs[o.kind],'kind-icon'));
      }
      const tags=el('div',null,'cell-tags');
      if(o.polluted)tags.append(el('span','污染'));
      else {if(R.kinds[o.kind][1])tags.append(el('span',R.kinds[o.kind][1]));for(const tag of statusTags(o).slice(0,3))tags.append(el('span',tag));}
      cell.append(tags);
      const readable=hiddenValue(o,i)?'重量'+R.weight(o):o.value+'份';
      cell.setAttribute('aria-label',`${Math.floor(i/4)+1}行${i%4+1}列，`+(o.polluted?'受污染的物品，重量'+R.weight(o):`${R.kinds[o.kind][0]}，${readable}，${statusTags(o).join('，')}`));
    }else if(game.preview?.cell===i&&!R.fatigue(game,'preview')){
      const img=el('img',null,'preview-file');img.src=art.paper;img.alt='';cell.append(img);
      cell.setAttribute('aria-label','空格，下一份文件预告');
    }else cell.setAttribute('aria-label',`${Math.floor(i/4)+1}行${i%4+1}列，空格`);
    if(!fogged(i)&&game.props[i]==='tea')cell.append(el('span','杯','tea-tag'));
    if(!fogged(i)&&z.types.length){cell.append(el('span',z.types.map(t=>R.zones[t][1]).join('·'),'zone-tag'));cell.setAttribute('aria-label',cell.getAttribute('aria-label')+'，'+z.types.map(t=>R.zones[t][0]+'区').join('、'));}
    for(const [a,b] of game.barriers){if(a===i&&b===i+1)cell.classList.add('barrier-right');if(a===i&&b===i+4)cell.classList.add('barrier-bottom');}
    cell.classList.toggle('foggy',fogged(i));
    cell.classList.toggle('pending',(game.pending!==null&&!game.pending.startsWith('attach@')&&!game.pending.startsWith('collect@')&&game.pending.endsWith('@'+i))||game.pending==='collect@'+o?.id || (game.pending!==null&&game.pending.startsWith('attach@')&&Number(game.pending.split('@')[2])===i));
    cell.disabled=game.status!=='playing';
    cell.ondblclick=()=>{if(busy||!game.board[i])return;path=[i];drop=null;inspectOpen=true;paintSelection();inspect();requestPageResize();};
    cell.onkeydown=e=>{
      if(e.key==='Escape'){e.preventDefault();cancelDrag();}
      if(e.key==='Enter'||e.key===' '){e.preventDefault();keyboardSelection=true;if(e.ctrlKey)void commitSelection();else tapCell(i);}
    };
    boardViews[i]={view,cell};return cell;
  });
  for(let i=0;i<cells.length;i++){const old=$('board').children[i];if(!old)$('board').append(cells[i]);else if(old!==cells[i])$('board').replaceChild(cells[i],old);}
  paintSelection();
}
function paintSelection(){
  const selectedCells=groupDrag&&path.length===1?B.linked(game,path[0]):path;
  const choosing=path.length>0&&!groupDrag&&item===null&&!busy&&R.isFile(game.board[path[0]]),choices=connectable();
  for(const n of $('board').children){
    const i=Number(n.dataset.cell),selected=selectedCells.includes(i),candidate=choosing&&!selected&&R.isFile(game.board[i]);
    n.classList.toggle('selected',selected);n.classList.toggle('drop-target',drop===i);
    n.classList.toggle('connectable',candidate&&choices.includes(i));n.classList.toggle('unconnectable',candidate&&!choices.includes(i));
    n.setAttribute('aria-pressed',String(selected));
    if(candidate)n.setAttribute('aria-description',choices.includes(i)?'可继续连接':'当前无法连接');else n.removeAttribute('aria-description');
  }
  const merging=choosing&&path.length>1;
  $('mergePreview').hidden=!merging;
  if(merging){
    const plan=OfficeMerge.preview(game,path),concealed=path.some(i=>fogged(i)||hiddenValue(game.board[i],i));
    $('mergePreview').classList.toggle('ready',plan.ready);
    writeText('mergePreview',plan.ready?(concealed?`${path.length} 张 · 松手合并`:`${path.length} 张 → ${plan.value} 份 · +${plan.gain}`):`${path.length} 张 · 待配齐`);
  }
  const points=[...path,...(drop!==null&&!path.includes(drop)?[drop]:[])];
  $('connectLine').replaceChildren();
  if(points.length>1){const line=document.createElementNS('http://www.w3.org/2000/svg','polyline');line.setAttribute('points',points.map(i=>`${(i%4+.5)*100},${(Math.floor(i/4)+.5)*100}`).join(' '));$('connectLine').append(line);}
  const selected=path.length>0;
  const pendingMerge=selected&&(game?.pending===path.map(i=>game.board[i].id).sort((a,b)=>a-b).join(',')+'@'+(drop===null?path[path.length-1]:drop)||game.pending==='linked@'+B.linked(game,path[0]).map(i=>game.board[i].id).join(',')+'@'+drop);
  const pendingAttach=item!==null&&game.pending?.startsWith('attach@'+game.items[item].key+'@');
  $('cancelSelection').hidden=!selected&&item===null;
  const states=game.fatigues.map(f=>R.fatigues[f.type]);$('statusContent').textContent=states.join(' · ');$('statusIcon').hidden=!states.length;$('statusIcon').textContent=states.length?'疲':'';
  $('instruction').textContent=pendingAttach?'审批中，再次点击金色框里的物品确认附着':item!==null?(game.items[item].polluted?'已选受污染的道具，点击空格放回桌面，用清水洗净':game.items[item].key==='magnet'?'点击桌面空格放置磁铁，或在文件柜选择桌外位置':`已选${R.items[game.items[item].key].name}，点击桌面目标使用`):
    pendingMerge?'审批区：再拖动相同文件到这里，完成第二次合并。':groupDrag?'整组移动：选择落点，分别合并同值文件、收集道具或附着。':
    path.length>1?(OfficeMerge.complete(path.map(i=>game.board[i]))?`已连接 ${path.length} 张，松手合并`:'尚未配齐，继续连接亮起的文件，或沿线退回'):
    drop!==null&&R.collectible(game.board[drop])?'松手收集或附着目标道具':
    selected?'连接亮起的文件，配齐后松手合并；拖到空格可移动':OfficeCampaign.hint(game);
}
function inspect(){
  const i=path.length===1?path[0]:null,o=i!==null?game.board[i]:null;
  $('inspect').hidden=!inspectOpen||!o||game.status!=='playing'||item!==null;
  if(!o)return;
  if(fogged(i)){
    $('inspectTitle').textContent='迷雾中的物品';$('inspectText').textContent='这里暂时看不清，疲劳消退后恢复可见。';$('inspectActions').replaceChildren();return;
  }
  $('inspectTitle').textContent=R.kinds[o.kind][0]+(R.isFile(o)&&!hiddenValue(o,i)?' · '+o.value+' 份':'');
  const z=game.zones[i];
  const details=['重量 '+R.weight(o),...statusTags(o),...o.attach.map(a=>R.items[a].name),...z.types.map(t=>R.zones[t][0]+'区')];
  if(game.props[i]==='tea')details.push('茶杯：移动会泼水');
  if(z.types.includes('danger'))details.push('剩余稳定 '+z.collapse+'，每步衰减，移动经过会加速');
  if(z.types.some(t=>['water','pollution'].includes(t)))details.push('剩余水量 '+z.water);
  if(z.types.includes('glue'))details.push('胶水可用 '+z.glue+' 次');
  if(o.kind==='magnet')details.push('朝向 '+['上','右','下','左'][o.direction]);
  const delayed=game.delayed.filter(a=>a.id===o.id);for(const change of delayed)details.push(change.turns+' 步后变为 '+change.value+' 份');
  if(o.sticky&&B.linked(game,i).length>1)details.push('黏连体共 '+B.linked(game,i).length+' 件，可整组移动并分别合并');
  if(o.kind==='parcel')details.push(o.opened?'外卖袋已打开，可以收集':'先挪到空格，再拆开外卖袋');
  if(o.kind==='prop')details.push(R.items[o.item].name,R.rarities[R.itemRarity[o.item]]);
  if(o.kind==='stone'&&o.brittle)details.push('脆化剩余 '+o.brittle+' 格，碰撞消耗 1，清水消耗 2');
  $('inspectText').textContent=details.join(' · ');
  const actions=[];
  if(o.sticky&&B.linked(game,i).length>1)actions.push(button(groupDrag?'改为连线选择':'整组移动',()=>{groupDrag=!groupDrag;drop=null;render();}));
  if(o.polluted){$('inspectTitle').textContent=o.bossDelivery?'老板的脏道具':'受污染的物品';$('inspectText').textContent=o.bossDelivery?'用清水洗净后会自动送回老板，恢复 1 点忍耐度。':'重量 '+R.weight(o)+' · 特殊效果暂停，移到清水区或使用清水瓶洗净。';}
  if(['prop','parcel','magnet'].includes(o.kind)&&!o.bossDelivery)actions.push(button(game.pending==='collect@'+o.id?'确认收集':'收进文件柜',async()=>{
    const result=await transact(s=>Office.collect(s,i));if(result.approval)toast('审批区：再点一次确认收集');else clearSelection();render();
  },'aurai-button',o.kind==='parcel'&&!o.opened));
  if(o.kind==='magnet'&&!o.polluted)actions.push(button('转动朝向',()=>transact(s=>{s.board[i].direction=(s.board[i].direction+1)%4;})));
  if(o.attach.includes('seal'))actions.push(button('撕下封条',()=>transact(s=>{s.board[i].attach=s.board[i].attach.filter(a=>a!=='seal');})));
  $('inspectActions').replaceChildren(...actions);
}
function renderDemands(){
  $('demandCount').textContent=game.demands.length;$('demands').replaceChildren();
  for(const d of game.demands){
    const row=el('details',null,'demand-row'),summary=el('summary'),clock=el('img',null,'demand-clock'),title=el('strong',d.title);
    clock.src='{{ART_CLOCK}}';clock.alt=d.category==='urgent'?'紧急需求':'工作需求';summary.append(clock,title);
    if(d.status==='offered')summary.append(el('span','待接受','demand-offer'));
    const progress=d.status==='active'?Math.min(d.target,game.stats[d.metric]-d.baseline):0;
    const meter=el('div',null,'demand-meter'),track=el('div',null,'demand-progress'),fill=el('div');fill.style.width=progress/d.target*100+'%';track.append(fill);meter.append(track,el('span',progress+'/'+d.target,'demand-count'));summary.append(meter);
    const detail=el('div',null,'demand-information');
    detail.append(el('strong',d.title+(d.category==='chain'?' · 第 '+(d.stage+1)+' 段':'')),el('p',(d.status==='active'?'剩余':'接受后')+' '+d.turns+' 步 · '+(d.category==='favor'?'奖励完成后揭晓':Math.round(d.reward*(game.phase===2?1.3:1)*(OfficeWelfare.active(game,'commission')?1.25:1))+' 金币')));
    detail.append(el('p',d.category==='favor'?'逾期无惩罚':{patience:'逾期扣 10 忍耐度',event:'逾期触发桌面意外',phase:'逾期疲劳至本阶段结束',next:'逾期疲劳至下阶段结束',day:'逾期疲劳至今日结束'}[d.consequence]));
    if(d.status==='offered'){const supply=W.supplyDescription(game,d);if(supply)detail.append(el('p',supply));detail.append(button(d.category==='chain'&&d.stage>0?'接受第 '+(d.stage+1)+' 段':'接受需求',()=>transact(s=>W.accept(s,d.id)),'aurai-button',game.status!=='playing'));}
    if(d.category==='chain'&&d.stage<2)detail.append(el('p','后续：'+d.plan.slice(d.stage+1).map((part,index)=>'第 '+(d.stage+index+2)+' 段 '+part.title+' '+part.target).join(' → ')));
    row.append(summary,detail);$('demands').append(row);
  }
}
function renderCabinet(){
  $('itemCount').textContent=game.items.length+'/'+R.itemLimit(game);$('cabinet').replaceChildren();
  $('itemTray').replaceChildren();
  const grid=el('div',null,'office-items');
  game.items.forEach((entry,index)=>{
    const info=R.items[entry.key],b=button(entry.polluted?'受污染的道具':(entry.spoiled?'变质 · ':'')+info.name,()=>{
      if(entry.polluted){item=index;path=[];drop=null;panel='cabinet';render();$('board').scrollIntoView({block:'nearest',behavior:'smooth'});return;}
      if(info.target==='passive'){toast(info.description);return;}
      if(info.target==='instant'){void transact(s=>W.use(s,index,0));return;}
      item=index;path=[];drop=null;panel='cabinet';render();if(entry.key!=='magnet')$('board').scrollIntoView({block:'nearest',behavior:'smooth'});
    },item===index?'active':'',game.status!=='playing');
    const label=el('span',b.textContent);b.textContent='';const imageKey={coffee:'coffee',sleeve:'sleeve',cage:'cage'}[entry.key];if(imageKey){const image=el('img',null);image.src=art[imageKey];image.alt='';b.append(image);}b.append(label);
    b.title=info.name+'：'+info.description;
    b.append(el('small',entry.polluted?'放回桌面清洗':entry.spoiled?{water:'使用后产生污水',strongGlue:'仅普通胶效果',coffee:'消除一种疲劳，下次合并产生疲劳',snack:'恢复 5 忍耐度',hamburger:'下两份为 1，额外留下临时文件',energy:'保护一次行动，结束后获得疲劳'}[entry.key]:entry.rental==='phase'?'本阶段租用':entry.rental==='day'?'今日租用':R.rarities[R.itemRarity[entry.key]]+(info.target==='passive'?' · 持有生效':' · 点击使用')));grid.append(b);
  });
  const limit=R.itemLimit(game);for(let index=game.items.length;index<Math.max(12,limit);index++){const slot=el('div',null,'tray-empty');if(index>=limit){const lock=el('img',null);lock.src=art.lock;lock.alt='未解锁';slot.append(lock);}else slot.setAttribute('aria-label','空道具位');grid.append(slot);}
  $('itemTray').replaceChildren(...grid.childNodes);
  if(game.pendingItems.length){
    $('cabinet').append(el('strong','待领取'),el('p','使用或放置道具，留出位置后即可收下。'));
    for(const [index,entry] of game.pendingItems.entries())$('cabinet').append(button('收下 '+R.items[entry.key].name,()=>transact(s=>W.claimItem(s,index)),'aurai-button',game.items.length>=R.itemLimit(game)||game.status!=='playing'));
  }
  if(game.welfare.length)$('cabinet').append(el('strong','办公福利'));
  for(const w of game.welfare){const info=OfficeWelfare.definitions[w.key];$('cabinet').append(el('strong',info.name),el('p',info.description+OfficeWelfare.progress(w)+(w.rental==='phase'?' · 本阶段':w.rental==='day'?' · 今日':' · 本局')));}
  $('cabinet').append(el('p',item!==null?(game.items[item].polluted?'受污染道具无法使用。点击空格放回桌面，再用清水洗净；清洗后重新收集。':game.items[item].spoiled?{water:'变质清水会铺成污水，污染文件。',strongGlue:'变质强力胶仅有普通胶效果，黏着 5 步。'}[game.items[item].key]:R.items[game.items[item].key].description):'点击道具后选择桌面目标。最多同时持有 '+R.itemLimit(game)+' 件。','item-tip'));
  if(item!==null&&game.items[item].key==='magnet'&&!game.items[item].polluted){
    const outside=el('div',null,'office-items');$('cabinet').append(el('p','也可以放在桌外，磁铁朝向桌内：'));
    for(let side=0;side<4;side++)for(let lane=0;lane<4;lane++){
      outside.append(button(['上','右','下','左'][side]+'侧第 '+(lane+1)+(side%2?' 行':' 列'),async()=>{
        const index=item;await transact(s=>W.outsideMagnet(s,index,side,lane));item=null;render();
      },'',game.outsideMagnets.some(m=>m.side===side&&m.lane===lane)));
    }
    $('cabinet').append(outside);
  }
  if(game.outsideMagnets.length){
    $('cabinet').append(el('strong','桌外磁铁'));
    game.outsideMagnets.forEach((m,index)=>$('cabinet').append(button(['上','右','下','左'][m.side]+'侧第 '+(m.lane+1)+(m.side%2?' 行':' 列')+' · 收回',()=>transact(s=>W.collectOutside(s,index)),'',game.items.length>=R.itemLimit(game)||game.status!=='playing')));
  }
}
function renderShop(){
  const closed=game.shopBlocked||!game.shopUnlocked||OfficeWelfare.active(game,'closed');
  $('shopNote').textContent=closed?(OfficeWelfare.active(game,'closed')?'封闭开发期间不能前往后勤部。':!game.shopUnlocked?'完成人情需求后开放，第二天上午结束后也会开放。':'后勤部本阶段暂停营业。'):'白天与夜晚货品不同；持续道具可购买或租用。';
  $('stock').replaceChildren();$('stock').hidden=closed;$('deck').parentElement.hidden=closed;
  if(closed)return;
  game.stock.forEach((entry,index)=>{
    const welfare=entry.kind==='welfare',info=welfare?OfficeWelfare.definitions[entry.key]:R.items[entry.key];
    const card=el('div',null,'stock-card');card.append(el('strong',info.name),el('p',info.description));
    const owned=welfare&&OfficeWelfare.active(game,entry.key),sold=entry.sold||owned||game.status!=='playing',price=W.price(game,entry);
    card.append(button(entry.sold?'已售出':owned?'持有中':price+' 金币 · 购买',()=>transact(s=>W.buy(s,index)),'aurai-button',sold||game.coins<price||(!welfare&&game.items.length>=R.itemLimit(game))));
    if(welfare&&!info.instant){
      const row=el('div',null,'rental-row');
      for(const [kind,label] of [['phase','租本阶段'],['day','租今日']]){const cost=W.price(game,entry,kind);row.append(button(label+' '+cost,()=>transact(s=>W.buy(s,index,kind)),'',sold||game.coins<cost));}
      card.append(row);
    }
    $('stock').append(card);
  });
  const price=OfficeWelfare.deckPrice(game,'upgrade'),removePrice=OfficeWelfare.deckPrice(game,'remove');
  $('deck').replaceChildren(...game.deck.map((entry,index)=>{
    const details=[...statusTags(entry).filter(tag=>!tag.startsWith('套 ')),...entry.attach.map(key=>R.items[key].name)];
    const row=el('div',null,'deck-card');row.append(el('span',entry.value+' 份'+R.kinds[entry.kind][0]+(details.length?' · '+details.join(' · '):'')),button('升级 · '+price,()=>transact(s=>W.editDeck(s,'upgrade',index)),'',game.coins<price||entry.value>=1024||game.status!=='playing'),button(game.freeRemovals?'免费移除 · 剩 '+game.freeRemovals+' 次':'移除 · '+removePrice,()=>transact(s=>W.editDeck(s,'remove',index)),'',game.coins<removePrice||game.deck.length===1||game.status!=='playing'));return row;
  }));
  $('addCard').textContent='增加一张 4 份文件 · '+price+' 金币';$('addCard').disabled=game.coins<price||game.status!=='playing';
}
function renderResult(){
  const ended=game.status!=='playing';$('stageResult').hidden=!ended;
  if(!ended)return;
  $('resultEyebrow').textContent=`${game.day}日${R.phases[game.phase]}本局目标`;
  $('resultTitle').textContent=game.status==='won'?'两天工作，顺利收工':game.status==='lost'?'问题不大，你已经做得很好了。':game.summary.success?'这一阶段，整理好了':'这个阶段结束了';
  $('resultText').textContent=game.status==='won'?'席奇留下一张便签：干得不错，这是给你的奖励。选择的通关福利将带到下一次上班。':game.status==='lost'?'席奇：如果不是'+(game.reason==='sealed'?'封条和桌洞占满了桌面':game.cleanings?'保洁已经收拾过这张桌子':game.moves===0?'这阶段的文件没能按时整理完':'这些没处理完的工作耗尽了耐心')+'的话，这摊事本来还能再拖一会儿。下次注意，你去吧。':
    game.summary.success?'提前完成目标。下一阶段继续使用当前桌面。':'整理次数耗尽，忍耐度扣除 50。下一阶段还有机会。';
  $('phaseFeedback').replaceChildren(el('span','干燥文件 '+game.phaseStats.dry),el('span','黏着文件 '+game.phaseStats.sticky));
  $('rewardChoices').replaceChildren();
  $('rewardChoices').classList.toggle('inheritance-choices',game.reward?.kind==='inheritance');
  if(game.reward?.kind==='inheritance'){
    $('rewardChoices').append(el('strong','选一件道具，带到下一次上班','reward-heading'));
    for(const [index,entry] of game.reward.choices.entries()){
      const info=R.items[entry.key],card=el('div',null,'stock-card');
      card.append(el('strong',info.name),el('p',[...(entry.polluted?['保留污染状态，下局仍需先用清水洗净。']:[]),...(entry.spoiled?['保留变质状态，劣质效果不会恢复。']:[]),...(!entry.polluted&&!entry.spoiled?[info.description]:[])].join(' ')),button('保留这件',()=>transact(s=>OfficeInheritance.choose(s,index)),'aurai-button aurai-button--primary'));$('rewardChoices').append(card);
    }
  }else if(game.reward){
    $('rewardChoices').append(el('strong',game.reward.kind==='food'?'领取零食':'选择办公福利','reward-heading'));
    for(const key of game.reward.choices){const info=game.reward.kind==='food'?R.items[key]:OfficeWelfare.definitions[key];const card=el('div',null,'stock-card');card.append(el('strong',info.name),el('p',info.description),button(game.reward.kind==='food'&&game.items.length>=R.itemLimit(game)?'立即使用':'领取',()=>transact(s=>OfficeWelfare.choose(s,key,s.reward.kind==='food'&&s.items.length>=R.itemLimit(s))),'aurai-button aurai-button--primary'));$('rewardChoices').append(card);}
  }
  $('continue').hidden=game.status!=='summary';$('continue').disabled=!!game.reward;$('restart').disabled=game.reward?.kind==='inheritance';
  if(game.status==='lost')$('restart').textContent=game.completionReward?'带上'+R.items[game.completionReward.key].name+'，重新上班':'重新上班';
  else $('restart').textContent='重新上班';
  $('restart').className=game.status==='summary'?'office-link':'aurai-button aurai-button--primary';
  if(game.status==='summary')$('continue').textContent=game.phase===2?'开始第二天':'进入'+R.phases[game.phase+1];
}
function render(){
  $('officeGame').classList.toggle('playing',!!game&&screen==='desk');$('welcome').hidden=!!game;$('workplace').hidden=!game||screen!=='desk';$('workMenu').hidden=screen!=='menu';$('restartConfirm').hidden=screen!=='restart';
  $('start').disabled=busy;
  $('newWork').disabled=$('confirmRestart').disabled=busy||game?.reward?.kind==='inheritance';
  $('soundToggle').textContent='音效：'+(soundEnabled?'开启':'关闭');$('soundToggle').setAttribute('aria-pressed',String(soundEnabled));$('soundToggle').disabled=busy;
  writeText('dayBadge',game?game.day+'日'+R.phases[game.phase]+'本局目标':'汉娜的办公桌');
  if(game){
    writeText('scoreLabel',game.score+' / '+Office.target(game));writeText('movesLabel',game.moves+' 次');writeText('coinLabel',game.coins);
    $('targetFill').style.width=Math.min(100,game.score/Office.target(game)*100)+'%';
    writeText('patienceLabel',game.patience);$('patienceFill').style.height=game.patience+'%';document.querySelector('.boss-meter').setAttribute('aria-valuenow',game.patience);$('timeFill').style.width=(100-game.moves)+'%';$('timePointer').style.left=(100-game.moves)+'%';
    $('fatigue').hidden=!game.fatigues.length;$('fatigue').textContent=game.fatigues.map(f=>'疲劳 · '+R.fatigues[f.type]+' · '+W.fatigueDuration(game,f)).join('；');
    writeText('nextLabel',R.fatigue(game,'preview')?'下份文件暂时看不清':'下份文件 '+(game.forcedOnes?1:game.nextCard.value)+' 份');
    writeText('zoneLabel',game.zonePreview&&game.moves<=51&&game.moves>=50?'下次整理出现胶水区':game.outsideMagnets.length?'桌外磁铁 '+game.outsideMagnets.length+' 件 · 文件柜可收回':'');
    renderBoard();inspect();
    renderSection('demands',[game.demands,game.demands.map(d=>game.stats[d.metric]),game.phase,OfficeWelfare.active(game,'commission'),game.status],renderDemands);
    renderSection('cabinet',[game.items,game.pendingItems,game.welfare,game.outsideMagnets,item,game.status,R.itemLimit(game)],renderCabinet);
    if(panel==='shop')renderShop();renderResult();
    for(const n of document.querySelectorAll('.office-desk,.desk-caption,.selection-row,.office-nav,.item-tray'))n.hidden=game.status!=='playing';
    $('demands').hidden=game.status!=='playing';for(const id of ['cabinet','shop'])$(id).hidden=panel!==id||game.status!=='playing';
    for(const b of document.querySelectorAll('[data-panel]')){b.classList.toggle('active',b.dataset.panel===panel);b.disabled=game.status!=='playing';}
    $('slack').disabled=game.status!=='playing'||game.slacks>=5;writeText('slackLabel','摸鱼');$('slack').setAttribute('aria-label',`摸鱼，剩余 ${5-game.slacks} 次`);
  }
  requestPageResize();
}
async function transact(action){
  if(busy)return;
  const previousGame=game,previousPath=path.slice(),previousDrop=drop,previousItem=item;
  let committed=false;
  busy=true;path=[];drop=null;
  try{
    const next=structuredClone(game),selectedItem=item===null?null:next.items[item];
    const result=action(next);
    if(next.status==='playing'&&!result?.approval)Office.checkEnd(next);
    const messages=Office.publish(next);
    const selectedIndex=selectedItem===null?-1:next.items.indexOf(selectedItem);
    item=selectedIndex===-1?null:selectedIndex;
    game=next;render();
    if(!result?.approval)F.animate(previousGame,next);
    await AuraiHTML.saveState({version:7,game:next,soundEnabled});committed=true;
    if(result?.approval){path=previousPath;drop=previousDrop;}
    if(game.status!=='playing')clearSelection();
    if(messages.length)toast(messages.join(' '));
    await F.play(result?.approval?'select':F.changed(previousGame,next));
    return result;
  }finally{busy=false;if(!committed){game=previousGame;path=previousPath;drop=previousDrop;item=previousItem;render();}}
}
function clearSelection(){if(selectionFrame){cancelAnimationFrame(selectionFrame);selectionFrame=0;}touchId=null;inspectOpen=false;path=[];drop=null;item=null;drag=false;groupDrag=false;keyboardSelection=false;}
async function commitSelection(){
  if(!path.length||busy)return;
  if(path.length>1&&!OfficeMerge.complete(path.map(i=>game.board[i]))){
    clearSelection();paintSelection();inspect();toast('文件尚未配齐，本次未合并，也不消耗整理次数');return;
  }
  const chosen=path.slice(),target=drop===null?chosen[chosen.length-1]:drop;
  const result=await transact(s=>Office.connect(s,chosen,target));
  clearSelection();
  if(result?.approval)toast('审批区：请再拖动相同文件到这里，完成第二次合并');
  paintSelection();inspect();
}
async function applyItem(i){
  const index=item;
  const result=await transact(s=>{
    const entry=s.items[index],info=R.items[entry.key];
    if(info.attach&&!entry.polluted&&s.zones[i].types.includes('approval')){
      const key='attach@'+entry.key+'@'+i;
      if(s.pending!==key){s.pending=key;return {approval:true};}
    }
    s.pending=null;W.use(s,index,i);Office.checkEnd(s);return {approval:false};
  });
  if(result?.approval)toast('审批区：再点一次目标物品确认附着');else item=null;render();
}
function tapCell(i){
  if(busy||game.status!=='playing')return;
  if(item!==null){void applyItem(i);return;}
  if(groupDrag&&path.length===1&&i!==path[0]){drop=i;paintSelection();inspect();return;}
  if(!path.length){if(game.board[i])path=[i];}
  else if(path.includes(i)){path=path.slice(0,path.indexOf(i)+1);drop=null;}
  else if(!game.board[i]||R.collectible(game.board[i])||(game.board[i].kind==='stone'&&game.board[i].brittle>0))drop=i;
  else if(connectable().includes(i)){path.push(i);drop=null;}
  paintSelection();inspect();requestPageResize();
}
let dragBounds=null,dragCells=[],dragPoint=null,selectionFrame=0,touchId=null;
function cellAt(e){
  const r=dragBounds;
  if(e.clientX<r.left||e.clientX>=r.right||e.clientY<r.top||e.clientY>=r.bottom)return null;
  return dragCells.findIndex(c=>e.clientX>=c.left&&e.clientX<c.right&&e.clientY>=c.top&&e.clientY<c.bottom);
}
function paintDrag(){
  if(selectionFrame)return;
  selectionFrame=requestAnimationFrame(()=>{selectionFrame=0;paintSelection();});
}
function beginDrag(e){
  if(busy||!game||game.status!=='playing'||drag)return false;
  dragBounds=$('board').getBoundingClientRect();dragCells=Array.from($('board').children,n=>n.getBoundingClientRect());
  const i=cellAt(e);if(i===null||i<0)return false;
  if(item!==null){void applyItem(i);return false;}
  if(groupDrag&&path.length===1&&i!==path[0]){drop=i;paintSelection();return false;}
  if(!game.board[i]){clearSelection();paintSelection();inspect();return false;}
  if(path[0]!==i)groupDrag=false;
  path=[i];drop=null;drag=true;dragPoint={clientX:e.clientX,clientY:e.clientY};keyboardSelection=false;inspectOpen=false;paintSelection();return true;
}
function dragSelection(i){
  if(i===null||i<0){drop=null;return;}
  if(groupDrag){drop=i===path[0]?null:i;return;}
  const existing=path.indexOf(i);
  if(existing>=0){path=path.slice(0,existing+1);drop=i;}
  else if(R.isFile(game.board[i])&&connectable().includes(i)){path.push(i);drop=null;}
  else if(!game.board[i]||R.collectible(game.board[i])||(game.board[i].kind==='stone'&&game.board[i].brittle>0)){drop=i;}
  // Crossing an incompatible file keeps the last valid destination, as in the original.
}
// Touch events may skip cells during a fast stroke; visit the crossed cell interiors in order.
function traceDrag(e){
  const from=dragPoint,dx=e.clientX-from.clientX,dy=e.clientY-from.clientY,hits=[];
  if(dx!==0||dy!==0){
    dragCells.forEach((cell,i)=>{
      let enter=0,leave=1;
      for(const [start,delta,min,max] of [[from.clientX,dx,cell.left,cell.right],[from.clientY,dy,cell.top,cell.bottom]]){
        if(delta===0){if(start<=min||start>=max)return;}
        else{const a=(min-start)/delta,b=(max-start)/delta;enter=Math.max(enter,Math.min(a,b));leave=Math.min(leave,Math.max(a,b));}
      }
      if(enter<leave)hits.push({i,enter});
    });
    hits.sort((a,b)=>a.enter-b.enter).forEach(({i})=>dragSelection(i));
  }
  dragSelection(cellAt(e));dragPoint={clientX:e.clientX,clientY:e.clientY};
}
function releaseDestination(i){
  if(drop!==null)return drop;
  if(i!==null&&i>=0&&(!game.board[i]||path.includes(i)))return i;
  return path[path.length-1];
}
function finishDrag(e){
  if(selectionFrame){cancelAnimationFrame(selectionFrame);selectionFrame=0;}
  traceDrag(e);const i=cellAt(e),target=releaseDestination(i);drag=false;
  if(path.length>1||target!==path[0]){drop=target;void commitSelection();}
  else{drop=null;paintSelection();inspect();requestPageResize();}
}
function cancelDrag(){
  if(selectionFrame){cancelAnimationFrame(selectionFrame);selectionFrame=0;}
  touchId=null;clearSelection();paintSelection();inspect();
}
$('board').onpointerdown=e=>{
  if(e.pointerType==='touch'||e.button!==0)return;
  e.preventDefault();if(beginDrag(e)){pointer=e.pointerId;$('board').setPointerCapture(pointer);}
};
$('board').onpointermove=e=>{
  if(e.pointerType==='touch'||!drag||e.pointerId!==pointer)return;
  traceDrag(e);paintDrag();
};
$('board').onpointerup=e=>{
  if(e.pointerType==='touch'||!drag||e.pointerId!==pointer)return;
  if($('board').hasPointerCapture(e.pointerId))$('board').releasePointerCapture(e.pointerId);
  finishDrag(e);
};
$('board').onpointercancel=e=>{if(e.pointerType!=='touch'&&e.pointerId===pointer)cancelDrag();};
// Read the final Android touch directly; pointer move delivery may be coalesced.
$('board').addEventListener('touchstart',e=>{
  if(touchId!==null)return;
  e.preventDefault();const touch=e.changedTouches[0];if(beginDrag(touch))touchId=touch.identifier;
},{passive:false});
$('board').addEventListener('touchmove',e=>{
  if(touchId===null)return;
  e.preventDefault();const touch=Array.from(e.changedTouches).find(t=>t.identifier===touchId);
  if(touch){traceDrag(touch);paintDrag();}
},{passive:false});
$('board').addEventListener('touchend',e=>{
  if(touchId===null)return;
  const touch=Array.from(e.changedTouches).find(t=>t.identifier===touchId);
  if(touch){e.preventDefault();touchId=null;finishDrag(touch);}
},{passive:false});
$('board').addEventListener('touchcancel',()=>{if(touchId!==null)cancelDrag();});
$('showStatus').onclick=()=>{if(game.fatigues.length)toast(game.fatigues.map(f=>R.fatigues[f.type]+' · '+W.fatigueDuration(game,f)).join('；'));};
$('cancelSelection').onclick=()=>{clearSelection();render();};
$('start').onclick=async()=>{busy=true;render();try{const next=Office.create(crypto.getRandomValues(new Uint32Array(1))[0]);next.notices=[];await AuraiHTML.saveState({version:7,game:next,soundEnabled});game=next;}finally{busy=false;render();}};
$('continue').onclick=()=>transact(s=>Office.advance(s));
$('slack').onclick=()=>transact(s=>Office.slack(s));
$('addCard').onclick=()=>transact(s=>W.editDeck(s,'add',0));
for(const b of document.querySelectorAll('[data-panel]'))b.onclick=()=>{if(busy)return;panel=panel===b.dataset.panel?'demands':b.dataset.panel;clearSelection();render();};
$('menu').onclick=()=>{if(busy)return;clearSelection();screen='menu';render();};
$('soundToggle').onclick=async()=>{
  if(busy)return;busy=true;render();
  try{
    const nextEnabled=!soundEnabled,unlocked=nextEnabled?F.unlock():null;
    await AuraiHTML.saveState({version:7,game,soundEnabled:nextEnabled});
    soundEnabled=nextEnabled;F.setEnabled(soundEnabled);
    if(unlocked)await unlocked;await F.play('select');
  }finally{busy=false;render();}
};
$('officeGame').addEventListener('pointerdown',async()=>{if(soundEnabled)await F.unlock();},{capture:true});
$('returnToWork').onclick=()=>{screen='desk';render();};
$('newWork').onclick=$('restart').onclick=()=>{screen='restart';render();};
$('keepWork').onclick=()=>{screen='desk';render();};
$('confirmRestart').onclick=async()=>{
  if(busy)return;busy=true;render();
  try{const next=OfficeInheritance.restart(game,crypto.getRandomValues(new Uint32Array(1))[0]);next.notices=[];await AuraiHTML.saveState({version:7,game:next,soundEnabled});game=next;clearSelection();screen='desk';panel='demands';}
  finally{busy=false;render();}
};
function guide(id,entries){$(id).replaceChildren(...entries.map(([name,text])=>{const p=el('p');p.append(el('strong',name+'：'),document.createTextNode(text));return p;}));}
guide('zoneGuide',Object.values(R.zones).map(([name,,text])=>[name,text]));
guide('itemGuide',Object.entries(R.items).map(([key,a])=>[a.name+' · '+R.rarities[R.itemRarity[key]],a.description]));
guide('fatigueGuide',Object.values(R.fatigues).map(text=>['疲劳',text+'；按剩余步数或标注的阶段结束时间消退，可用咖啡缓解。']));
guide('fileGuide',[
  ['杂乱','移动时累计整理进度，合并时计入整理份数。'],['紧急','10 步内合并，否则每步扣 1 忍耐度。'],
  ['废弃','只能与同值废弃文件合并，送进废弃区才计入整理。'],['复印','可与任意普通文件合并，按另一份文件的份数复制，可多张叠加。'],
  ['撤销','可与普通文件合并，本次不得分并添加撤销；与普通文件合并后解除撤销；再次撤销可抵消，两个撤销文件合成普通 1 份。'],
  ['金属','导电、受磁吸；手动移动带电物品需要绝缘手套。']]);
document.addEventListener('aurai:restore',()=>{if(!busy){game=AuraiHTML.state?.version===7?AuraiHTML.state.game:null;soundEnabled=AuraiHTML.state?.soundEnabled===true;F.setEnabled(soundEnabled);clearSelection();render();}});
document.addEventListener('aurai:pause',()=>{F.pause();clearSelection();if(game)render();});
document.addEventListener('aurai:resume',()=>{F.resume();render();});
document.addEventListener('visibilitychange',()=>{if(document.hidden)F.pause();else F.resume();});
document.addEventListener('aurai:displaychange',()=>{if(game){clearSelection();render();}else requestPageResize();});
render();
