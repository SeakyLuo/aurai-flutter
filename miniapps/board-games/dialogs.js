let dialogPage='',drawDialogKey='';
function closeGameDialog(){
  $('gameDialog').close();dialogPage='';
}
function openGameDialog(page){
  dialogPage=page;
  const titles={Menu:'对局菜单',Rules:'规则',Difficulty:'难度',Restart:s.phase==='finished'?'再来一局':'重新开始',Resign:'确认认输？',Draw:'提议和棋？',AnswerDraw:'对手提议和棋'};
  $('dialogTitle').textContent=titles[page];
  for(const name of ['Menu','Rules','Difficulty','Restart'])$('dialog'+name).hidden=name!==page;
  const questions={Resign:GAME==='halma'&&s.players.length>2?'退出本局，其余玩家继续对局。':'认输后本局结束，对手获胜。',Draw:'向对手提出和棋，双方同意后结束本局。',AnswerDraw:'接受后本局以和棋结束，也可以继续对局。'};
  $('dialogQuestion').hidden=!questions[page];$('dialogQuestion').textContent=questions[page]||'';
  $('restartText').textContent=GAME==='halma'?'保持颜色，轮换先手，开始下一局。':s.phase==='finished'?'交换先后手，开始下一局。':'结束当前对局，交换先后手重新开始。';
  $('matchDifficulty').value=String(s.difficulty);
  $('nextMode').value=s.mode||'normal';
  $('dialogCancel').textContent=page==='Menu'||page==='Rules'?'关闭':page==='AnswerDraw'?'继续对局':'取消';
  $('dialogConfirm').hidden=page==='Menu'||page==='Rules';
  $('dialogConfirm').textContent={Difficulty:'保存',Restart:s.phase==='finished'?'再来一局':'重新开始',Resign:'认输',Draw:'提出和棋',AnswerDraw:'接受和棋'}[page]||'确定';
  $('dialogConfirm').classList.toggle('aurai-button--danger',page==='Resign');
  $('dialogConfirm').classList.toggle('aurai-button--primary',page!=='Resign');
  if(!$('gameDialog').open)$('gameDialog').showModal();
  $('dialogCancel').focus({preventScroll:true});
}
function syncGameDialogs(){
  const own=me(),playing=s.phase==='playing',manage=!!own||s.watching&&canManage();
  $('menuDifficulty').hidden=!s.players?.some(p=>p.kind==='engine')||GAME==='tictactoe';
  $('menuDifficulty').disabled=busy||!manage;
  $('menuRestart').hidden=!s.phase||s.phase==='setup';$('menuRestart').disabled=busy||!manage;
  $('offerDraw').hidden=!own||!playing||GAME==='halma'&&s.players.length>2;
  $('offerDraw').disabled=busy||s.drawOffer===own?.id;
  $('dialogConfirm').disabled=busy;
  if(['Resign','Draw','AnswerDraw'].includes(dialogPage)&&!playing)closeGameDialog();
  const incoming=playing&&own&&s.drawOffer&&s.drawOffer!==own.id;
  if(dialogPage==='AnswerDraw'&&!incoming)closeGameDialog();
  const key=incoming?`${s.game}:${s.drawOffer}`:'';
  if(!incoming)drawDialogKey='';
  else if(fullscreen()&&!busy&&key!==drawDialogKey){drawDialogKey=key;openGameDialog('AnswerDraw');}
}
function initGameDialogs(){
  $('menu').onclick=()=>openGameDialog('Menu');
  $('menuRules').onclick=()=>openGameDialog('Rules');
  $('menuDifficulty').onclick=()=>openGameDialog('Difficulty');
  $('menuRestart').onclick=$('rematch').onclick=()=>openGameDialog('Restart');
  $('resign').onclick=()=>openGameDialog('Resign');
  $('offerDraw').onclick=()=>openGameDialog(s.drawOffer&&s.drawOffer!==me().id?'AnswerDraw':'Draw');
  $('dialogCancel').onclick=()=>{const answer=dialogPage==='AnswerDraw';closeGameDialog();if(answer)void submit('answerDraw',{accept:false});};
  $('dialogConfirm').onclick=()=>{
    const page=dialogPage,level=Number($('matchDifficulty').value),mode=$('nextMode').value;
    closeGameDialog();
    if(page==='Difficulty')void submit('difficulty',{level});
    else if(page==='Restart')void submit(s.phase==='finished'?'rematch':'restart',GAME==='xiangqi'?{mode}:{});
    else if(page==='Resign')void submit('resign');
    else if(page==='Draw')void submit('offerDraw');
    else if(page==='AnswerDraw')void submit('answerDraw',{accept:true});
  };
  $('gameDialog').addEventListener('cancel',()=>{dialogPage='';});
  $('gameDialog').addEventListener('click',event=>{if(event.target===$('gameDialog')){const rect=$('gameDialog').getBoundingClientRect();if(event.clientX<rect.left||event.clientX>rect.right||event.clientY<rect.top||event.clientY>rect.bottom)closeGameDialog();}});
}
