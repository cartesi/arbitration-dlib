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

// promisify jsonRPC direct call
sendRPC = function(web3, param){
  let web3Instance = web3
  return new Promise(function(resolve, reject) {
    web3Instance.givenProvider.send(param, function(err, data){
      if(err !== null) return reject(err);
      resolve(data);
    });
  });
}

module.exports = {
  getEvent: getEvent,
  unwrap: unwrap,
  getError: getError,
  sendRPC: sendRPC
}
