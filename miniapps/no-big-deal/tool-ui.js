const OfficeToolUI = (() => {
  let source=null,target=null,draftGame=null,poolView='';
  const reset=()=>{source=null;target=null;draftGame=game;};
  const active=()=>item!==null&&!game.items[item].polluted&&OfficeTools.has(game.items[item].key);
  function select(index){
    const entry=game.items[index],info=R.items[entry.key];
    if(item===index){clearSelection();render();return;}
    if(!entry.polluted&&OfficeTools.has(entry.key)){
      const why=OfficeTools.availability(game,entry.key);if(why){toast(why);return;}
    }
    if(!entry.polluted&&info.target==='passive'){toast(info.description);return;}
    if(!entry.polluted&&info.target==='instant'){void transact(s=>W.use(s,index,0));return;}
    clearSelection();item=index;reset();render();
    $('board').scrollIntoView({block:'nearest',behavior:'smooth'});
  }
  function pick(i){
    const key=game.items[item].key;
    if(key==='requisition')return;
    if(key==='dispatch'){
      const why=OfficeTools.problem(game,key,null,i);if(why){toast(why);return;}target=i;
    }else if(game.board[i]){
      const why=OfficeTools.sourceProblem(game,key,i);if(why){toast(why);return;}source=i;target=null;
    }else if(source!==null&&key!=='stapler'){
      const why=OfficeTools.problem(game,key,source,i);if(why){toast(why);return;}target=i;
    }else {toast('请先选择普通文件');return;}
    paintSelection();
  }
  function hint(key){
    const concealed=source!==null&&(fogged(source)||hiddenValue(game.board[source],source));
    const value=source===null?null:game.board[source].value;
    if(key==='requisition')return target===null?'选择本轮剩余文件，作为下一份':R.kinds[game.pool[target].kind][0]+' '+game.pool[target].value+' 份 → 下份预告';
    if(key==='dispatch')return target===null?'选择下一份文件的落点':'下份文件 → 第 '+(Math.floor(target/4)+1)+' 行第 '+(target%4+1)+' 列';
    if(source===null)return key==='paperKnife'?'选择要拆分的偶数份普通文件':'选择一份普通文件';
    if(key==='stapler')return concealed?'选中文件的份数翻倍':value+' → '+value*2+' 份';
    const result=concealed?(key==='paperKnife'?'拆成两半':'复印相同份数'):key==='paperKnife'?value+' → '+value/2+' ＋ '+value/2+' 份':'复印 '+value+' 份';
    return result+(target===null?'，再选空格':'');
  }
  function paint(){
    const showing=item!==null&&game.status==='playing'&&screen==='desk';
    $('itemAction').hidden=!showing;
    for(const cell of $('board').children){
      cell.classList.remove('tool-source','tool-target','tool-valid','tool-invalid');
      for(const n of cell.querySelectorAll('.tool-number-preview'))n.remove();
    }
    if(!showing){$('toolPool').hidden=true;poolView='';return;}
    const entry=game.items[item],key=entry.key,isTool=active();
    if(draftGame!==game)reset();
    writeText('toolName',R.items[key].name);
    writeText('toolHint',isTool?hint(key):entry.polluted?'选择空格放回桌面，洗净后收集':R.items[key].description);
    $('useTool').hidden=!isTool;$('toolPool').hidden=!isTool||key!=='requisition';
    if(!isTool)return;
    const ready=(key==='requisition'||key==='dispatch'?target!==null:key==='stapler'?source!==null:source!==null&&target!==null);
    $('useTool').disabled=busy||!ready;
    if(key==='requisition'){
      const view=JSON.stringify([game.pool,target]);
      if(poolView!==view){
        poolView=view;$('toolPool').replaceChildren(...game.pool.map((o,i)=>{
          const b=button(null,()=>{target=i;paintSelection();},'tool-pool-card'+(target===i?' active':''));
          b.append(el('strong',o.value+' 份'),el('span',R.kinds[o.kind][0]));
          const tags=[...statusTags(o),...(o.polluted?['污染']:[])];if(tags.length)b.append(el('small',tags.join(' · ')));
          b.setAttribute('aria-pressed',String(target===i));return b;
        }));
      }
      return;
    }
    poolView='';
    for(const cell of $('board').children){
      const i=Number(cell.dataset.cell),o=game.board[i];
      const valid=key==='dispatch'?OfficeTools.emptyTargets(game).includes(i):o?!OfficeTools.sourceProblem(game,key,i):key!=='stapler'&&source!==null&&OfficeTools.emptyTargets(game).includes(i);
      cell.classList.toggle('tool-valid',valid);cell.classList.toggle('tool-invalid',!valid);
      cell.classList.toggle('tool-source',i===source);cell.classList.toggle('tool-target',i===target);
    }
    if(source!==null&&!fogged(source)&&!hiddenValue(game.board[source],source)){
      const value=game.board[source].value;
      if(key==='stapler')$('board').children[source].append(el('span','→ '+value*2,'tool-number-preview'));
      if(key==='paperKnife')$('board').children[source].append(el('span','→ '+value/2,'tool-number-preview'));
      if(target!==null&&key!=='stapler')$('board').children[target].append(el('span',key==='paperKnife'?value/2:value,'tool-number-preview'));
    }
  }
  async function commit(){
    if(busy||!active())return;
    const index=item,from=source,to=target;
    await transact(s=>{OfficeTools.use(s,index,from,to);return {approval:false};});
    clearSelection();render();
  }
  function init(){
    $('useTool').onclick=commit;
    $('cancelTool').onclick=()=>{if(!busy){clearSelection();render();}};
  }
  return {active,select,pick,paint,reset,init};
})();
