const OfficeRules = (() => {
  // Existing NoBigDeal values take precedence; campaign rules complete its placeholders.
  const config = {
    days: 2, moves: 100, patience: 100, penalty: 50,
    targets: [[100, 200, 300], [1000, 1500, 2000]],
    wetTurns: 5, water: 60, wetWeight: 3, glueUses: 3,
    weakGlue: 5, strongGlue: 10, collapse: 6,
    burnTurns: 5, spreadTurns: 2, bombTurns: 8,
    noteChance: .12, demandEvery: 20, slackCost: 5, slackLimit: 5,
    demandTurns:{normal:30,urgent:12,favor:40,chain:30}, demandPenalty:10,
    demandReward:12, urgentReward:18, fatigueTurns:8, nightFatigueTurns:12,
    nightRewardMultiplier:1.3, machineScore:8, startingCoins:20, rareGiftChance:20,
  };
  const phases = ['上午', '下午', '晚上'];
  const zones = {
    water: ['清水', '水', '补充湿润，清除污染；水量自然衰减。'],
    glue: ['胶水', '胶', '触碰即黏着，普通胶 5 步，强力胶 10 步；可用 3 次。'],
    discard: ['废弃', '弃', '文件坠落；只有更重的区外黏着文件才能拉住它。'],
    danger: ['承重危险', '裂', '基础 6 步后塌陷；轻、中、重物经过额外消耗 1、2、3，火焰立即使其塌陷。'],
    pollution: ['污水', '污', '打湿并污染，只显示轮廓和重量，暂停特殊效果；用清水洗净。'],
    approval: ['审批', '审', '合并、附着和收集操作须重复确认，首次不消耗步数。'],
    overtime: ['加班', '班', '每次在这里合并，忍耐度恢复 1。'],
    electricity: ['通电', '电', '金属获得 2 点电量；每步衰减，可启动损坏的机械。'],
    metal: ['金属', '导', '同一片金属区域将电传给最近的金属物品。'],
    fire: ['火焰', '火', '按原逻辑立即去湿、去胶；干燥可燃物燃烧并蔓延。'],
  };
  const kinds = {
    file: ['普通文件', ''], messy: ['杂乱文件', '杂'], urgent: ['紧急文件', '急'],
    waste: ['废弃文件', '废'], copy: ['复印文件', '复'], cancel: ['撤销文件', '撤'],
    metal: ['金属文件', '金'], stone: ['石墩', '石'], rubble: ['碎石', '碎'],
    bomb: ['炸弹', '弹'], magnet: ['马蹄铁', '磁'], machine: ['损坏的整理机', '机'],
    parcel: ['外卖袋', '袋'], prop: ['道具', '具'],
  };
  const items = {
    machine: {name:'损坏的整理机',price:18,target:'cell',description:'放置整理机；传入电量后启动，每次整理 8 份文件。'},
    water: {name:'清水瓶', price:8, target:'cell', description:'在一格铺清水，洗净污染并灭火。'},
    glue: {name:'普通胶', price:8, target:'cell', description:'在一格铺胶水，黏着 5 步。'},
    strongGlue: {name:'强力胶', price:12, target:'cell', description:'在一格铺强力胶，黏着 10 步。'},
    ice: {name:'冰块', price:10, target:'object', description:'冻结物品 3 步，熄灭火焰并暂停炸弹。'},
    lighter: {name:'打火机', price:10, target:'cell', description:'点燃一格；引爆炸弹、脆化石墩、烧毁木支架。'},
    sleeve: {name:'牛皮文件套', price:16, target:'file', attach:true, description:'永久抵挡水、污染、冰和火，与胶水互相抵消。'},
    film: {name:'保护膜', price:8, target:'object', attach:true, description:'抵挡一次胶水、冰、火、水或污染。'},
    woodStand: {name:'木支架', price:8, target:'object', attach:true, description:'固定物品，可拆除或烧毁。'},
    metalStand: {name:'金属支架', price:14, target:'object', attach:true, description:'固定物品，只能拆除。'},
    woodCage: {name:'木笼', price:12, target:'object', attach:true, description:'物品可移动，外壳抵挡水、污染与冰，可烧毁。'},
    metalCage: {name:'金属笼', price:16, target:'object', attach:true, description:'物品可移动，外壳保护并导电。'},
    tape: {name:'胶带', price:5, target:'object', attach:true, description:'固定物品一次，下一次整理后松开。'},
    wheels: {name:'滚轮', price:14, target:'object', attach:true, description:'金属滚轮，解除重量和固定造成的移动限制。'},
    booster: {name:'助推器', price:10, target:'object', attach:true, description:'下一次可无视重量和固定移动。'},
    seal: {name:'封条', price:5, target:'object', attach:true, description:'保洁保留这个物品，点击文件可撕除。'},
    magnet: {name:'马蹄铁', price:18, target:'cell', description:'放置磁铁，整理后沿朝向吸引最近的金属物品。'},
    bomb: {name:'小炸弹', price:10, target:'cell', description:'放置 8 步倒计时炸弹，炸毁最近一格物品。'},
    glove: {name:'绝缘手套', price:18, target:'passive', description:'持有时可以直接移动带电物品。'},
    coffee: {name:'咖啡', price:10, target:'instant', description:'消除一种疲劳。'},
    hamburger: {name:'汉堡', price:10, target:'instant', description:'接下来三次发出的文件均为 1 份。'},
    energy: {name:'能量饮料', price:10, target:'instant', description:'接下来两次行动不会获得疲劳。'},
    snack: {name:'小点心', price:10, target:'instant', description:'老板忍耐度恢复 10。'},
    scissors: {name:'拆除剪', price:8, target:'object', description:'拆除支架、笼子、胶带或封条。'},
  };
  const fatigues = {
    temporary:'合并后原位留下 5 步临时杂物', one:'合并后原位留下 1 份文件',
    food:'食品产生劣质效果', reverse:'拖放方向反转', hidden:'部分文件只显示重量',
    fog:'部分格子被雾遮住', preview:'看不到下一份文件', heavy:'单个文件每次只能移动一格',
    noMerge:'暂时无法合并', noGrowth:'合并得分但份数不增加', trouble:'便签事件更频繁',
  };
  const rarities={normal:'普通',rare:'稀有',favor:'人情专属',night:'夜间专属',logistics:'后勤专属',event:'事件专属'};
  const itemRarity={machine:'logistics',water:'normal',glue:'normal',film:'normal',woodStand:'normal',tape:'normal',coffee:'normal',snack:'normal',
    sleeve:'rare',metalStand:'rare',woodCage:'rare',metalCage:'rare',wheels:'rare',seal:'normal',
    glove:'favor',ice:'night',strongGlue:'night',lighter:'night',bomb:'night',hamburger:'normal',energy:'normal',scissors:'logistics',booster:'event',magnet:'event'};
  const itemLimit = s => 6+(s.welfare.some(w=>w.key==='cabinet')?2:0);
  const fatigue = (s,type) => s.fatigues.find(f=>f.type===type);
  const isFile = o => o && ['file','messy','urgent','waste','copy','cancel','metal'].includes(o.kind);
  const collectible = o => o && ['prop','parcel','magnet'].includes(o.kind);
  const itemKey = o => o.kind==='magnet'?'magnet':o.item;
  const effect = (o,kind) => !o.polluted && o.kind===kind;
  const canAttach = (key,o) => items[key].attach && !o.attach.includes(key) && (items[key].target!=='file'||isFile(o));
  const metal = o => o && (o.kind === 'metal' || o.kind === 'magnet' || o.kind === 'machine' ||
    (o.kind==='prop'&&['metalCage','metalStand','wheels','magnet','machine'].includes(o.item)) || o.attach.some(a=>['metalCage','metalStand','wheels'].includes(a)));
  const weight = o => o.value + (o.wet > 0 ? config.wetWeight : 0) + (metal(o) ? 3 : 0);
  const tier = o => weight(o) <= 31 ? 0 : weight(o) <= 512 ? 1 : weight(o) <= 10000 ? 2 : 3;
  const adjacent = (a,b) => a!==b && Math.abs(a%4-b%4)<=1 && Math.abs(Math.floor(a/4)-Math.floor(b/4))<=1;
  return {itemLimit,fatigue, config, phases, zones, kinds, items, fatigues, rarities, itemRarity, isFile, collectible, itemKey, effect, canAttach, metal, weight, tier, adjacent};
})();
