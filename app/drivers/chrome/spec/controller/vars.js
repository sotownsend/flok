//Tests various control variables, like info

$(document).ready(function() {
  QUnit.test("Controller does receive info on explicit init", function(assert) {
    var done = assert.async();

    //Create a test controller
    var TestController = function() {
      this.base = FlokController; this.base(); self = this;

      self.init = function() {
        assert.equal(this.info.hello, "world", "Matches");
        done();
      }
    }

    //Insert some HTML
    $("body").html("              \
      <div id='root'>             \
        <div id='test'></div>     \
      </div>                      \
    ");

    //Call the controllers init with a forged selector
    $sel = $("#test");
    var c = new TestController();
    c.__initialize__(0, $sel, {hello: 'world'});
    c.init();
  });

  QUnit.test("Controller does receive info on if_controller_init", function(assert) {
    var done = assert.async();

    //Create a test controller
    var TestController = function() {
      this.base = FlokController; this.base(); self = this;

      self.init = function() {
        assert.equal(this.info.hello, "world", "Matches");
        done();
      }
    }
    regController("test", TestController)

    //Insert some HTML
    $("body").html("              \
      <div id='root'>             \
        <div id='test'></div>     \
      </div>                      \
    ");

    //Call the controllers init with a forged selector
    $sel = $("#test");
    if_ui_tp_to_selector[1] = $sel;
    if_controller_init(0, 1, "test", {hello: 'world'});
  });

});
