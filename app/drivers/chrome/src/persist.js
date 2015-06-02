function if_per_set(ns, key, value) {
  var _ns = store.namespace(ns);
  _ns.set(key, value)
}

function if_per_del(ns, key) {
  var _ns = store.namespace(ns);
  _ns.remove(key);
}

function if_per_del_ns(ns) {
  var _ns = store.namespace(ns);
  _ns.clearAll();
}

function if_per_get(s, ns, key) {
  function async() {
    var _ns = store.namespace(ns);
    var res = _ns.get(key);
    int_dispatch([2, "int_per_get_res", s, res]);
  }
  setTimeout(async, 0);
}

function if_per_get_sync(s, ns, key) {
  var _ns = store.namespace(ns);
  var res = _ns.get(key);
  int_dispatch([2, "int_per_get_res", s, res]);
}