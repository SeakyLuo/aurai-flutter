const escape=text=>text.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
function inline(text){
return escape(text).replace(/\[([^\]]+)\]\(([^)]+)\)/g,(match,label,target)=>{
const file=target.replace(/^\.\//,'').split('#')[0],index=documents.findIndex(doc=>doc.fileName===file);
return index>=0?`<a href="#" data-doc="${index}">${label}${index===7?'（主持人剧透）':''}</a>`:label;
}).replace(/`([^`]+)`/g,'<code>$1</code>').replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>');
}
function markdown(source){
const lines=source.split(/\r?\n/),out=[];
let index=0,headingIndex=0;
const isTableRule=line=>/^\s*\|?\s*:?-{3,}/.test(line);
const cells=line=>line.trim().replace(/^\|/,'').replace(/\|$/,'').split('|').map(cell=>cell.trim());
while(index<lines.length){
const line=lines[index];
if(!line.trim()){index++;continue}
const heading=/^(#{1,6})\s+(.+)$/.exec(line);
if(heading){out.push(`<h${heading[1].length} id="section-${headingIndex++}">${inline(heading[2])}</h${heading[1].length}>`);index++;continue}
if(line.startsWith('|')&&index+1<lines.length&&isTableRule(lines[index+1])){
const titles=cells(line);index+=2;const rows=[];
while(index<lines.length&&lines[index].startsWith('|')){rows.push(`<tr>${cells(lines[index++]).map(cell=>`<td>${inline(cell)}</td>`).join('')}</tr>`)}
out.push(`<div class="tableWrap"><table><thead><tr>${titles.map(title=>`<th scope="col">${inline(title)}</th>`).join('')}</tr></thead><tbody>${rows.join('')}</tbody></table></div>`);continue;
}
if(/^>\s?/.test(line)){out.push(`<blockquote>${inline(line.replace(/^>\s?/,''))}</blockquote>`);index++;continue}
if(/^[-*]\s+/.test(line)||/^\d+\.\s+/.test(line)){
const ordered=/^\d+\.\s+/.test(line),pattern=ordered?/^\d+\.\s+/:/^[-*]\s+/,items=[];
while(index<lines.length&&pattern.test(lines[index]))items.push(`<li>${inline(lines[index++].replace(pattern,''))}</li>`);
out.push(`<${ordered?'ol':'ul'}>${items.join('')}</${ordered?'ol':'ul'}>`);continue;
}
if(/^---+$/.test(line.trim())){out.push('<hr>');index++;continue}
out.push(`<p>${inline(line)}</p>`);index++;
}
return out.join('');
}
function list(){app.innerHTML=header('规则与资料')+`<section class="card"><button class="ghost" data-back>返回</button><h2>资料目录</h2>${roleButtons()}<div class="documentNav">${documents.map((doc,index)=>index===7&&role==='player'?'':`<button class="action" data-doc="${index}"><b>${escape(doc.title)}</b><span>${index===7?'包含剧透':'查看规则'}</span></button>`).join('')}</div></section>`}
