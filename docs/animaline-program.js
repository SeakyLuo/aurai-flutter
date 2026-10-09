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
function wake(note){host.call('messages.send',{text:note,audience:[s.hostId],wakeAi:true,wakeMemberIds:[s.hostId]});}
if(e.action==='configure'){
 check(e.actorId===ctx.ownerId||e.actorId==='user:local','只有创建人可以开始旅程');check(!s.phase||s.phase==='setup','已有旅程，请继续当前旅程');
 check(member(d.hostId).kind==='agent','请选择主持 AI');check(Array.isArray(d.players)&&d.players.length>=1&&d.players.length<=12,'选择 1–12 位玩家');
 var used={};d.players.forEach(function(p){member(p.memberId);check(p.memberId!==d.hostId&&!used[p.memberId],'主持人不能兼任玩家，玩家不能重复');used[p.memberId]=true;check(rules.animals.some(function(a){return a.name===p.animal;})&&rules.professions.some(function(a){return a.name===p.profession;}),'请选择已开放的动物和职业');});
 s={phase:'active',hostId:d.hostId,players:d.players.map(function(p){return {memberId:p.memberId,name:member(p.memberId).name,animal:p.animal,profession:p.profession};}),cash:30,inventory:JSON.parse(JSON.stringify(rules.inventory)),passengers:JSON.parse(JSON.stringify(rules.passengers)),orders:JSON.parse(JSON.stringify(rules.orders)),facilities:rules.facilities.slice(),scene:{mode:'行驶中',station:'',nextStation:'松岭',title:'午餐营业',description:'三组乘客提出了午餐需求。玩家在群聊中讨论菜单和分工。',crowding:'宽松'},event:{title:'',progress:'',known:[]},secrets:[],offers:[],routePaid:false,ledger:[],seq:0};
 host.call('messages.mark',{});host.call('messages.pin',{});wake('安宁列车旅程已建立。请先读取后台状态，在群聊介绍角色、三张午餐需求与当前库存，邀请玩家商量分工。不要让玩家通过页面点阶段推进。');
}else if(e.action==='resume'){
 check(e.actorId===s.hostId||e.actorId===ctx.ownerId,'只有主持人或创建人可以恢复');check(s.phase==='paused','当前未暂停');s.phase='active';wake('旅程恢复，请根据保存状态在群聊继续。');
}else if(e.action==='pause'){
 manager();s.phase='paused';record('旅程','暂停旅程',0);
}else if(e.action==='setCharacter'){
 check(s.phase==='active','旅程尚未开始或已暂停');var id=d.memberId;check(e.actorId===id||e.actorId===s.hostId||e.actorId===ctx.ownerId,'只能选择自己的角色');var p=character(id);
 check(!s.ledger.some(function(row){return row.kind!=='角色';}),'营业开始后不再改换技能');check(rules.animals.some(function(a){return a.name===d.animal;})&&rules.professions.some(function(a){return a.name===d.profession;}),'动物或职业未开放');p.animal=d.animal;p.profession=d.profession;record('角色',p.name+'选择了'+p.animal+' · '+p.profession,0);
}else if(e.action==='arrive'){
 manager();check(s.scene.mode==='行驶中'&&d.station===s.scene.nextStation,'请按当前目的站抵达');s.scene.mode='停站';s.scene.station=d.station;s.scene.nextStation=text(d.nextStation,'下一站');s.routePaid=false;s.offers=[];record('到站','抵达'+d.station,0);
}else if(e.action==='depart'){
 manager();check(s.scene.mode==='停站','当前不在车站');check(d.lineConfirmed===true,'离站前需站方确认路段通行');check(s.routePaid,'尚未完成下一段牵引燃料补给');s.scene.mode='行驶中';s.offers=[];record('出发','离开'+s.scene.station+'，前往'+s.scene.nextStation,0);
}else if(e.action==='setOffers'){
 manager();check(s.scene.mode==='停站','供应商只能在停站时提供');check(Array.isArray(d.offers)&&d.offers.length<=100,'供应清单最多 100 项');var names={};
 d.offers.forEach(function(o){text(o.name,'商品');check(!names[o.name],'商品重复');names[o.name]=true;count(o.quantity,'供应数量');amount(o.price,'单价');});s.offers=d.offers;
}else if(e.action==='purchase'){
 manager();check(s.scene.mode==='停站','离站后不能购买站内商品');var requested=items(d.items),cost=0;
 Object.keys(requested).forEach(function(name){var offer=s.offers.filter(function(o){return o.name===name;})[0];check(!!offer&&offer.quantity>=requested[name],'商家库存不足：'+name);cost+=offer.price*requested[name];});
 if(professional(d.memberId,'商人'))cost*=.9;charge(cost,text(d.note,'采购说明'));
 s.offers.forEach(function(o){if(requested[o.name]!==undefined)o.quantity-=requested[o.name];});receive(requested);
}else if(e.action==='supply'){
 manager();check(s.scene.mode==='停站'&&!s.routePaid,'当前不能重复补给');var cost=amount(d.cost,'路段补给价格');if(professional(d.memberId,'商人'))cost*=.9;charge(cost,text(d.note,'补给说明'));s.routePaid=true;
}else if(e.action==='acquire'){
 manager();check(d.executed===true,'审核通过不等于取得物资，请先执行');var obtained=items(d.items);text(d.note,'来源与实际行动');receive(obtained);record('取得物资',d.note,0);
}else if(e.action==='board'){
 manager();check(s.scene.mode==='停站','新乘客只能在车站上车');check(d.arrangementConfirmed===true,'先确认接待方案');text(d.id,'乘客组标识');check(!s.passengers.some(function(p){return p.id===d.id;}),'该乘客组已登记');count(d.count,'乘客数');amount(d.fare,'每人票价');
 var passenger={id:d.id,name:text(d.name,'同行组名称'),count:d.count,destination:text(d.destination,'目的站'),requirements:text(d.requirements,'已约定的需求'),onboard:true};s.passengers.push(passenger);income(d.count*d.fare,passenger.name+'购票至'+passenger.destination);
}else if(e.action==='alight'){
 manager();check(s.scene.mode==='停站','乘客到站才能下车');var passenger=group(d.groupId);check(passenger.onboard&&passenger.destination===s.scene.station,'乘客尚未到约定目的站');passenger.onboard=false;record('下客',passenger.name+'在'+s.scene.station+'下车',0);
}else if(e.action==='reroute'){
 manager();var passenger=group(d.groupId);check(passenger.onboard&&d.agreed===true,'需在车乘客同意改程');var fare=amount(d.extraFare,'每人补票款');passenger.destination=text(d.destination,'新目的站');income(passenger.count*fare,passenger.name+'改程补票');
}else if(e.action==='addOrder'){
 manager();check(group(d.groupId).onboard,'订单乘客已下车');check(!s.orders.some(function(o){return o.id===d.id;}),'订单已存在');text(d.id,'订单标识');count(d.servings,'份数');amount(d.price,'已约定总餐费');
 s.orders.push({id:d.id,groupId:d.groupId,title:text(d.title,'订单名称'),requirements:text(d.requirements,'饮食要求'),servings:d.servings,price:d.price,status:'待交付'});
}else if(e.action==='amendOrder'){
 manager();var o=order(d.orderId);check(o.status==='待交付'&&d.agreed===true,'只能协商修改待交付订单');o.title=text(d.title,'订单名称');o.requirements=text(d.requirements,'饮食要求');o.servings=count(d.servings,'份数');o.price=amount(d.price,'重新约定总餐费');record('订单',o.title+'的菜单与价格已重新协商',0);
}else if(e.action==='deliver'){
 manager();var o=order(d.orderId);check(o.status==='待交付','订单不能重复交付');check(d.agreed===true,'实际菜单需乘客同意');count(d.baseServings,'本批普通份数');var made=professional(d.memberId,'厨师')?Math.floor(d.baseServings*1.25):d.baseServings;
 check(made>=o.servings,'本批餐食不足约定份数');consume(items(d.ingredients));o.status='已交付';o.menu=text(d.menu,'实际菜单');o.produced=made;o.extraServings=made-o.servings;income(o.price,o.title+'交付');
}else if(e.action==='cancelOrder'){
 manager();var o=order(d.orderId);check(o.status==='待交付','该订单不能取消');check(d.agreed===true,'取消需与乘客协商');o.status='已取消';record('订单',o.title+'：'+text(d.note,'取消说明'),0);
}else if(e.action==='install'){
 manager();check(s.scene.mode==='停站','设备在停站时安装');check(!s.facilities.some(function(f){return f.name===d.name;}),'设施已经安装');consume(items(d.items));s.facilities.push({name:text(d.name,'设备'),status:'可用',use:text(d.use,'用途')});record('设施',d.name+'安装完成',0);
}else if(e.action==='repair'){
 manager();var f=s.facilities.filter(function(f){return f.name===d.name;})[0];check(!!f,'设施不存在');var materials=items(d.materials);if(professional(d.memberId,'机械师'))Object.keys(materials).forEach(function(name){if(d.indivisible.indexOf(name)<0)materials[name]*=.75;});consume(materials);f.status=text(d.status,'维修后的状态');record('维修',text(d.note,'维修说明'),0);
}else if(e.action==='setScene'){
 manager();s.scene.title=text(d.title,'当前场景');s.scene.description=text(d.description,'已公开的情况');check(['宽松','忙碌','拥挤'].indexOf(d.crowding)>=0,'接待状态无效');s.scene.crowding=d.crowding;
}else if(e.action==='setFacility'){
 manager();var f=s.facilities.filter(function(f){return f.name===d.name;})[0];check(!!f,'设施不存在');f.status=text(d.status,'设施状态');f.use=text(d.use,'用途');record('设施',text(d.note,'实际调整说明'),0);
}else if(e.action==='setEvent'){
 manager();s.event={title:text(d.title,'事件'),progress:text(d.progress,'进展'),known:d.known};check(Array.isArray(d.known)&&d.known.length<=100,'公开信息最多 100 项');d.known.forEach(function(v){text(v,'已知事实');});s.secrets=d.secrets;check(Array.isArray(d.secrets)&&d.secrets.length<=100,'幕后事实最多 100 项');d.secrets.forEach(function(v){text(v,'幕后事实');});
}else if(e.action==='resolve'){
 manager();record('裁定',text(d.note,'已经执行的行动及结果'),0);
}else if(e.action==='refund'){
 manager();charge(amount(d.amount,'退款额'),text(d.note,'退款约定'));
}else if(e.action==='init'||e.action==='read'){
 if(!s.phase)s={phase:'setup'};
}else{throw new Error('不支持的操作：'+e.action);}
var protocol='你是安宁列车 DM。群聊承载描述、讨论、自由行动与结果；小程序只保存实际状态和结算。先 readHtmlProgram，再 submitHtmlProgramEvent；传 expectedVersion，重复同一操作复用 eventId，避免重复扣款。后台失败时据真实原因继续协商，不假装成功。普通行动直接成功，有风险才掷骰，不逐分钟推进。不要求打开页面或点击阶段。玩家可在群里选动物和职业，由你代登记。幕后事实只能读私密视图，不能发到群里。到站新客才上车，不凭空给资源；先谈菜单、价格和限制，行动执行后记账。暂未自动化的动物技能、道具、掷骰与种植由你按规则裁定，以 resolve 记录，不能宣称后台已自动计算。';
var actions={configure:'{hostId,players:[{memberId,animal,profession}]} 创建人开局',setCharacter:'{memberId,animal,profession} 营业前绑定角色',arrive:'{station,nextStation}',depart:'{lineConfirmed:true}',setOffers:'{offers:[{name,quantity,price}]} 本站真实有限货物',purchase:'{items:[{name,quantity}],note,memberId?} 商人折扣',supply:'{cost,note,memberId?} 下一路段燃料，只付一次',acquire:'{items:[{name,quantity}],note,executed:true} 实际取得免费物资',board:'{id,name,count,destination,requirements,fare,arrangementConfirmed:true}',alight:'{groupId}',reroute:'{groupId,destination,extraFare,agreed:true}',addOrder:'{id,groupId,title,requirements,servings,price}',deliver:'{orderId,ingredients:[{name,quantity}],baseServings,menu,agreed:true,memberId?} 厨师倍率按同款一批；只交付一单，额外份数保留在订单记录，不自动卖给别人',cancelOrder:'{orderId,note,agreed:true}',install:'{name,use,items:[{name,quantity}]} 消耗已买到的设备或配套用品',repair:'{name,status,materials:[{name,quantity}],indivisible:[name],memberId?,note}',setScene:'{title,description,crowding:宽松|忙碌|拥挤} 不改车站位置',setEvent:'{title,progress,known:[公开事实],secrets:[幕后事实]}',resolve:'{note} 记录实际裁定，不变更钱物',refund:'{amount,note}',pause:'{}',resume:'{}'};
actions.amendOrder='{orderId,title,requirements,servings,price,agreed:true} 修改待交付订单，如松茸版面条';
actions.setFacility='{name,status,use,note} 已落实的临时用途和故障状态';
if(s.phase!=='setup'){
 s.players.forEach(function(p){p.name=member(p.memberId).name;privateViews[p.memberId]={character:p,protocol:'在群聊中讨论并描述行动。DM 根据现场审核，然后由后台结算。页面用于查看状态，不用点阶段推进。'};});
 privateViews[s.hostId]={isHost:true,canEditData:true,canSubmitForPlayers:true,secrets:s.secrets,actions:actions,rules:rules,protocol:protocol};
 if(ctx.ownerId!==s.hostId)privateViews[ctx.ownerId]={isHost:true,canEditData:true,canSubmitForPlayers:true,secrets:s.secrets,actions:actions,rules:rules,protocol:protocol};
}
var view=s.phase==='setup'?{phase:'setup'}:{phase:s.phase,hostId:s.hostId,players:s.players,cash:s.cash,inventory:s.inventory,passengers:s.passengers,orders:s.orders,facilities:s.facilities,scene:s.scene,event:s.event,offers:s.offers,routePaid:s.routePaid,ledger:s.ledger.slice(-50)};
return {state:s,view:view,privateViews:privateViews};
