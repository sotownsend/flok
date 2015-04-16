drivers = window.drivers || {}
drivers.ui = {}

//Create a new surface based on a prototype name and information. Should return a surface pointer
drivers.ui.createSurface = function(protoName, info) {
  var $proto = $("#surface-prototypes").find(".surface[data-name=\'"+protoName+"\']");
  if ($proto.length === 0) {
    throw "Couldn't find a surface prototype named: \(protoName)";
  }

  //Get a UUID, move the surface to the 'body' element and hidden
  var uuid = UUID()
  $proto.attr("data-uuid", uuid);
  $("body").append($proto[0].outerHTML);
  $proto.removeAttr("data-uuid");

  $sel = $("[data-uuid='" + uuid + "']");
  $sel.addClass("hidden");

  //Does this have a controller?
  var scc = drivers.ui.scc[protoName];
  var pipe = {
    sendEvent: function(name, info) {
      var source = drivers.ui.createSurface("login");
      var dest = $("#root-surface");
      drivers.ui.embedSurface(source, dest, "main", false, null);
    }
  };
  if (scc != undefined) {
    new scc($sel, info, pipe);
  }

  //Our surface pointers are selectors
  return $sel
}

//Delete a surface which removes it from the UI
drivers.ui.deleteSurface = function(sp) {
  sp.remove();
}

//Embed a surface into another surface in the view with the correct name
//source_sp - The surface we are embedding
//dest_sp - The surface we are embedding into
//animated - If true, a segue is allowed to take place
//animationDidComplete - Call this funtction if animated is true when you are done animating.
drivers.ui.embedSurface = function(source_sp, dest_sp, viewName, animated, animationDidComplete) {
  //Lookup view selector
  var $view = dest_sp.find(".view[data-name=" + viewName + "]");
  if ($view.length === 0) {
    throw "Found surface, but couldn't find a view *inside* a surface named: " + viewName;
  }

  source_sp.appendTo($view);
  source_sp.removeClass('hidden');
}

//Surface controller constructors
drivers.ui.scc = {};
drivers.ui.regController = function(surfaceName, constructor) {
  drivers.ui.scc[surfaceName] = constructor;
}
