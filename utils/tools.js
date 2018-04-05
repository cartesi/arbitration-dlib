const getEvent = function(result, eventName) {
  for (var i = 0; i < result.logs.length; i++) {
    var log = result.logs[i];
    if (log.event == eventName) {
      return log.args
      break;
    }
  }
  throw "Event not found";
}


const unwrap = function(promise) {
   return promise.then(data => {
      return [null, data];
   })
   .catch(err => [err]);
}

const getError = async function(promise) {
  [error, response] = await unwrap(promise);
  if (error === null) return "";
  if (!('message' in error)) return "";
  return error.message;
}

const timeTravel = function (time) {
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [time],
      id: new Date().getSeconds()
    }, (err, resp) => {
      if (!err) {
        web3.currentProvider.send({
          jsonrpc: '2.0',
          method: 'evm_mine',
          params: [],
          id: new Date().getSeconds()
        })
      }
    });
  })
}

module.exports = {
  getEvent: getEvent,
  unwrap: unwrap,
  getError: getError,
  timeTravel:timeTravel
}
