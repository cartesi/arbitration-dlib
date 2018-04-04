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

module.exports = {
  getEvent: getEvent
}

//export default getEvent;
