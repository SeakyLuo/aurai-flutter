function documentView(index){
const doc=documents[index],headings=[...doc.content.matchAll(/^(#{1,6})\s+(.+)$/gm)];
app.innerHTML=header(doc.title)+`<section class="card"><div class="buttons"><button class="ghost" data-back>返回</button><button class="ghost" data-view="home">旅途指南</button><button class="ghost" data-view="list">全部资料</button></div>${index===7?'<p class="notice">主持人资料 · 包含事件幕后事实与场景答案</p>':''}<details><summary>章节目录</summary><nav class="documentToc" aria-label="章节">${headings.map((heading,i)=>heading[1].length===2?`<a href="#section-${i}" data-anchor="section-${i}">${escape(heading[2])}</a>`:'').join('')}</nav></details></section><article class="card document">${markdown(doc.content)}</article><div class="buttons"><button class="secondary" data-back>返回之前页面</button></div>`;
if(section){const target=headings.findIndex(heading=>heading[2].replace(/^\d+\.\s*/, '')===section);if(target>=0)document.getElementById(`section-${target}`).scrollIntoView()}
}
function render(){window.scrollTo(0,0);if(view==='home')home();else if(view==='guide')guide();else if(view==='list')list();else if(view==='characters')characterCards();else documentView(view)}
function open(next,heading=''){history.push({view,stage,role,section,scroll:window.scrollY});view=next===2?'characters':next;if(next===7)role='dm';section=heading;render()}
app.addEventListener('click',event=>{
const target=event.target.closest('[data-view],[data-doc],[data-stage],[data-role],[data-back],[data-anchor],[data-animal]');if(!target)return;
event.preventDefault();
if(target.hasAttribute('data-back')){const previous=history.pop();if(previous){({view,stage,role,section}=previous);render();window.scrollTo(0,previous.scroll)}else{view='home';section='';render()}return}
if(target.dataset.anchor){document.getElementById(target.dataset.anchor).scrollIntoView();return}
if(target.dataset.animal!==undefined){selectedAnimal=Number(target.dataset.animal);characterCards();document.getElementById("combination").scrollIntoView();document.getElementById("profession").focus({preventScroll:true});return}
if(target.dataset.role){role=target.dataset.role;render();return}
if(target.dataset.stage!==undefined){const scroll=window.scrollY;stage=Number(target.dataset.stage);guide();window.scrollTo(0,scroll);return}
if(target.dataset.doc!==undefined){open(Number(target.dataset.doc),target.dataset.section||'');return}
open(target.dataset.view);
});
app.addEventListener('change',event=>{if(event.target.id==='profession'){selectedProfession=Number(event.target.value);const scroll=window.scrollY;characterCards();window.scrollTo(0,scroll);document.getElementById('profession').focus({preventScroll:true})}});
app.addEventListener('toggle',event=>{
 const details=event.target;if(!details.open)return;
 if(details.hasAttribute('data-lazy-gallery')){
  const gallery=details.querySelector('[data-gallery]');if(gallery.childElementCount)return;
  const used=new Set(Object.values(characterArt.playable));
  gallery.innerHTML=characterArt.avatars.filter(item=>!used.has(item.key)).map(item=>`<div class="galleryPortrait"><img loading="lazy" decoding="async" src="${item.src}" alt="${item.name}" width="96" height="96">${item.name}</div>`).join('');
 }
 if(details.hasAttribute('data-lazy-rules')){const article=details.querySelector('[data-animal-rules]');if(!article.childElementCount)article.innerHTML=markdown(documents[2].content);}
},true);
document.addEventListener('aurai:messageupdate',()=>{if(view==='home')home()});
render();
