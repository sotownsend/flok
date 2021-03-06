#Specifically about the find_view releated (selector) functions

Dir.chdir File.join File.dirname(__FILE__), '../../'
require './spec/env/kern.rb'
require './spec/lib/helpers.rb'
require './spec/lib/io_extensions.rb'
require './spec/lib/rspec_extensions.rb'

RSpec.describe "kern:find_view_spec" do
  include_context "kern"

  it "Can call the find_view function" do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller0.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    base = ctx.eval("base")
  end

  it "The find_view returns the sub-controller's named basepointer" do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller0.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller2_base = ctx.eval("JSON.stringify(my_controller2_base)")

    expect(find_view_res).to eq({
      "foo" => my_controller2_base.to_i
    }.to_json)
  end

  it "The find_view can return two subviews of different spots" do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller1.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller2_base = ctx.eval("JSON.stringify(my_controller2_base)")
    my_controller3_base = ctx.eval("JSON.stringify(my_controller3_base)")

    expect(find_view_res).to eq({
      "foo" => my_controller2_base.to_i,
      "foo2" => my_controller3_base.to_i
    }.to_json)
  end

  it "The find_view can return two subviews of different spots at different points in the hierarchy" do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller1a.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller2_base = ctx.eval("JSON.stringify(my_controller2_base)")
    my_controller3_base = ctx.eval("JSON.stringify(my_controller3_base)")

    expect(find_view_res).to eq({
      "foo" => my_controller2_base.to_i,
      "foo2" => my_controller3_base.to_i
    }.to_json)
  end


  it "The find_view can return an immediate ." do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller2.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller2_base = ctx.eval("JSON.stringify(my_controller2_base)")

    expect(find_view_res).to eq({
      "foo" => my_controller2_base.to_i,
    }.to_json)
  end

  it "The find_view can return a concrete nested followed by a ." do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller3.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller3_base = ctx.eval("JSON.stringify(my_controller3_base)")

    expect(find_view_res).to eq({
      "foo" => my_controller3_base.to_i,
    }.to_json)
  end

  it "The find_view can return a . followed by a concrete nested" do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller4.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller3_base = ctx.eval("JSON.stringify(my_controller3_base)")

    expect(find_view_res).to eq({
      "foo" => my_controller3_base.to_i,
    }.to_json)
  end


  it "The find_view can return a + followed by a concrete nested for 4 views" do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller5.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller4_base = ctx.eval("JSON.stringify(my_controller4_base)")

    expect(find_view_res).to eq({
      "foo" => my_controller4_base.to_i,
    }.to_json)
  end

  it "The find_view can return a + followed by a concrete nested for 3 views" do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller6.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller3_base = ctx.eval("JSON.stringify(my_controller3_base)")

    expect(find_view_res).to eq({
      "foo" => my_controller3_base.to_i,
    }.to_json)
  end

  it "The find_view can return a + followed by a . match" do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller7.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller3_base = ctx.eval("JSON.stringify(my_controller3_base)")

    expect(find_view_res).to eq({
      "foo" => my_controller3_base.to_i,
    }.to_json)
  end

  it "The find_view can return a . followed by + followed by a . match" do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller8.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller2_base = ctx.eval("JSON.stringify(my_controller2_base)")
    my_controller4_base = ctx.eval("JSON.stringify(my_controller4_base)")

    expect(find_view_res).to eq({
      "foo1" => my_controller2_base.to_i,
      "foo2" => my_controller4_base.to_i,
    }.to_json)
  end

  it "The find_view can return a . . followed by + followed by a . match" do
    #Compile the controller
    ctx = flok_new_user File.read('./spec/kern/assets/find_view/controller9.rb')

    #Run the embed function
    ctx.eval %{
      //Call embed on main root view
      base = _embed("my_controller", 0, {}, null);

      //Drain queue
      int_dispatch([]);
    }

    find_view_res = ctx.eval("JSON.stringify(find_view_res)")
    my_controller3_base = ctx.eval("JSON.stringify(my_controller3_base)")
    my_controller5_base = ctx.eval("JSON.stringify(my_controller5_base)")

    expect(find_view_res).to eq({
      "foo1" => my_controller3_base.to_i,
      "foo2" => my_controller5_base.to_i,
    }.to_json)
  end

end
