const OfficeItemUI = (() => {
  const paths={
    duplicator:'M8 7V4a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v12M5 7h9l3 3v10H5zM14 7v4h3M8 14h6M8 17h6',
    paperKnife:'m5 17 11-12 4 4L9 20l-5 1zM13 8l4 4M5 17l4 3M16 5l2-2 4 4-2 2',
    stapler:'M3 18h18v3H3zM4 17l1-5 14-6 2 5-13 6zM5 12l-1-4 12-5 3 3M8 17v1M18 12v6',
    requisition:'M7 5H4v16h10M10 5h4V3H7v2h3M7 10h3M7 14h2M19 16l3 4M15 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10',
    dispatch:'M3 3h12v6M3 3v18h12v-5M6 7h5M6 11h3M10 13h11m-4-4 4 4-4 4',
    water:'M9 3h6v4l3 4v9H6v-9l3-4zM9 7h6M12 12c-4 4-3 6 0 6s4-2 0-6',
    glue:'M10 3h4v4l3 3v11H7V10l3-3zM10 7h4M9 13h6M9 17h6',
    strongGlue:'M10 3h4v4l3 3v11H7V10l3-3zM10 7h4M9 15h6M12 12v6',
    ice:'m12 2 8 5v10l-8 5-8-5V7zM4 7l8 5 8-5M12 12v10M8 7l4-2',
    lighter:'M7 11h10v10H7zM9 11V8h6v3M12 2c-5 5 3 7 2 2M10 15h4',
    film:'M4 4h16v16H4zM7 7l10 10M17 7 7 17M16 20v-4h4',
    woodStand:'M5 4h14v4H5zM8 8v10M16 8v10M4 21h16M8 13h8',
    metalStand:'M5 4h14v4H5zM8 8v10M16 8v10M4 21h16M8 10l8 8M16 10l-8 8',
    woodCage:'M4 7h16v13H4zM4 7l8-4 8 4M8 7v13M16 7v13',
    metalCage:'M4 7h16v13H4zM4 7l8-4 8 4M8 7v13M16 7v13M4 13h16',
    tape:'M12 3a7 7 0 1 0 7 7v10h-7M12 7a3 3 0 1 0 0 6 3 3 0 0 0 0-6M12 17v3h7',
    wheels:'M5 17a3 3 0 1 0 0 6 3 3 0 0 0 0-6M19 17a3 3 0 1 0 0 6 3 3 0 0 0 0-6M3 14h18M6 14V5h12v9M9 8h6',
    booster:'M9 16H5l2-6h3M15 16h4l-2-6h-3M9 16V7l3-5 3 5v9zM10 19l2 3 2-3',
    seal:'M5 3h14v9H5zM8 7h8M12 10l3 3-3 3-3-3zM10 16v6l2-2 2 2v-6',
    magnet:'M4 4h5v10a3 3 0 0 0 6 0V4h5v10a8 8 0 0 1-16 0zM4 8h5M15 8h5',
    bomb:'M10 7h5v3M13 7V4h5M19 2l2 2M20 7h2M12 9a6 6 0 1 0 0 12 6 6 0 0 0 0-12M8 13l1-1',
    glove:'M7 12V6a1.5 1.5 0 0 1 3 0v5-7a1.5 1.5 0 0 1 3 0v7-6a1.5 1.5 0 0 1 3 0v7-4a1.5 1.5 0 0 1 3 0v8l-3 5H9l-6-7a2 2 0 0 1 3-2l3 3',
    hamburger:'M3 10c0-9 18-9 18 0zM3 14h18M3 18h18c0 5-18 5-18 0M8 6h1M14 7h1',
    energy:'M8 3h8M7 6h10v15H7zM13 9l-3 5h4l-3 5',
    snack:'M4 10c-2-5 4-8 8-5 5-3 10 0 8 5v10H4zM8 13h1M14 15h1M9 18h1',
    scissors:'M6 13a4 4 0 1 0 0 8 4 4 0 0 0 0-8M18 13a4 4 0 1 0 0 8 4 4 0 0 0 0-8M8 14 18 3M16 14 6 3',
    machine:'M4 8h16v13H4zM7 8V3h10v5M7 16h10M16 11h1M7 12h3',
  };
  function icon(key){
    const raster={coffee:art.coffee,sleeve:art.sleeve,woodCage:art.cage,duplicator:'{{ART_TOOL_DUPLICATOR}}',paperKnife:'{{ART_TOOL_PAPER_KNIFE}}',stapler:'{{ART_TOOL_BINDING_PRESS}}',requisition:'{{ART_TOOL_REQUISITION}}',dispatch:'{{ART_TOOL_DISPATCH}}'};
    if(raster[key]){const img=el('img',null);img.src=raster[key];img.alt='';img.draggable=false;return img;}
    const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
    for(const [k,v] of Object.entries({viewBox:'0 0 24 24',fill:'none',stroke:'currentColor','stroke-width':'1.65','stroke-linecap':'round','stroke-linejoin':'round','aria-hidden':'true'}))svg.setAttribute(k,v);
    const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',paths[key]);svg.append(path);return svg;
  }
  const spoiled={water:'使用后产生污水。',strongGlue:'仅有普通胶效果。',coffee:'消除一种疲劳，下次合并产生疲劳。',snack:'恢复 5 忍耐度。',hamburger:'下两份为 1，额外留下临时文件。',energy:'保护一次行动，结束后获得疲劳。'};
  function description(entry){
    if(entry.polluted)return '受污染，不能直接使用。点击后放回桌面，用清水洗净再收集。';
    return entry.spoiled?spoiled[entry.key]:R.items[entry.key].description;
  }
  let anchor=null;
  function hide(){if(anchor)anchor.removeAttribute('aria-describedby');anchor=null;$('itemInfo').hidden=true;}
  function show(b,entry){
    hide();anchor=b;const info=R.items[entry.key],box=$('itemInfo');
    box.replaceChildren(el('strong',info.name),el('p',description(entry)),el('small',[
      R.rarities[R.itemRarity[entry.key]],entry.rental==='phase'?'本阶段租用':entry.rental==='day'?'今日租用':info.target==='passive'?'持有生效':'点击使用',
      ...(OfficeTools.has(entry.key)?['不消耗整理次数，不补牌，不推进倒计时；直接变化不计合并分。']:[])
    ].join(' · ')));
    box.hidden=false;b.setAttribute('aria-describedby','itemInfo');
    const bounds=$('officeGame').getBoundingClientRect(),r=b.getBoundingClientRect(),width=Math.min(250,bounds.width-16);
    box.style.width=width+'px';box.style.left=Math.max(bounds.left+8,Math.min(r.left+r.width/2-width/2,bounds.right-width-8))+'px';
    box.style.top=Math.max(8,r.top-box.getBoundingClientRect().height-8)+'px';
  }
  function bind(b,entry,activate){
    let timer=0,start=null,suppress=false;
    const clear=()=>{clearTimeout(timer);timer=0;};
    b.setAttribute('aria-label',R.items[entry.key].name+(entry.polluted?'，受污染':entry.spoiled?'，变质':'')+'；长按查看详情');
    b.onclick=e=>{if(suppress){suppress=false;e.preventDefault();return;}hide();if(!busy)activate();};
    b.onpointerdown=e=>{
      if(e.button!==0)return;clear();hide();suppress=false;start={x:e.clientX,y:e.clientY};
      timer=setTimeout(()=>{timer=0;suppress=true;show(b,entry);},450);
    };
    b.onpointermove=e=>{if(start&&Math.hypot(e.clientX-start.x,e.clientY-start.y)>8){clear();suppress=true;hide();}};
    b.onpointerup=()=>{clear();start=null;};
    b.onpointercancel=()=>{clear();start=null;suppress=true;hide();};
    b.onlostpointercapture=clear;
    b.onpointerleave=()=>{clear();start=null;};
    b.oncontextmenu=e=>{e.preventDefault();clear();suppress=true;show(b,entry);};
    b.onkeydown=e=>{if(e.key==='F1'||(e.shiftKey&&e.key==='F10')){e.preventDefault();show(b,entry);}if(e.key==='Escape')hide();};
    b.onblur=hide;
  }
  function init(){
    document.addEventListener('pointerdown',e=>{if(anchor&&!anchor.contains(e.target))hide();},true);
    document.addEventListener('scroll',hide,true);window.addEventListener('resize',hide);
    document.addEventListener('visibilitychange',()=>{if(document.hidden)hide();});
  }
  return {icon,description,bind,hide,init};
})();
