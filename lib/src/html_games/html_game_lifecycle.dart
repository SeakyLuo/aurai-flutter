/// Installed before page scripts so timers belong to the page lifecycle.
const htmlGameLifecycleScript = r'''
(()=>{
  const nativeTimeout=window.setTimeout.bind(window), nativeClear=window.clearTimeout.bind(window);
  const nativeFrame=window.requestAnimationFrame.bind(window), nativeCancel=window.cancelAnimationFrame.bind(window);
  const timers=new Map(), frames=new Map();
  let serial=0, paused=false;
  let saved=JSON.parse(AuraiGameBridge.loadState());
  window.AuraiHTML=Object.freeze({
    get state(){return structuredClone(saved)},
    async saveState(value){
      const json=JSON.stringify(value);
      if(json===undefined) throw new Error('State must be JSON-compatible');
      if(!AuraiGameBridge.saveState(json)) throw new Error('State save failed: stateful must be enabled and state must fit within 64 KB');
      saved=JSON.parse(json);
    }
  });
  const schedule=(id,t)=>{
    t.started=performance.now();
    t.handle=nativeTimeout(()=>{
      if(paused || !timers.has(id)) return;
      if(!t.repeat) timers.delete(id);
      try { if(typeof t.fn==='function') t.fn(...t.args); else (0,eval)(String(t.fn)); }
      finally { if(t.repeat && timers.has(id)){t.remaining=t.delay;if(!paused)schedule(id,t)} }
    },t.remaining);
  };
  const add=(fn,delay,repeat,args)=>{
    const id=++serial, wait=Math.max(0,Number(delay)||0);
    const timer={fn,args,repeat,delay:wait,remaining:wait,handle:null,started:0};
    timers.set(id,timer);if(!paused)schedule(id,timer);return id;
  };
  window.setTimeout=(fn,delay,...args)=>add(fn,delay,false,args);
  window.setInterval=(fn,delay,...args)=>add(fn,delay,true,args);
  window.clearTimeout=window.clearInterval=id=>{
    const timer=timers.get(id);if(timer){nativeClear(timer.handle);timers.delete(id)}
  };
  const scheduleFrame=(id,frame)=>{frame.handle=nativeFrame(time=>{
    if(!frames.has(id))return;
    frames.delete(id);frame.fn(time);
  })};
  window.requestAnimationFrame=fn=>{
    const id=++serial,frame={fn,handle:null};frames.set(id,frame);
    if(!paused)scheduleFrame(id,frame);return id;
  };
  window.cancelAnimationFrame=id=>{
    const frame=frames.get(id);if(frame){nativeCancel(frame.handle);frames.delete(id)}
  };
  window.__auraiLifecycle=value=>{
    if(paused===value)return;
    paused=value;
    document.documentElement.dataset.auraiPaused=String(paused);
    if(paused){
      for(const timer of timers.values()){
        nativeClear(timer.handle);
        timer.remaining=Math.max(0,timer.remaining-(performance.now()-timer.started));
      }
      for(const frame of frames.values())nativeCancel(frame.handle);
      document.querySelectorAll('audio,video').forEach(media=>media.pause());
      document.dispatchEvent(new Event('aurai:pause'));
    }else{
      for(const [id,timer] of timers) schedule(id,timer);
      for(const [id,frame] of frames) scheduleFrame(id,frame);
      document.dispatchEvent(new Event('aurai:resume'));
    }
  };
})();
''';
