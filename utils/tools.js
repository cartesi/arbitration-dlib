function getEvent(result, eventName) {
  for (var i = 0; i < result.logs.length; i++) {
    var log = result.logs[i];
    if (log.event == eventName) {
      return log.args
      break;
    }
  }
  throw "Event not found";
}


function unwrap(promise) {
   return promise.then(data => {
      return [null, data];
   })
   .catch(err => [err]);
}

async function shouldThrow(promise) {
  [error, response] = await unwrap(promise);
  expect(error.message).to.have.string('VM Exception');
}

module.exports = {
  getEvent: getEvent,
  unwrap: unwrap,
  shouldThrow: shouldThrow
}
