function archivePanel(key,title,offset=0){return `<section class="card"><details data-archive="${key}"><summary>${title}</summary><div data-archive-rows></div><button class="secondary" data-more-archive="${key}" data-offset="${offset}">查看记录</button></details></section>`;}
function archiveRow(key,row){
 if(key==='archive-orders')return `<div class="skillPanel"><strong>${escape(row.title)} · ${row.servings} 份</strong><p>${escape(row.requirements)}</p><p class="small">${escape(row.status)} · ${row.price} 元</p>${row.menu?`<p>${escape(row.menu)}</p>`:''}</div>`;
 if(key==='archive-passengers')return `<p><strong>${escape(row.name)}</strong> · ${row.count} 位 → ${escape(row.destination)}</p><p class="small">${escape(row.requirements)}</p>`;
 return `<p>${escape(row.note)}${row.cash?' · '+(row.cash>0?'+':'')+row.cash+' 元':''}<br><span class="small">余额 ${row.balance} 元</span></p>`;
}
async function loadArchive(button){
 button.disabled=true;const key=button.dataset.moreArchive;
 try{
  const result=await AuraiHTML.readProgramResource(key,Number(button.dataset.offset));
  if(!button.isConnected)return;
  const rows=button.closest('[data-archive]').querySelector('[data-archive-rows]');
  rows.insertAdjacentHTML('beforeend',result.items.map(row=>archiveRow(key,row)).join('')||(result.total===0?'<p class="small">暂无历史记录。</p>':''));
  if(result.nextOffset===undefined)button.remove();else{button.dataset.offset=result.nextOffset;button.textContent='查看更多';}
 }finally{button.disabled=false;}
}
function showPageError(error){
 const toast=document.createElement('div');toast.className='pageToast';toast.setAttribute('role','status');toast.textContent=error.message;document.body.append(toast);setTimeout(()=>toast.remove(),6000);
}
app.addEventListener('click',event=>{const button=event.target.closest('[data-more-archive]');if(button)void loadArchive(button).catch(showPageError);});
