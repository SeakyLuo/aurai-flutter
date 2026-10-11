// A cancellable worker per move: no model request and no work on the UI thread.
const LocalEngine=(()=>{
  let active=null;
  function cancel(){if(active){active.finish(null);active=null;}}
  function search(view){
    cancel();
    const hiddenXiangqi=GAME==='xiangqi'&&view.mode!=='normal'&&view.mode!==undefined;
    const source=document.getElementById(hiddenXiangqi?'hiddenXiangqiEngineSource':'localEngineSource').textContent;
    const url=URL.createObjectURL(new Blob([JSON.parse(source)],{type:'text/javascript'}));
    const worker=new Worker(url);URL.revokeObjectURL(url);
    return new Promise((resolve,reject)=>{
      let timer=null,best=null;const started=performance.now();
      const job={finish(value,error){
        worker.terminate();clearTimeout(timer);if(active===job)active=null;
        error?reject(error):resolve(value);
      }};
      active=job;
      worker.onerror=event=>{event.preventDefault();job.finish(null,new Error(event.message));};
      worker.onmessage=({data})=>{
        if(data.type==='error'){job.finish(null,new Error(data.message));return;}
        if(data.type==='progress'){
          best=data.move;
          if(timer===null)timer=setTimeout(()=>job.finish(best),Math.max(0,[200,400,800,1500,2500][view.difficulty-1]-(performance.now()-started)));
        }
        if(data.type==='done')job.finish(best);
        if(data.type==='result'){
          const choice=data.forced||data.vcf?data.move:Difficulty.pickMove(data.candidates,view.difficulty).move;
          job.finish({to:[choice%15,Math.floor(choice/15)]});
        }
      };
      if(['tictactoe','reversi','connect4','halma'].includes(GAME)){
        const codes=Object.fromEntries(Object.entries(view.pieceLegend).map(([code,symbol])=>[symbol,code]));
        worker.postMessage({board:view.board.flat().map(p=>p==='·'?null:codes[p]),turn:view.turn,level:view.difficulty,...(GAME==='halma'?{sides:view.players.filter(p=>p.active).map(p=>p.side)}:{})});
      }else if(GAME==='xiangqi'){
        const codes=Object.fromEntries(Object.entries(view.pieceLegend).map(([code,symbol])=>[symbol,code]));
        const board=view.board.map(row=>row.map(p=>p==='·'?null:codes[p]));
        worker.postMessage(hiddenXiangqi?{mode:view.mode,board:board.flat(),players:view.players,unseenPieces:view.unseenPieces,colorsAssigned:view.colorsAssigned,quiet:view.quiet,turn:view.turn,level:view.difficulty,legalMoves:view.legalMoves}:{board,turn:view.turn,level:view.difficulty,legalMoves:view.legalMoves});
      }else{
        // The worker uses alternating first/second roles internally. Map from
        // the actual opening color so white-first games retain the live board.
        const first=[],second=[],firstSymbol=view.pieceLegend[view.firstSide];
        view.board.flat().forEach((p,i)=>{if(p===firstSymbol)first.push(i);else if(p!=='·')second.push(i);});
        const moves=[];first.forEach((p,i)=>{moves.push(p);if(i<second.length)moves.push(second[i]);});
        worker.postMessage({type:'search',seq:1,moves,level:view.difficulty});
      }
    });
  }
  return {search,cancel};
})();
