function apply(action,data){var d=data;
function wake(note){host.call('messages.send',{text:note,audience:[s.hostId],wakeAi:true,wakeMemberIds:[s.hostId]});}
if(action==='configure'){
 check(e.actorId===ctx.ownerId||e.actorId==='user:local','只有创建人可以开始旅程');check(!s.phase||s.phase==='setup','已有旅程，请继续当前旅程');
 check(member(d.hostId).kind==='agent','请选择主持 AI');check(Array.isArray(d.players)&&d.players.length>=1&&d.players.length<=12,'选择 1–12 位玩家');
 var used={};d.players.forEach(function(p){member(p.memberId);check(p.memberId!==d.hostId&&!used[p.memberId],'主持人不能兼任玩家，玩家不能重复');used[p.memberId]=true;check(rules.animals.some(function(a){return a.name===p.animal;})&&rules.professions.some(function(a){return a.name===p.profession;}),'请选择已开放的动物和职业');});
 s={phase:'active',hostId:d.hostId,players:d.players.map(function(p){return {memberId:p.memberId,name:member(p.memberId).name,animal:p.animal,profession:p.profession};}),cash:30,inventory:JSON.parse(JSON.stringify(rules.inventory)),passengers:JSON.parse(JSON.stringify(rules.passengers)),orders:JSON.parse(JSON.stringify(rules.orders)),facilities:rules.facilities.slice(),scene:{mode:'行驶中',station:'',nextStation:'松岭',title:'午餐营业',description:'三组乘客提出了午餐需求。玩家在群聊中讨论菜单和分工。',crowding:'宽松'},event:{title:'',progress:'',known:[]},secrets:[],offers:[],routePaid:false,ledger:[],seq:0,journal:{commitments:[],clues:[],relationships:[],ongoing:[]}};
 host.call('messages.mark',{});host.call('messages.pin',{});wake('安宁列车旅程已建立。使用当前运行时状态，缺少状态时再读取，在群聊介绍角色、三张午餐需求与当前库存，邀请玩家商量分工。不要让玩家通过页面点阶段推进。');
}else if(action==='resume'){
 check(e.actorId===s.hostId||e.actorId===ctx.ownerId,'只有主持人或创建人可以恢复');check(s.phase==='paused','当前未暂停');s.phase='active';wake('旅程恢复，请根据保存状态在群聊继续。');
}else if(action==='pause'){
 manager();checkpoint(d.journal);s.phase='paused';record('旅程','暂停旅程',0);
}else if(action==='setCharacter'){
 check(s.phase==='active','旅程尚未开始或已暂停');var id=d.memberId;check(e.actorId===id||e.actorId===s.hostId||e.actorId===ctx.ownerId,'只能选择自己的角色');var p=character(id);
 check(!s.ledger.some(function(row){return row.kind!=='角色';}),'营业开始后不再改换技能');check(rules.animals.some(function(a){return a.name===d.animal;})&&rules.professions.some(function(a){return a.name===d.profession;}),'动物或职业未开放');p.animal=d.animal;p.profession=d.profession;record('角色',p.name+'选择了'+p.animal+' · '+p.profession,0);
}else if(action==='arrive'){
 manager();check(s.scene.mode==='行驶中'&&d.station===s.scene.nextStation,'请按当前目的站抵达');s.scene.mode='停站';s.scene.station=d.station;s.scene.nextStation=text(d.nextStation,'下一站');s.routePaid=false;s.offers=[];record('到站','抵达'+d.station,0);
}else if(action==='depart'){
 manager();check(s.scene.mode==='停站','当前不在车站');check(d.lineConfirmed===true,'离站前需站方确认路段通行');check(s.routePaid,'尚未完成下一段牵引燃料补给');checkpoint(d.journal);s.scene.mode='行驶中';s.offers=[];record('出发','离开'+s.scene.station+'，前往'+s.scene.nextStation,0);
}else if(action==='setOffers'){
 manager();check(s.scene.mode==='停站','供应商只能在停站时提供');check(Array.isArray(d.offers)&&d.offers.length<=100,'供应清单最多 100 项');var names={};
 d.offers.forEach(function(o){text(o.name,'商品');check(!names[o.name],'商品重复');names[o.name]=true;count(o.quantity,'供应数量');amount(o.price,'单价');});s.offers=d.offers;
}else if(action==='purchase'){
 manager();check(s.scene.mode==='停站','离站后不能购买站内商品');var requested=items(d.items),cost=0;
 Object.keys(requested).forEach(function(name){var offer=s.offers.filter(function(o){return o.name===name;})[0];check(!!offer&&offer.quantity>=requested[name],'商家库存不足：'+name);cost+=offer.price*requested[name];});
 if(professional(d.memberId,'商人'))cost*=.9;charge(cost,text(d.note,'采购说明'));
 s.offers.forEach(function(o){if(requested[o.name]!==undefined)o.quantity-=requested[o.name];});receive(requested);
}else if(action==='supply'){
 manager();check(s.scene.mode==='停站'&&!s.routePaid,'当前不能重复补给');var cost=amount(d.cost,'路段补给价格');if(professional(d.memberId,'商人'))cost*=.9;charge(cost,text(d.note,'补给说明'));s.routePaid=true;
}else if(action==='acquire'){
 manager();check(d.executed===true,'审核通过不等于取得物资，请先执行');var obtained=items(d.items);text(d.note,'来源与实际行动');receive(obtained);record('取得物资',d.note,0);
}else if(action==='board'){
 manager();check(s.scene.mode==='停站','新乘客只能在车站上车');check(d.arrangementConfirmed===true,'先确认接待方案');text(d.id,'乘客组标识');check(!s.passengers.some(function(p){return p.id===d.id;}),'该乘客组已登记');count(d.count,'乘客数');amount(d.fare,'每人票价');
 var passenger={id:d.id,name:text(d.name,'同行组名称'),count:d.count,destination:text(d.destination,'目的站'),requirements:text(d.requirements,'已约定的需求'),onboard:true};s.passengers.push(passenger);income(d.count*d.fare,passenger.name+'购票至'+passenger.destination);
}else if(action==='alight'){
 manager();check(s.scene.mode==='停站','乘客到站才能下车');var passenger=group(d.groupId);check(passenger.onboard&&passenger.destination===s.scene.station,'乘客尚未到约定目的站');passenger.onboard=false;record('下客',passenger.name+'在'+s.scene.station+'下车',0);
}else if(action==='reroute'){
 manager();var passenger=group(d.groupId);check(passenger.onboard&&d.agreed===true,'需在车乘客同意改程');var fare=amount(d.extraFare,'每人补票款');passenger.destination=text(d.destination,'新目的站');income(passenger.count*fare,passenger.name+'改程补票');
}else if(action==='addOrder'){
 manager();check(group(d.groupId).onboard,'订单乘客已下车');check(!s.orders.some(function(o){return o.id===d.id;}),'订单已存在');text(d.id,'订单标识');count(d.servings,'份数');amount(d.price,'已约定总餐费');
 s.orders.push({id:d.id,groupId:d.groupId,title:text(d.title,'订单名称'),requirements:text(d.requirements,'饮食要求'),servings:d.servings,price:d.price,status:'待交付'});
}else if(action==='amendOrder'){
 manager();var o=order(d.orderId);check(o.status==='待交付'&&d.agreed===true,'只能协商修改待交付订单');o.title=text(d.title,'订单名称');o.requirements=text(d.requirements,'饮食要求');o.servings=count(d.servings,'份数');o.price=amount(d.price,'重新约定总餐费');record('订单',o.title+'的菜单与价格已重新协商',0);
}else if(action==='deliver'){
 manager();var o=order(d.orderId);check(o.status==='待交付','订单不能重复交付');check(d.agreed===true,'实际菜单需乘客同意');count(d.baseServings,'本批普通份数');var made=professional(d.memberId,'厨师')?Math.floor(d.baseServings*1.25):d.baseServings;
 check(made>=o.servings,'本批餐食不足约定份数');consume(items(d.ingredients));o.status='已交付';o.menu=text(d.menu,'实际菜单');o.produced=made;o.extraServings=made-o.servings;income(o.price,o.title+'交付');
}else if(action==='cancelOrder'){
 manager();var o=order(d.orderId);check(o.status==='待交付','该订单不能取消');check(d.agreed===true,'取消需与乘客协商');o.status='已取消';record('订单',o.title+'：'+text(d.note,'取消说明'),0);
}else if(action==='install'){
 manager();check(s.scene.mode==='停站','设备在停站时安装');check(!s.facilities.some(function(f){return f.name===d.name;}),'设施已经安装');consume(items(d.items));s.facilities.push({name:text(d.name,'设备'),status:'可用',use:text(d.use,'用途')});record('设施',d.name+'安装完成',0);
}else if(action==='repair'){
 manager();var f=s.facilities.filter(function(f){return f.name===d.name;})[0];check(!!f,'设施不存在');var materials=items(d.materials);if(professional(d.memberId,'机械师'))Object.keys(materials).forEach(function(name){if(d.indivisible.indexOf(name)<0)materials[name]*=.75;});consume(materials);f.status=text(d.status,'维修后的状态');record('维修',text(d.note,'维修说明'),0);
}else if(action==='setScene'){
 manager();s.scene.title=text(d.title,'当前场景');s.scene.description=text(d.description,'已公开的情况');check(['宽松','忙碌','拥挤'].indexOf(d.crowding)>=0,'接待状态无效');s.scene.crowding=d.crowding;
}else if(action==='setFacility'){
 manager();var f=s.facilities.filter(function(f){return f.name===d.name;})[0];check(!!f,'设施不存在');f.status=text(d.status,'设施状态');f.use=text(d.use,'用途');record('设施',text(d.note,'实际调整说明'),0);
}else if(action==='setEvent'){
 manager();s.event={title:text(d.title,'事件'),progress:text(d.progress,'进展'),known:d.known};check(Array.isArray(d.known)&&d.known.length<=100,'公开信息最多 100 项');d.known.forEach(function(v){text(v,'已知事实');});s.secrets=d.secrets;check(Array.isArray(d.secrets)&&d.secrets.length<=100,'幕后事实最多 100 项');d.secrets.forEach(function(v){text(v,'幕后事实');});
}else if(action==='checkpoint'){
 manager();checkpoint(d.journal);
}else if(action==='resolve'){
 manager();record('裁定',text(d.note,'已经执行的行动及结果'),0);
}else if(action==='refund'){
 manager();charge(amount(d.amount,'退款额'),text(d.note,'退款约定'));
}else if(action==='init'||action==='read'){
 if(!s.phase)s={phase:'setup'};
}else{throw new Error('不支持的操作：'+action);}
}
