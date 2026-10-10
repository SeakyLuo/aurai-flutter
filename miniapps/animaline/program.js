if(e.action==='batch'){
 manager();check(Array.isArray(e.data.operations)&&e.data.operations.length>0&&e.data.operations.length<=12,'一次结算需要 1–12 个已确认操作');
 var allowed=['arrive','depart','setOffers','purchase','supply','acquire','board','alight','reroute','addOrder','amendOrder','deliver','cancelOrder','install','repair','setScene','setFacility','setEvent','resolve','refund','checkpoint'];
 var boundaries=e.data.operations.filter(function(op){return op.action==='depart'||op.action==='checkpoint';});check(boundaries.length<=1,'一批最多切换一次上下文');
 e.data.operations.forEach(function(op,index){check(allowed.indexOf(op.action)>=0,'该操作不能批量执行：'+op.action);check(boundaries.indexOf(op)<0||index===e.data.operations.length-1,'保存笔记与切换上下文须放在本批末尾');apply(op.action,op.data);});
}else apply(e.action,e.data);
