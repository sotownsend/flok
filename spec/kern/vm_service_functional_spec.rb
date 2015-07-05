#This contains tests for the 'functions' of the vm service system

Dir.chdir File.join File.dirname(__FILE__), '../../'
require './spec/env/kern.rb'
require './spec/lib/helpers.rb'
require './spec/lib/io_extensions.rb'
require './spec/lib/rspec_extensions.rb'
require 'zlib'

#Evaluates the 
def eval_and_dump str

end

RSpec.describe "kern:vm_service_functional" do
  include Zlib
  include_context "kern"

  it "Can can use vm_create_page" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller0.rb'), File.read("./spec/kern/assets/vm/config5.rb") 
    dump = ctx.evald %{
      dump.new_page = vm_create_page("my_id")
      dump.new_anon_page = vm_create_page();
    }

    expect(dump["new_page"]).to eq({
      "_head" => nil,
      "_next" => nil,
      "_id" => "my_id",
      "entries" => [],
      "__index" => {},
      "_hash" => nil,
    })

    expect(dump["new_anon_page"]["_id"]).not_to eq nil
    expect(dump["new_anon_page"]["entries"]).to eq []
  end

  #vm_rehash_page
  ###########################################################################
  it "vm_rehash_page can calculate the hash correctly" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller0.rb'), File.read("./spec/kern/assets/vm/config3.rb") 

    #Run the check
    res = ctx.eval %{
      //Manually construct a page
      var page = {
        _head: null,
        _next: null,
        _id: "hello",
        entries: [
          {_id: "hello2", _sig: "nohteunth"},
        ]
      }

      vm_rehash_page(page);
    }

    #Calculate hash ourselves
    hash = crc32("hello")
    hash = crc32("nohteunth", hash)
    page = JSON.parse(ctx.eval("JSON.stringify(page)"))
    page = JSON.parse(ctx.eval("JSON.stringify(page)"))

    #Expect the same hash
    expect(page).to eq({
      "_head" => nil,
      "_next" => nil,
      "_id" => "hello",
      "entries" => [
        {"_id" => "hello2", "_sig" => "nohteunth"}
      ],
      "_hash" => hash.to_s
    })
  end

  it "vm_rehash_page can calculate the hash correctly with head and next" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller0.rb'), File.read("./spec/kern/assets/vm/config3.rb") 

    #Run the check
    res = ctx.eval %{
      //Manually construct a page
      var page = {
        _head: "a",
        _next: "b",
        _id: "hello",
        entries: [
          {_id: "hello2", _sig: "nohteunth"},
        ]
      }

      vm_rehash_page(page);
    }

    #Calculate hash ourselves
    hash = crc32("a")
    hash = crc32("b", hash)
    hash = crc32("hello", hash)
    hash = crc32("nohteunth", hash)
    page = JSON.parse(ctx.eval("JSON.stringify(page)"))

    #Expect the same hash
    expect(page).to eq({
      "_head" => "a",
      "_next" => "b",
      "_id" => "hello",
      "entries" => [
        {"_id" => "hello2", "_sig" => "nohteunth"}
      ],
      "_hash" => hash.to_s
    })
  end
  ###########################################################################

  #vm_diff
  ###########################################################################
  it "can use vm_diff with modified entry" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller22.rb'), File.read("./spec/kern/assets/vm/config5.rb") 
    pages_src = File.read("./spec/kern/assets/vm/vm_diff_pages.js")

    #Run the checks
    ctx.eval pages_src

    expect(ctx.dump("diff_them(mod0)")).to eq([
      ["M", 0, {"value" => "b", "_sig" => "sig_new", "_id" => "id0"}]
    ])
    expect(ctx.dump("diff_them(mod1)")).to eq([
      ["M", 1, {"value" => "c", "_sig" => "sig_new", "_id" => "id1"}]
    ])
    expect(ctx.dump("diff_them(mod2)")).to eq([
      ["M", 0, {"value" => "b", "_sig" => "sig_new", "_id" => "id0"}],
      ["M", 1, {"value" => "c", "_sig" => "sig_new", "_id" => "id1"}]
    ])
  end

  it "can use vm_diff with deleted entry" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller22.rb'), File.read("./spec/kern/assets/vm/config5.rb") 
    pages_src = File.read("./spec/kern/assets/vm/vm_diff_pages.js")

    #Run the checks
    ctx.eval pages_src

    expect(ctx.dump("diff_them(dmod0)")).to eq([
      ["-", "id0"]
    ])
    expect(ctx.dump("diff_them(dmod1)")).to eq([
      ["-", "id1"]
    ])
    expect(ctx.dump("diff_them(dmod2)")).to eq([
      ["-", "id1"], ["-", "id0"]
    ])
  end

  #Inserted is just opposite of deleted, so we flip them
  it "can use vm_diff with inserted entry" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller22.rb'), File.read("./spec/kern/assets/vm/config5.rb") 
    pages_src = File.read("./spec/kern/assets/vm/vm_diff_pages.js")

    #Run the checks
    ctx.eval pages_src

    expect(ctx.dump("diff_them_reverse(dmod0)")).to eq([
      ["+", 0, {"value" => "a", "_sig" => "sig", "_id" => "id0"}]
    ])
    expect(ctx.dump("diff_them_reverse(dmod1)")).to eq([
      ["+", 1, {"value" => "b", "_sig" => "sig", "_id" => "id1"}]
    ])
    expect(ctx.dump("diff_them_reverse(dmod2)")).to eq([
      ["+", 0, {"value" => "a", "_sig" => "sig", "_id" => "id0"}],
      ["+", 1, {"value" => "b", "_sig" => "sig", "_id" => "id1"}]
    ])
  end
  ###########################################################################

  #vm_diff_replay
  ###########################################################################
  it "can use vm_diff_replay to replay insert" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller22.rb'), File.read("./spec/kern/assets/vm/config5.rb") 
    pages_src = File.read("./spec/kern/assets/vm/vm_diff_pages.js")

    #Run the checks
    ctx.eval pages_src

    ctx.eval %{
      //Array
      /////////////////////////////////////////////
      //Insert one at beginning (revese delete)
      var diff = diff_them_reverse(dmod0)
      vm_diff_replay(dmod0[1], diff);

      //Insert one at index 1
      diff = diff_them_reverse(dmod1)
      vm_diff_replay(dmod1[1], diff);
      /////////////////////////////////////////////

      //Hash
      /////////////////////////////////////////////
      //Insert one at beginning (revese delete)
      var hdiff = diff_them_reverse(hdmod0)
      vm_diff_replay(hdmod0[1], hdiff);

      //Insert one at index 1
      hdiff = diff_them_reverse(hdmod1)
      vm_diff_replay(hdmod1[1], hdiff);
      /////////////////////////////////////////////
    }

    #Array
    replayed_page0 = ctx.dump("dmod0[0]")
    original_page0 = ctx.dump("dmod0[1]")
    replayed_page1 = ctx.dump("dmod1[0]")
    original_page1 = ctx.dump("dmod1[1]")

    #Hash
    hreplayed_page0 = ctx.dump("hdmod0[0]")
    horiginal_page0 = ctx.dump("hdmod0[1]")
    hreplayed_page1 = ctx.dump("hdmod1[0]")
    horiginal_page1 = ctx.dump("hdmod1[1]")

    expect(original_page0).to eq(replayed_page0)
    expect(original_page1).to eq(replayed_page1)

    expect(horiginal_page0).to eq(hreplayed_page0)
    expect(horiginal_page1).to eq(hreplayed_page1)
  end

  it "can use vm_diff_replay to replay modify" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller22.rb'), File.read("./spec/kern/assets/vm/config5.rb") 
    pages_src = File.read("./spec/kern/assets/vm/vm_diff_pages.js")

    #Run the checks
    ctx.eval pages_src

    #One insert (Backwards delete)
    ctx.eval %{
      //Array
      var diff = diff_them(mod0)
      vm_diff_replay(mod0[0], diff);

      //Hash
      var hdiff = diff_them(hmod0)
      vm_diff_replay(hmod0[0], hdiff);
    }

    #Array
    replayed_page = ctx.dump("mod0[0]")
    original_page = ctx.dump("mod0[1]")

    #Hash
    hreplayed_page = ctx.dump("hmod0[0]")
    horiginal_page = ctx.dump("hmod0[1]")

    expect(original_page).to eq(replayed_page)
    expect(horiginal_page).to eq(hreplayed_page)
  end
  ###########################################################################
end
