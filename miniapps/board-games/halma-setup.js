let halmaRoster='';
function renderHalmaSetup(){
  if(!$('halmaSeats')){
    const count=text('label','','aurai-field');count.append(text('span','人数'));
    const select=document.createElement('select');select.id='halmaSeats';[2,3,4,6].forEach(n=>{const option=text('option',n+' 人');option.value=String(n);select.append(option);});select.onchange=render;count.append(select);
    const slots=text('div','','aurai-stack');slots.id='halmaPlayers';$('setup').insertBefore(count,$('human').closest('label'));$('setup').insertBefore(slots,$('human').closest('label'));
  }
  $('human').closest('label').hidden=true;$('ai').closest('label').hidden=true;$('matchTypeField').hidden=true;
  const count=Number($('halmaSeats').value),key=JSON.stringify([count,host.members]);
  const engines=Array.from({length:5},(_,i)=>({id:'engine:halma:'+(i+1),name:'电脑 '+(i+1),kind:'engine'}));
  const members=[...host.members.slice().sort((a,b)=>a.name.localeCompare(b.name,'zh-CN')), ...engines];
  if(key!==halmaRoster){
    const previous=Array.from($('halmaPlayers').querySelectorAll('select')).map(el=>el.value);halmaRoster=key;$('halmaPlayers').replaceChildren();
    for(let i=0;i<count;i++){const field=text('label','','aurai-field');field.append(text('span','玩家 '+(i+1)));const select=document.createElement('select');select.id='halmaPlayer'+i;field.append(select);$('halmaPlayers').append(field);options(select.id,members,previous[i]||(i===0?host.viewerId:engines[i-1].id));select.onchange=render;}
  }
  const ids=Array.from($('halmaPlayers').querySelectorAll('select')).map(el=>el.value),chosen=ids.map(id=>members.find(m=>m.id===id));
  options('first',chosen,host.viewerId);
  const local=chosen.some(m=>m.kind==='engine'),duplicates=new Set(ids).size!==count;
  $('difficultyField').hidden=!local;$('difficulty').disabled=!canManage()||busy;$('halmaSeats').disabled=!canManage()||busy;$('first').disabled=!canManage()||busy;
  $('halmaPlayers').querySelectorAll('select').forEach(el=>el.disabled=!canManage()||busy);
  $('setupHint').textContent=!canManage()?'等待发起人选择玩家并开局':duplicates?'请选择不同玩家':local&&host.viewerId!=='user:local'?'请由本机用户开启电脑对局':'选择聊天成员或电脑，按席位依次行动。';
  $('start').disabled=!canManage()||busy||duplicates||local&&host.viewerId!=='user:local';
}
function halmaSetup(){return {players:Array.from($('halmaPlayers').querySelectorAll('select')).map(el=>el.value),firstId:$('first').value,difficulty:Number($('difficulty').value)};}
