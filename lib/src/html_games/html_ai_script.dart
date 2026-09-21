/// Installed before the frozen AuraiHTML facade. Never carries credentials.
const htmlAiScript = r'''
(()=>{
  let serial=0;
  const pending=new Map();
  const timeout=window.setTimeout.bind(window),clear=window.clearTimeout.bind(window);
  const failure=(message,code)=>Object.assign(new Error(message),{code});
  const finish=(id,value)=>{
    const entry=pending.get(id);if(!entry)return;
    pending.delete(id);clear(entry.timer);entry.cleanup();
    value.error?entry.reject(failure(value.error,value.code)):entry.resolve(value);
  };
  window.__auraiAiReply=finish;
  document.addEventListener('aurai:pause',()=>{
    for(const id of pending.keys()){
      AuraiGameBridge.cancelAi(id);
      finish(id,{error:'AI 请求已取消',code:'cancelled'});
    }
  });
  window.__auraiAiUpdate=(id,text)=>{
    const entry=pending.get(id);if(!entry?.onText)return;
    try{entry.onText(text)}catch(error){console.error('AI onText callback failed',error)}
  };
  const request=(args,{signal,onText}={})=>new Promise((resolve,reject)=>{
    if(signal?.aborted){reject(failure('AI 请求已取消','cancelled'));return}
    const id=++serial;
    const cancel=()=>{
      AuraiGameBridge.cancelAi(id);
      finish(id,{error:'AI 请求已取消',code:'cancelled'});
    };
    const timer=timeout(()=>{
      AuraiGameBridge.cancelAi(id);
      finish(id,{error:'AI 请求超时，请重试',code:'timeout'});
    },130000);
    pending.set(id,{resolve,reject,onText,timer,cleanup:()=>signal?.removeEventListener('abort',cancel)});
    signal?.addEventListener('abort',cancel,{once:true});
    try{AuraiGameBridge.ai(id,JSON.stringify({...args,streamUpdates:typeof onText==='function'}))}
    catch(error){finish(id,{error:'AI 接口不可用',code:'unavailable'})}
  });
  window.__auraiAi=Object.freeze({
    version:1,
    getStatus(){return request({operation:'status'})},
    complete({messages,responseFormat='text',maxOutputTokens=4096},options={}){
      return request({operation:'complete',messages,responseFormat,maxOutputTokens},options);
    }
  });
})();
''';
