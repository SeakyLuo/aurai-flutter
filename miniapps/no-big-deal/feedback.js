const OfficeFeedback = (() => {
  const clips={move:'{{SOUND_MOVE}}',merge:'{{SOUND_MERGE}}',collect:'{{SOUND_COLLECT}}',success:'{{SOUND_SUCCESS}}',select:'{{SOUND_SELECT}}'};
  let enabled=false,paused=false,context=null,ready=null,active=null;
  async function unlock(){
    if(!context)context=new AudioContext();
    if(context.state==='suspended')await context.resume();
    if(!ready)ready=Promise.all(Object.entries(clips).map(async([key,url])=>{
      const binary=atob(url.split(',')[1]),bytes=Uint8Array.from(binary,c=>c.charCodeAt(0));
      return [key,await context.decodeAudioData(bytes.buffer)];
    })).then(entries=>Object.fromEntries(entries));
    return ready;
  }
  function stop(){if(active){active.stop();active.disconnect();active=null;}}
  async function play(key){
    if(!enabled||paused)return;
    const buffers=await unlock();
    // A mute or lifecycle pause can arrive while decoding the bundled clips.
    if(!enabled||paused)return;
    stop();
    const source=context.createBufferSource(),gain=context.createGain();
    source.buffer=buffers[key];gain.gain.value=.35;source.connect(gain);gain.connect(context.destination);
    source.onended=()=>{source.disconnect();gain.disconnect();if(active===source)active=null;};
    active=source;source.start();
  }
  function setEnabled(value){enabled=value;if(!enabled)stop();}
  function pause(){paused=true;stop();}
  function resume(){paused=false;}
  function changed(before,after){
    if(before.status==='playing'&&after.status!=='playing')return after.status==='won'||after.summary?.success?'success':'select';
    if(after.coins>before.coins||after.items.length>before.items.length)return 'collect';
    if(after.stats.merges>before.stats.merges)return 'merge';
    if(after.turn>before.turn)return 'move';
    return 'select';
  }
  function animate(before,after){
    if(matchMedia('(prefers-reduced-motion: reduce)').matches)return;
    const moved=new Set(after.board.flatMap((o,i)=>o&&before.board[i]?.id!==o.id?[o.id]:[]));
    requestAnimationFrame(()=>{
      if(paused)return;
      for(const cell of document.getElementById('board').children){
        const o=after.board[Number(cell.dataset.cell)];
        if(o&&moved.has(o.id))cell.classList.add('file-arrival');
      }
    });
  }
  return {unlock,play,setEnabled,pause,resume,changed,animate};
})();
