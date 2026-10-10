const app=document.getElementById('app');
const resourceCache=new Map();
function resource(key){if(!resourceCache.has(key))resourceCache.set(key,JSON.parse(document.getElementById(key).textContent));return resourceCache.get(key);}
const documents=JSON.parse(document.getElementById('reference-index').textContent);
documents.forEach(doc=>Object.defineProperty(doc,'content',{get(){return doc.sections.map(section=>resource(section.key).content).join('');}}));
const characterArt=JSON.parse(document.getElementById('portrait-index').textContent);
const artByKey=Object.fromEntries(characterArt.avatars.map(item=>[item.key,item]));
const gameRules=JSON.parse(document.getElementById('game-rules').textContent);
const animals=gameRules.animals.map(item=>({...item,art:artByKey[characterArt.playable[item.name]]}));
const professions=gameRules.professions;
let selectedAnimal=0,selectedProfession=0;
let view='home',stage=0,role='player',section='';
const history=[];
