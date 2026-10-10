var s=ctx.state,e=ctx.event,d=e.data,privateViews={};
function check(ok,text){if(!ok)throw new Error(text);}
function text(value,label){check(typeof value==='string'&&value.trim().length>0&&value.length<=2000,label+'需要明确内容');return value;}
function amount(value,label){check(typeof value==='number'&&isFinite(value)&&value>=0,label+'必须是非负数');return value;}
function count(value,label){check(Number.isInteger(value)&&value>0&&value<=100,label+'必须为 1–100 的整数');return value;}
function member(id){var m=ctx.members.filter(function(m){return m.id===id;})[0];check(!!m,'成员不在当前群聊');return m;}
function manager(){check(e.actorId===s.hostId||e.actorId===ctx.ownerId,'只有主持人或创建人可以结算');check(s.phase==='active','旅程尚未开始或已暂停');}
function money(value){return Math.round(value*100)/100;}
function record(kind,note,change){s.seq++;s.ledger.push({seq:s.seq,kind:kind,note:note,cash:money(change),balance:s.cash});}
function charge(cost,note){cost=money(amount(cost,'费用'));check(s.cash>=cost,'共有资金不足，当前 '+s.cash+' 元，需要 '+cost+' 元');s.cash=money(s.cash-cost);record('支出',note,-cost);}
function income(value,note){value=money(amount(value,'收入'));s.cash=money(s.cash+value);record('收入',note,value);}
function character(id){var p=s.players.filter(function(p){return p.memberId===id;})[0];check(!!p,'该成员没有绑定角色');return p;}
function professional(id,name){return id!==undefined&&character(id).profession===name;}
function group(id){var p=s.passengers.filter(function(p){return p.id===id;})[0];check(!!p,'乘客组不存在');return p;}
function order(id){var o=s.orders.filter(function(o){return o.id===id;})[0];check(!!o,'订单不存在');return o;}
function items(rows){check(Array.isArray(rows)&&rows.length>0&&rows.length<=60,'物资列表需要 1–60 项');var result={};rows.forEach(function(row){text(row.name,'物资名称');check(row.quantity>0&&isFinite(row.quantity),'物资数量须为正数');check(result[row.name]===undefined,'同种物资请合并数量');result[row.name]=row.quantity;});return result;}
function consume(rows){Object.keys(rows).forEach(function(name){check((s.inventory[name]||0)>=rows[name],'库存不足：'+name+'，剩余 '+(s.inventory[name]||0));});Object.keys(rows).forEach(function(name){s.inventory[name]=money(s.inventory[name]-rows[name]);});}
function receive(rows){Object.keys(rows).forEach(function(name){s.inventory[name]=money((s.inventory[name]||0)+rows[name]);});}
function saveJournal(value){
 check(value&&typeof value==='object'&&!Array.isArray(value),'请保存未完约定、线索、人物关系与进行中的行动');
 var fields=['commitments','clues','relationships','ongoing'],journal={};
 fields.forEach(function(key){check(Array.isArray(value[key])&&value[key].length<=20,'旅程笔记每类最多 20 项');journal[key]=value[key].map(function(note){check(typeof note==='string'&&note.trim().length>0&&note.length<=500,'笔记每项需要 1–500 字');return note;});});
 check(JSON.stringify(journal).length<=12000,'旅程笔记总长最多 12000 字');s.journal=journal;
}
function checkpoint(journal){saveJournal(journal);host.call('context.compact',{instructions:'安宁列车的资金、库存、订单、场景、幕后事实及旅程笔记已保存于程序。下一轮先读取当前状态，按需查阅规则章节；不要重读完整 HTML。未完约定与线索以 journal 为准，不重演已完成行动。'});}
