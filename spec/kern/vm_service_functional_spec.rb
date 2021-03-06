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
      "_prev" => nil,
      "_id" => "my_id",
      "entries" => [],
      "__index" => {},
      "_hash" => nil,
    })

    expect(dump["new_anon_page"]["_id"]).not_to eq nil
    expect(dump["new_anon_page"]["entries"]).to eq []
  end

  it "Can can use vm_entry_with_id" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller0.rb'), File.read("./spec/kern/assets/vm/config5.rb") 
    dump = ctx.evald %{
      dump.new_page = vm_create_page("my_id")
      dump.new_page.entries.push({
        _sig: "test",
        _id: "test",
        value: "test",
      });

      vm_reindex_page(dump.new_page);
      vm_rehash_page(dump.new_page);

      dump.test_entry = vm_entry_with_id(dump.new_page, "test");
      dump.no_such_entry = vm_entry_with_id(dump.new_page, "test2");
    }

    expect(dump["test_entry"]).to eq({
      "_id" => "test",
      "_sig" => "test",
      "value" => "test",
    })

    expect(dump["test_entry2"]).to eq(nil)
  end

  it "Can can use vm_del_entry_with_id" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller0.rb'), File.read("./spec/kern/assets/vm/config5.rb") 
    dump = ctx.evald %{
      dump.new_page = vm_create_page("my_id")
      dump.new_page.entries.push({
        _sig: "test",
        _id: "test",
        value: "test",
      });
      dump.new_page.entries.push({
        _sig: "test2",
        _id: "test2",
        value: "test2",
      });
      dump.new_page.entries.push({
        _sig: "test3",
        _id: "test3",
        value: "test3",
      });
      dump.new_page.entries.push({
        _sig: "test4",
        _id: "test4",
        value: "test4",
      });

      vm_reindex_page(dump.new_page);
      vm_rehash_page(dump.new_page);

      vm_del_entry_with_id(dump.new_page, "test3");
      vm_del_entry_with_id(dump.new_page, "test4");
      vm_del_entry_with_id(dump.new_page, "test");
      vm_del_entry_with_id(dump.new_page, "testX");
    }

    expect(dump["new_page"]["entries"]).to eq([{
        "_sig" => "test2",
        "_id" => "test2",
        "value" => "test2",
      }
    ])
  end

  it "Can can use vm_set_entry_with_id_key_val" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller0.rb'), File.read("./spec/kern/assets/vm/config5.rb") 
    dump = ctx.evald %{
      dump.new_page = vm_create_page("my_id")
      dump.new_page.entries.push({
        _sig: "test",
        _id: "test",
        value: "test",
      });
      dump.new_page.entries.push({
        _sig: "test2",
        _id: "test2",
        value: "test2",
      });
      dump.new_page.entries.push({
        _sig: "test3",
        _id: "test3",
        value: "test3",
      });
      dump.new_page.entries.push({
        _sig: "test4",
        _id: "test4",
        value: "test4",
      });

      vm_reindex_page(dump.new_page);
      vm_rehash_page(dump.new_page);

      vm_set_entry_with_id_key_val(dump.new_page, "test3", "value", "foo");
      vm_set_entry_with_id_key_val(dump.new_page, "test3", "value2", "foo2"); 

      //Also test some ids that do not currently exist
      vm_set_entry_with_id_key_val(dump.new_page, "test5", "foo", "bar");
      vm_set_entry_with_id_key_val(dump.new_page, "test5", "foo2", "bar2");
    }

    expect(dump["new_page"]["entries"][0]).to eq("_sig" => "test", "_id" => "test", "value" => "test")
    expect(dump["new_page"]["entries"][1]).to eq("_sig" => "test2", "_id" => "test2", "value" => "test2")

    expect(dump["new_page"]["entries"][2]["_id"]).to eq("test3")
    expect(dump["new_page"]["entries"][2]["_sig"]).not_to eq(nil)
    expect(dump["new_page"]["entries"][2]["value"]).to eq("foo")
    expect(dump["new_page"]["entries"][2]["value2"]).to eq("foo2")

    expect(dump["new_page"]["entries"][3]).to eq("_sig" => "test4", "_id" => "test4", "value" => "test4")

    expect(dump["new_page"]["entries"][4]["_id"]).to eq("test5")
    expect(dump["new_page"]["entries"][4]["_sig"]).not_to eq(nil)
    expect(dump["new_page"]["entries"][4]["foo"]).to eq("bar")
    expect(dump["new_page"]["entries"][4]["foo2"]).to eq("bar2")
   end

  it "Can can use vm_copy_page" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller0.rb'), File.read("./spec/kern/assets/vm/config5.rb") 
    dump = ctx.evald %{
      dump.new_page = vm_create_page("Q")
      dump.no_head_no_next_no_entry = vm_copy_page(dump.new_page);

      //Modify the new_page with a head, next, and entry; then create a copy
      dump.new_page._head = "Z";
      dump.new_page._next = "Triangle";
      dump.new_page._prev = null;
      dump.new_page.entries.push({"_id": "id0", "_sig": "Square", "value": "Square"});
      dump.head_z_next_triangle_entry_square = vm_copy_page(dump.new_page);

      //Modify the new_page's entry in-place and make a copy
      dump.new_page.entries[0]["_sig"] = "Circle";
      dump.new_page.entries[0]["value"] = "Circle";
      dump.head_z_next_triangle_entry_circle = vm_copy_page(dump.new_page);

      //Modify the new_page's entry again in-place to make sure it dosen't affect the copies
      dump.new_page.entries[0]["_sig"] = "Triangle"
      dump.new_page.entries[0]["value"] = "Triangle"

      //Force a re-index, copy the page
      vm_reindex_page(dump.new_page);
      dump.head_z_next_triangle_entry_triangle_indexed = vm_copy_page(dump.new_page);

      //Adjust the page's index array container and an element itself to make sure nothing
      //is referenced.
      dump.new_page.__index["id0"] = -1 //This shouldn't modify our copied pages index at id0
      dump.new_page.__index["id1"] = 2  //Non-existant, just checking to make sure arrays are not referenced
    }

    expect(dump["no_head_no_next_no_entry"]).to eq({
      "_head" => nil,
      "_next" => nil,
      "_prev" => nil,
      "_id" => "Q",
      "_hash" => nil,
      "entries" => [],
      "__index" => {}
    })

    expect(dump["head_z_next_triangle_entry_square"]).to eq({
      "_head" => "Z",
      "_next" => "Triangle",
      "_prev" => nil,
      "_id" => "Q",
      "_hash" => nil,
      "entries" => [
        {"_id" => "id0", "_sig" => "Square", "value" => "Square"},
      ],
      "__index" => {"id0" => 0}
    })

    expect(dump["head_z_next_triangle_entry_circle"]).to eq({
      "_head" => "Z",
      "_next" => "Triangle",
      "_prev" => nil,
      "_id" => "Q",
      "_hash" => nil,
      "entries" => [
        {"_id" => "id0", "_sig" => "Circle", "value" => "Circle"},
      ],
      "__index" => {"id0" => 0}
    })

    expect(dump["head_z_next_triangle_entry_triangle_indexed"]).to eq({
      "_head" => "Z",
      "_next" => "Triangle",
      "_prev" => nil,
      "_id" => "Q",
      "_hash" => nil,
      "entries" => [
        {"_id" => "id0", "_sig" => "Triangle", "value" => "Triangle"},
      ],
      "__index" => { "id0" => 0, }
    })

    expect(dump["new_page"]).to eq({
      "_head" => "Z",
      "_prev" => nil,
      "_next" => "Triangle",
      "_id" => "Q",
      "_hash" => nil,
      "entries" => [
        {"_id" => "id0", "_sig" => "Triangle", "value" => "Triangle"},
      ],
      "__index" => {
        "id0" => -1,
        "id1" => 2
      }
    })
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
        _prev: null,
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
      "_prev" => nil,
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
        _prev: "c",
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
    hash = crc32("c", hash)
    hash = crc32("hello", hash)
    hash = crc32("nohteunth", hash)
    page = JSON.parse(ctx.eval("JSON.stringify(page)"))

    #Expect the same hash
    expect(page).to eq({
      "_head" => "a",
      "_next" => "b",
      "_prev" => "c",
      "_id" => "hello",
      "entries" => [
        {"_id" => "hello2", "_sig" => "nohteunth"}
      ],
      "_hash" => hash.to_s
    })
  end
  ###########################################################################

  #vm_reindex_page
  ###########################################################################
  it "vm_reindex_page can calculate the __index correctly" do
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
          {_id: "hello3", _sig: "nohteunth2"},
        ]
      }

      vm_reindex_page(page);
    }

    #Expect the same hash
    page = ctx.dump("page")
    expect(page.keys).to include("__index")
    expect(page["__index"]).to eq({
      "hello2" => 0,
      "hello3" => 1
    })
  end
  ###########################################################################

  #vm_diff
  ###########################################################################

  #################################################################################################################
  #Each vm_diff_entry is any array in the format of [type, *args] and each matcher is a hash
  #in the format of {:type => "*", :args => [...]}. In order for a matcher to match a vm_diff_entry
  #the matcher's :type must be equal to the vm_diff_entry's type, and the matcher's :args must be 
  #equal to the vm_diff_entry's *args. Equivalency for type is defined as absolutely equal. Equivalency
  #for args is defined per element; in order for args to be equivalent, all elements of the args must
  #be equivalent. Each element must be absolutely equal to be equivalent with the exception of argument
  #elements where the matcher element is of type hash. In the hash case, equivalency is true if the vm_diff_entry
  #sibling argument element is of type hash *and* the sibling element contains at-least all the key-value pairs
  #in the forementioned matcher's arg element.
  #e.g.
  #################################################################################################################
  #1. Match without a matcher's args element of type hash.
  #  ["foo", "bar", 3] <=> {:type => "foo", :args => ["bar", 3]}
  #2. Match with a matcher's args element of type hash.
  #  ["foo", "bar", {"hello" => "world", "goodbye" => "world} <=> {:type => "foo", :args => [{"hello" => "world"}]}
  #################################################################################################################
  def verify_vm_diff vm_diff, matchers
    winning_candidates = []

    _vm_diff = JSON.parse(vm_diff.to_json)

    _vm_diff.each do |vm_diff_entry|
      #Get the vm_diff_entry in the format of [type, *args]
      type = vm_diff_entry.shift
      args = vm_diff_entry

      #Find candidate matchers that have the same type as the vm_diff_entry
      candidates = matchers.select{|e| e[:type] == type}
      raise "verify_vm_diff failed. The given vm_diff contained a type, #{type.inspect} that was not even mentioned in the matchers. \nvm_diff = #{vm_diff.inspect}, \nmatchers = #{matchers.inspect}" unless candidates.length > 0

      #Find a candidate that matches the args rules listed in the comments
      winning_candidate = nil
      candidates.each do |c|
        catch(:candidate_failed) do
          raise "verify_vm_diff failed. A given matcher with type, \n#{c[:type]}, \ncontained no :args array" unless c[:args]
          next unless c[:args].length == args.length

          c[:args].each_with_index do |a, i|
            if a.class == Hash
              throw :candidate_failed if args[i].class != Hash
              a.each do |k, v|
                throw :candidate_failed if args[i][k] != v
              end
            else
              #Everything else is exactly equal to be equivalent
              throw :candidate_failed if a != args[i]
            end
          end

          winning_candidate = c
          break
        end
      end

      if winning_candidate
        winning_candidates << winning_candidate
      else
        raise "verify_vm_diff failed. Could not find a candidate to match the vm_diff_entry of: #{[type, *args]} with the matchers of #{matchers.inspect}"
      end
    end

    #Make sure all matchers were used
    left_matchers = matchers - winning_candidates
    raise "verify_vm_diff failed. Matchers did not all match a vm_diff_entry. \nRemaining matchers include \n#{left_matchers.inspect} \nand matched matchers include \n#{winning_candidates.inspect}\n for the vm_diff of\n#{vm_diff.inspect}" if left_matchers.length > 0
  end

  #Each vm_page["entries"] is an array, this helper function allows you to define a set
  #of matchers which will check the entries array to verify that all matchers are equal to
  #one unique element of the vm_page["entries"]. If all matchers are not exahusted, or all
  #vm_page["entries"] do not have a paired matcher, then this verify function fails. Equivalency
  #for entry matcher implies that all key-value pairs of the matcher are present in a vm_page["entries"] entry.
  #e.g.
  #############################################################################################################
  #Matching entry & matcher pair
  #entry = {"_id" => "my_id", "value" => 4}
  #matcher = {"_id" => "my_id"} or {"value" => 4} or {"_id => "my_id", "value" => 4}
  #############################################################################################################
  def verify_vm_page_entries page, matchers
    matching_matchers = []
    page["entries"].each do |entry|
      #Find matching matcher from matchers
      matching_matcher = nil
        matchers.each do |matcher|
          catch(:matcher_does_not_match) do
            #For all key value pairs in matcher
            matcher.each do |k, v|
              throw :matcher_does_not_match if entry[k] != v
            end

            matching_matcher = matcher
            break
          end
      end

      if matching_matcher
        matching_matchers << matching_matcher
      else
        raise "verify_vm_page_entries failed: The entry: #{entry.inspect} had no matchers that would fit the bill, given matchers include: #{matchers.inspect}. The page was: #{page.inspect}"
      end
    end

    left_matchers = matchers - matching_matchers
    raise "verify_vm_page_entries failed: Matchers did not all match an entry. \nRemaining matchers include\n#{left_matchers.inspect}\n and matched matchers include \n#{matching_matchers.inspect}\n for the page of #{page.inspect}" if left_matchers.length > 0
  end

  #Same as verify_vm_page_entries, but the order of the matchers is taken into account
  def verify_vm_page_entries_with_order page, matchers
    page["entries"].each_with_index do |entry, i|
      matcher = matchers[i]

      #Matcher should match all k, v pairs
      matcher.each do |k, v|
        raise "Matcher #{matcher.inspect} did not match entry: #{entry.inspect}\n The order was taken into consideration for entries:\n#{page["entries"].inspect}\nWith Matchers\n#{matchers.inspect}" if entry[k] != v
      end
    end
  end


  #Reload the vm_diff_pages.js.  Needed because vm_diff functions
  #are often destructive and multiple tests need to have a fresh
  #copy of the pages
  def reload_vm_diff_pages(ctx)
    pages_src = File.read("./spec/kern/assets/vm/vm_diff_pages.js")
    ctx.eval pages_src
  end

  it "can use vm_diff" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller22.rb'), File.read("./spec/kern/assets/vm/config5.rb") 

    #diff of vm_commit:0, 1
    #| Triangle | Square   | -> | Triangle | Circle   | 
    #| K        |          | -> |          | Q        |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = triangle_square_z_null;
      var to = triangle_circle_null_q;
      dump.diff = vm_diff(from, to)
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_diff(dump["diff"], [
      {type: "M", args: [{"_id" => "id1", "value" => "Circle"}]},
      {type: "-", args: ["id2"]},
      {type: "+", args: [2, {"_id" => "id3", "value" => "Q"}]}
    ])
    verify_vm_page_entries(dump["replay"], [
      {"_id" => "id0", "value" => "Triangle"},
      {"_id" => "id1", "value" => "Circle"},
      {"_id" => "id3", "value" => "Q"},
    ])

    #vm_commit:2
    #| Triangle | Square   | -> | Q        |          | 
    #| K        |          | -> | Circle   | Square   |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = triangle_square_z_null;
      var to = q_null_circle_square;
      dump.diff = vm_diff(from, to)
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_diff(dump["diff"], [
      {type: "M", args: [{"_id" => "id0", "value" => "Q"}]},
      {type: "-", args: ["id1"]},
      {type: "M", args: [{"_id" => "id2", "value" => "Circle"}]},
      {type: "+", args: [2, {"_id" => "id3", "value" => "Square"}]}
    ])
    verify_vm_page_entries(dump["replay"], [
      {"_id" => "id0", "value" => "Q"},
      {"_id" => "id2", "value" => "Circle"},
      {"_id" => "id3", "value" => "Square"},
    ])

    #vm_rebase:1 (diff only)
    #| P        | Circle   | -> | P        | Circle   | 
    #|          | Q        | -> |          |          |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = p_circle_null_q;
      dump.diff = [
        ["+", 0, {"_id": "id1", "_sig": "Square", "value": "Square"}],
        ["M", {"_id": "id2", "_sig": "Z", "value": "Z"}],
        ["-", "id3"],
      ]
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_page_entries(dump["replay"], [
      {"_id" => "id0", "value" => "P"},
      {"_id" => "id1", "value" => "Circle"},
    ])

    #vm_rebase:2a (diff only)
    #| P        | Circle   | -> | P        |          | 
    #|          | Q        | -> |          | Q        |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = p_circle_null_q;
      dump.diff = [
        ["-", "id1"],
        ["M", {"_id": "id2", "_sig": "A", "value": "A"}],
        ["+", 2, {"_id":"id3", "_sig": "M", "value": "M"}],
      ]
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_page_entries(dump["replay"], [
      {"_id" => "id0", "value" => "P"},
      {"_id" => "id3", "value" => "Q"},
    ])

    #vm_rebase:2b (diff only)
    #| P        |          | -> | P        | Square   | 
    #|          | Q        | -> |          |          |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = p_null_null_q;
      dump.diff = [
        ["+", 1, {"_id":"id1", "_sig": "Square", "value": "Square"}],
        ["M", {"_id": "id2", "_sig": "Z", "value": "Z"}],
        ["-", "id3"],
      ]
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_page_entries(dump["replay"], [
      {"_id" => "id0", "value" => "P"},
      {"_id" => "id1", "value" => "Square"},
    ])

    #vm_rebase:2c
    #| P        |          | -> | P        | Square   | 
    #|          | Q        | -> |          |          |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = p_null_null_q;
      var to = p_square_null_null;
      dump.diff = vm_diff(from, to)
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_diff(dump["diff"], [
      {type: "+", args: [1, {"_id" => "id1", "value" => "Square"}]},
      {type: "-", args: ["id3"]},
    ])
    verify_vm_page_entries(dump["replay"], [
      {"_id" => "id0", "value" => "P"},
      {"_id" => "id1", "value" => "Square"},
    ])

    #vm_rebase:2d
    #| Triangle |          | -> | Triangle | Square   | 
    #| A        | M        | -> | Z        |          |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = triangle_null_a_m;
      var to = triangle_square_z_null;
      dump.diff = vm_diff(from, to)
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_diff(dump["diff"], [
      {type: "+", args: [1, {"_id" => "id1", "value" => "Square"}]},
      {type: "M", args: [{"_id" => "id2", "value" => "Z"}]},
      {type: "-", args: ["id3"]},
    ])
    verify_vm_page_entries(dump["replay"], [
      {"_id" => "id0", "value" => "Triangle"},
      {"_id" => "id1", "value" => "Square"},
      {"_id" => "id2", "value" => "Z"},
    ])

    #vm_addendum:2a (diff only)
    #| Triangle | Square   | -> | Triangle | Z        | 
    #|          |          | -> | Q        |          |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = triangle_square_null_null;
      dump.diff = [
        ["M", {"_id": "id1", "_sig": "Z", "value": "Z"}],
        ["+", 2, {"_id":"id2", "_sig": "Q", "value": "Q"}],
        ["-", "id3"],
      ]
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_page_entries(dump["replay"], [
      {"_id" => "id0", "value" => "Triangle"},
      {"_id" => "id1", "value" => "Z"},
      {"_id" => "id2", "value" => "Q"},
    ])

    #vm_addendum:2b (diff only)
    #| Triangle | Square   | -> | Triangle | Z        | 
    #|          |          | -> | Q        |          |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = triangle_square_null_null;
      dump.diff = [
        ["M", {"_id": "id1", "_sig": "Z", "value": "Z"}],
        ["+", 2, {"_id":"id2", "_sig": "Q", "value": "Q"}],
        ["-", "id3"],
      ]
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_page_entries(dump["replay"], [
      {"_id" => "id0", "value" => "Triangle"},
      {"_id" => "id1", "value" => "Z"},
      {"_id" => "id2", "value" => "Q"},
    ])

    #vm_addendum:2c
    #head:null                  head:world
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = head_null;
      var to = head_world;
      dump.diff = vm_diff(from, to)
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_diff(dump["diff"], [
      {type: "HEAD_M", args: ["world"]}
    ])
    expect(dump["replay"]["_head"]).to eq("world")

    #vm_addendum:2d
    #head:world                  head:null
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = head_world;
      var to = head_null;
      dump.diff = vm_diff(from, to)
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_diff(dump["diff"], [
      {type: "HEAD_M", args: [nil]}
    ])
    expect(dump["replay"]["_head"]).to eq(nil)

    #vm_addendum:2e
    #next:null                  next:world
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = next_null;
      var to = next_world;
      dump.diff = vm_diff(from, to)
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_diff(dump["diff"], [
      {type: "NEXT_M", args: ["world"]}
    ])
    expect(dump["replay"]["_next"]).to eq("world")

    #vm_addendum:2f
    #next:world                 next:null
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = next_world;
      var to = next_null;
      dump.diff = vm_diff(from, to)
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_diff(dump["diff"], [
      {type: "NEXT_M", args: [nil]}
    ])
    expect(dump["replay"]["_next"]).to eq(nil)

    #continued... moved, XXXXXXX(N) is the new index
    #| Triangle(0) | Square(1)| -> | Triangle(1)| Square(0)|
    #| Z(2)        |          | -> | Z(2)       |          |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = triangle_square_z_null;
      var to = triangle_square_z_null_moved_square_triangle_z;
      dump.diff = vm_diff(from, to)
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_diff(dump["diff"], [
      {type: ">", args: [1, "id0"]}
    ])
    verify_vm_page_entries_with_order(dump["replay"], [
      {"_id" => "id1", "value" => "Square"},
      {"_id" => "id0", "value" => "Triangle"},
      {"_id" => "id2", "value" => "Z"},
    ])

    #moved(2)
    #| Triangle(0) | Square(1)| -> | Triangle(2)| Square(1)|
    #| Z(2)        |          | -> | Z(0)       |          |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = triangle_square_z_null;
      var to = triangle_square_z_null_moved_z_square_triangle;
      dump.diff = vm_diff(from, to)
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_diff(dump["diff"], [
      {type: ">", args: [2, "id0"]},
      {type: ">", args: [1, "id1"]}
    ])
    verify_vm_page_entries_with_order(dump["replay"], [
      {"_id" => "id2", "value" => "Z"},
      {"_id" => "id1", "value" => "Square"},
      {"_id" => "id0", "value" => "Triangle"},
    ])

    #moved(3) Not taking a diff, presenting an illegal move diff
    #to use on Q (Which dosen't exist)
    #| Triangle(0) | Square(1)| -> | Triangle(2)| Square(1)|
    #| Z(2)        |          | -> | Z(0)       |          |
    #from                       to
    reload_vm_diff_pages(ctx)
    dump = ctx.evald %{
      var from = triangle_square_z_null;
      dump.diff = [
        [">", 3, "id3"],
        [">", 2, "id0"],
        [">", 1, "id1"],
      ]
      vm_diff_replay(from, dump.diff);
      dump.replay = from;
      vm_rehash_page(dump.replay);
      vm_reindex_page(dump.replay);
    }
    verify_vm_page_entries_with_order(dump["replay"], [
      {"_id" => "id2", "value" => "Z"},
      {"_id" => "id1", "value" => "Square"},
      {"_id" => "id0", "value" => "Triangle"},
    ])
  end
  ###########################################################################

  #vm commit helpers
  ###########################################################################
  def reload_vm_commit_pages(ctx)
    pages_src = File.read("./spec/kern/assets/vm/vm_commit_pages.js")
    ctx.eval pages_src
  end

  it "can use vm_commit" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller22.rb'), File.read("./spec/kern/assets/vm/config5.rb") 

    #vm_commit:0
    #| Triangle | Circle   | -> | Triangle | Square   | 
    #|          | Q        | -> | Z        |          |
    #newer                       older
    reload_vm_commit_pages(ctx)
    dump = ctx.evald %{
      dump.newer = triangle_circle_null_q;
      dump.older = triangle_square_z_null;
      vm_commit(dump.older, dump.newer);
    }

    verify_vm_page_entries(dump["newer"], [
      {"_id" => "id0", "value" => "Triangle"},
      {"_id" => "id1", "value" => "Circle"},
      {"_id" => "id3", "value" => "Q"},
    ])

    #Changes match
    verify_vm_diff(dump["newer"]["__changes"], [
      {type: "M", args: [{"_id" => "id1", "value" => "Circle"}]},
      {type: "-", args: ["id2"]},
      {type: "+", args: [2, {"_id" => "id3", "value" => "Q"}]},
    ])

    #No base but does include changes
    expect(dump["newer"]["__changes_id"]).not_to eq(nil)
    expect(dump["newer"]["__base"]).to eq(nil)

    #vm_commit:1 older[nobase, changes]
    #| Triangle | Circle   | -> | Triangle | Square   | --__changes-- | -----             |
    #|          | Q        | -> | Z        |          |               | |x| |  Add (+)    |
    #newer                      older                                 | -----   Triangle  |
    #                                                                 | | | |             |
    #                                                                 | -----             |
    #                                                                 | -----             |
    #                                                                 | | | | Modify (M)  |
    #                                                                 | -----     Z       |
    #                                                                 | |x| |             |
    #                                                                 | -----             |
    #                                                                 | -----             |
    #                                                                 | | | | Remove (-)  |
    #                                                                 | -----             |
    #                                                                 | | |x|             |
    #                                                                 | -----             |
    reload_vm_commit_pages(ctx)
    dump = ctx.evald %{
      dump.newer = triangle_circle_null_q;
      dump.older = triangle_square_z_null;
      dump.older.__changes_id = "XXXXX";
      dump.older.__changes = [
        ["+", 0, {"_id": "id0", "_sig": "Triangle", "value": "Triangle"}],
        ["M", {"_id": "id2", "_sig": "Z", "value": "Z"}],
        ["-", "id3"],

      ]
      vm_commit(dump.older, dump.newer);
    }

    verify_vm_page_entries(dump["newer"], [
      {"_id" => "id0", "value" => "Triangle"},
      {"_id" => "id1", "value" => "Circle"},
      {"_id" => "id3", "value" => "Q"},
    ])

    #Changes match
    verify_vm_diff(dump["newer"]["__changes"], [
      {type: "M", args: [{"_id" => "id1", "value" => "Circle"}]},
      {type: "-", args: ["id2"]},
      {type: "+", args: [2, {"_id" => "id3", "value" => "Q"}]},
    ])
    expect(dump["newer"]["__changes_id"]).not_to eq(nil)

    #Base with changes
    verify_vm_page_entries(dump["newer"]["__base"], [
      {"_id" => "id0", "value" => "Triangle"},
      {"_id" => "id1", "value" => "Square"},
      {"_id" => "id2", "value" => "Z"},
    ])
    verify_vm_diff(dump["newer"]["__base"]["__changes"], [
      {type: "+", args: [0, {"_id" => "id0", "value" => "Triangle"}]},
      {type: "-", args: ["id3"]},
      {type: "M", args: [{"_id" => "id2", "value" => "Z"}]},
    ])
    expect(dump["newer"]["__base"]["__changes_id"]).not_to eq(nil)
    expect(dump["newer"]["__base"]["__base"]).to eq(nil)

    #vm_commit:2 older[base[nobase, changes], changes]
    #| Q        |          | -> | Triangle | Circle   | --__changes-- | -----             |
    #| Circle   | Square   | -> |          | Q        |               | | |x| Modify (M)  |
    #newer                      -----------------------               | -----   Circle    |
    #                           |      __base         |               | | | |             |
    #                           -----------------------               | -----             |
    #                           | Triangle | Square   |               | -----             |
    #                           | Z        |          | --__changes-  | | | | Remove (-)  |
    #                           older                              |  | -----             |
    #                                                              |  | |x| |             |
    #                                                              |  | -----             |
    #                                                              |  | -----             |
    #                                                              |  | | | | Insert (+)  |
    #                                                              |  | -----    Q        |
    #                                                              |  | | |x|             |
    #                                                              |  | -----             |
    #                                                              |  --------------------
    #                                                              |                      
    #                                                              |- | -----             |                    
    #                                                                 | |x| |  Add (+)    |                    
    #                                                                 | -----   Triangle  |                    
    #                                                                 | | | |             |                    
    #                                                                 | -----             |                    
    #                                                                 | -----             |                    
    #                                                                 | | | | Modify (M)  |                    
    #                                                                 | -----     Z       |                    
    #                                                                 | |x| |             |                    
    #                                                                 | -----             |                    
    #                                                                 | -----             |                    
    #                                                                 | | | | Remove (-)  |                    
    #                                                                 | -----             |                    
    #                                                                 | | |x|             |                    
    #                                                                 | -----             |                    
    reload_vm_commit_pages(ctx)
    dump = ctx.evald %{
      dump.newer = q_null_circle_square;
      dump.older = triangle_circle_null_q;
      dump.older.__changes_id = "XXXXX";
      dump.older.__changes = [
        ["M", {"_id": "id0", "_sig": "Circle", "value": "Circle"}],
        ["-", "id2"],
        ["+", 2, {"_id": "id3", "_sig": "Q", "value": "Q"}],
      ]

      //Also, base on older
      dump.older.__base = triangle_square_z_null;
      dump.older.__base.__changes = [
        ["+", 0, {"_id": "id0", "_sig": "Triangle", "value": "Triangle"}],
        ["M", {"_id": "id2", "_sig": "Z", "value": "Z"}],
        ["-", "id3"],
      ]
      dump.older.__base.__changes_id = "YYYYYYY";
      vm_commit(dump.older, dump.newer);
    }

    verify_vm_page_entries(dump["newer"], [
      {"_id" => "id0", "value" => "Q"},
      {"_id" => "id2", "value" => "Circle"},
      {"_id" => "id3", "value" => "Square"},
    ])

    #Changes match
    verify_vm_diff(dump["newer"]["__changes"], [
      {type: "M", args: [{"_id" => "id0", "value" => "Q"}]},
      {type: "-", args: ["id1"]},
      {type: "M", args: [{"_id" => "id2", "value" => "Circle"}]},
      {type: "+", args: [2, {"_id" => "id3", "value" => "Square"}]},
    ])
    expect(dump["newer"]["__changes_id"]).not_to eq(nil)

    #Base with changes
    verify_vm_page_entries(dump["newer"]["__base"], [
      {"_id" => "id0", "value" => "Triangle"},
      {"_id" => "id1", "value" => "Square"},
      {"_id" => "id2", "value" => "Z"},
    ])
    verify_vm_diff(dump["newer"]["__base"]["__changes"], [
      {type: "+", args: [0, {"_id" => "id0", "value" => "Triangle"}]},
      {type: "M", args: [{"_id" => "id2", "value" => "Z"}]},
      {type: "-", args: ["id3"]},
    ])
    expect(dump["newer"]["__base"]["__changes_id"]).not_to eq(nil)
    expect(dump["newer"]["__base"]["__base"]).to  eq(nil)
  end

  it "can use vm_rebase" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller22.rb'), File.read("./spec/kern/assets/vm/config5.rb") 

    #vm_rebase:0 newer[nobase, nochange]
    #| Triangle | Circle   | -> | Triangle | Square   | 
    #|          | Q        | -> | Z        |          |
    #older                       newer
    reload_vm_commit_pages(ctx)
    dump = ctx.evald %{
      dump.older = triangle_circle_null_q;
      dump.newer = triangle_square_z_null;
      vm_rebase(dump.newer, dump.older);
    }

    verify_vm_page_entries(dump["older"], [
      {"_id" => "id0", "value" => "Triangle"},
      {"_id" => "id1", "value" => "Circle"},
      {"_id" => "id3", "value" => "Q"},
    ])

    #No base & No changes
    expect(dump["older"]["__changes"]).to eq(nil)
    expect(dump["older"]["__changes_id"]).to eq(nil)
    expect(dump["older"]["__base"]).to eq(nil)

    #vm_rebase:1 newer[nobase, changes]
    #| P        | Circle   | -> | Triangle | Square   | --__changes-- | -----             |
    #|          | Q        | -> | Z        |          |               | | |x|  Add (+)    |
    #older                      newer                                 | -----   Square    |
    #                                                                 | | | |             |
    #                                                                 | -----             |
    #                                                                 | -----             |
    #                                                                 | | | | Modify (M)  |
    #                                                                 | -----     Z       |
    #                                                                 | |x| |             |
    #                                                                 | -----             |
    #                                                                 | -----             |
    #                                                                 | | | | Remove (-)  |
    #                                                                 | -----             |
    #                                                                 | | |x|             |
    #                                                                 | -----             |
    reload_vm_commit_pages(ctx)
    dump = ctx.evald %{
      dump.older = p_circle_null_q;
      dump.newer = triangle_square_z_null;
      dump.newer.__changes = [
        ["+", 0, {"_id": "id1", "_sig": "Square", "value": "Square"}],
        ["M", {"_id": "id2", "_sig": "Z", "value": "Z"}],
        ["-", "id3"],
      ]
      dump.newer.__changes_id = "XXXXXXXXXXX";
      vm_rebase(dump.newer, dump.older);
    }

    verify_vm_page_entries(dump["older"], [
      {"_id" => "id0", "value" => "P"},
      {"_id" => "id1", "value" => "Circle"},
    ])

    #Changes match
    verify_vm_diff(dump["older"]["__changes"], [
      {type: "+", args: [0, {"_id" => "id1", "value" => "Square"}]},
      {type: "M", args: [{"_id" => "id2", "value" => "Z"}]},
      {type: "-", args: ["id3"]},
    ])
    expect(dump["older"]["__changes_id"]).not_to eq(nil)

    #No base
    expect(dump["older"]["__base"]).to eq(nil)

    #vm_rebase:2 newer[base[nobase, changes], changes]
    #| P        | Circle   | -> | Triangle | Square   | --__changes-- | -----             |
    #|          | Q        | -> | K        |          |               | | |x|    Add (+)  |
    #older                      -----------------------               | -----   Square    |
    #                           |      __base         |               | | | |             |
    #                           -----------------------               | -----             |
    #                           | Triangle |          |               | -----             |
    #                           | A        | M        | --__changes-  | | | | Modify (M)  |
    #                           newer                              |  | -----    Z        |
    #                                                              |  | |x| |             |
    #                                                              |  | -----             |
    #                                                              |  | -----             |
    #                                                              |  | | | | Remove (-)  |
    #                                                              |  | -----             |
    #                                                              |  | | |x|             |
    #                                                              |  | -----             |
    #                                                              |  --------------------
    #                                                              |                      
    #                                                              |- | -----             |                    
    #                                                                 | | |x| Remove (-)  |                    
    #                                                                 | -----             |                    
    #                                                                 | | | |             |                    
    #                                                                 | -----             |                    
    #                                                                 | -----             |                    
    #                                                                 | | | | Modify (M)  |                    
    #                                                                 | -----     A       |                    
    #                                                                 | |x| |             |                    
    #                                                                 | -----             |                    
    #                                                                 | -----             |                    
    #                                                                 | | | |   Add (+)   |                    
    #                                                                 | -----     M       |                    
    #                                                                 | | |x|             |                    
    #                                                                 | -----             |                    
    reload_vm_commit_pages(ctx)
    dump = ctx.evald %{
      dump.older = p_circle_null_q;
      dump.newer = triangle_square_z_null;
      dump.newer.__changes_id = "XXXXX";
      dump.newer.__changes = [
        ["+", 0, {"_id": "id1", "_sig": "Square", "value": "Square"}],
        ["M", {"_id": "id2", "_sig": "Z", "value": "Z"}],
        ["-", "id3"],
      ]

      //Also, base on older
      dump.newer.__base = triangle_null_a_m;
      dump.newer.__base.__changes = [
        ["-", "id1"],
        ["M", {"_id": "id2", "_sig": "A", "value": "A"}],
        ["+", 2, {"_id": "id3", "_sig": "+", "value": "M"}],
      ]
      dump.newer.__base.__changes_id = "YYYYYYY";
      vm_rebase(dump.newer, dump.older);
    }

    verify_vm_page_entries(dump["older"], [
      {"_id" => "id0", "value" => "P"},
      {"_id" => "id1", "value" => "Square"},
    ])

    #Changes match
    verify_vm_diff(dump["older"]["__changes"], [
      {type: "+", args: [0, {"_id" => "id1", "value" => "Square"}]},
      {type: "-", args: ["id3"]},
    ])
    expect(dump["older"]["__changes_id"]).not_to eq(nil)
    expect(dump["older"]["__changes_id"]).not_to eq("XXXXX")

    #Base with changes
    verify_vm_page_entries(dump["older"]["__base"], [
      {"_id" => "id0", "value" => "P"},
      {"_id" => "id3", "value" => "Q"},
    ])
    verify_vm_diff(dump["older"]["__base"]["__changes"], [
      {type: "-", args: ["id1"]},
      {type: "M", args: [{"_id" => "id2", "value" => "A"}]},
      {type: "+", args: [2, {"_id" => "id3", "value" => "M"}]},
    ])
    expect(dump["older"]["__base"]["__changes_id"]).to  eq("YYYYYYY")
    expect(dump["older"]["__base"]["__base"]).to  eq(nil)
  end

  it "can use vm_mark_changes_synced" do
    ctx = flok_new_user File.read('./spec/kern/assets/vm/controller22.rb'), File.read("./spec/kern/assets/vm/config5.rb") 

    #Case A
    #Page with no changes. (Nothing happends)
    dump = ctx.evald %{
      dump.page = vm_create_page();
      vm_mark_changes_synced(dump.page, "changes_id");

      dump.__changes_id_is_undefined = (dump.page.__changes_id === undefined)
      dump.__changes_is_undefined = (dump.page.__changes === undefined)
    }
    expect(dump["__changes_id_is_undefined"]).to eq(true)
    expect(dump["__changes_is_undefined"]).to eq(true)

    #Case B
    #Page with changes, but changes_id given to vm_mark_changes_synced does not match (Nothing happends).
    dump = ctx.evald %{
      dump.page = vm_create_page();
      dump.page.__changes_id = "foo";
      dump.page.__changes = ["A"]
      vm_mark_changes_synced(dump.page, "bar");
    }
    expect(dump["page"]["__changes"]).to eq(["A"])
    expect(dump["page"]["__changes_id"]).to eq("foo")

    #Case C
    #Page with changes but no base, and changes_id given to vm_mark_changes_synced does match __changes_id of page.
    #The __changes and __changes_id of the page will be removed.
    dump = ctx.evald %{
      dump.page = vm_create_page();
      dump.page.__changes_id = "foo";
      dump.page.__changes = ["A"]
      vm_mark_changes_synced(dump.page, "foo");

      dump.__changes_id_is_undefined = (dump.page.__changes_id === undefined)
      dump.__changes_is_undefined = (dump.page.__changes === undefined)
    }
    expect(dump["__changes_id_is_undefined"]).to eq(true)
    expect(dump["__changes_is_undefined"]).to eq(true)

    #Case D
    #Page with changes and a base[changes, nobase], and changes_id given to vm_mark_changes_synced does not match __base.__changes_id of page.
    #Nothing happends
    dump = ctx.evald %{
      dump.page = vm_create_page();
      dump.page.__changes_id = "foo";
      dump.page.__changes = ["A"]

      //Attach base [unbased, changes]
      dump.page.__base = vm_create_page();
      dump.page.__base.__changes_id = "bar";
      dump.page.__base.__changes = ["B"]

      vm_mark_changes_synced(dump.page, "foo");
    }
    expect(dump["page"]["__changes"]).to eq(["A"])
    expect(dump["page"]["__changes_id"]).to eq("foo")

    #Case E
    #Page with changes and a base[changes, nobase], and changes_id given to vm_mark_changes_synced does match __base.__changes_id of page.
    #The base will be removed, but the page's __changes and __changes_id will remain.
    dump = ctx.evald %{
      dump.page = vm_create_page();
      dump.page.__changes_id = "foo";
      dump.page.__changes = ["A"]

      //Attach base [unbased, changes]
      dump.page.__base = vm_create_page();
      dump.page.__base.__changes_id = "bar";
      dump.page.__base.__changes = ["B"]

      vm_mark_changes_synced(dump.page, "bar");

      dump.__base_is_undefined = (dump.page.__base === undefined)
    }
    expect(dump["__base_is_undefined"]).to eq(true)
    expect(dump["page"]["__changes"]).to eq(["A"])
    expect(dump["page"]["__changes_id"]).to eq("foo")
  end
  ###########################################################################
end
