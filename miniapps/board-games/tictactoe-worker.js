self.onmessage=function(event) {
  var data=event.data;
  self.postMessage({type:'progress',move:Chess.bestMove(data.board,data.turn)});
  self.postMessage({type:'done'});
};
