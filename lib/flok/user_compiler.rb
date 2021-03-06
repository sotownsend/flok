#Compile a controller ruby file into a javascript string

require 'active_support'
require 'active_support/core_ext/numeric'
require 'erb'
module Flok
  module UserCompiler
    #Compile a ruby file containing flok controller definitions (from the user)
    def self.compile rb_src
      #Execute code in this context, the context will hold all the information
      #that is used to then generate code
      context = UserCompilerContext.new
      context.instance_eval(rb_src, __FILE__, __LINE__)

      @src = ""
      ctable_erb = File.read File.join(File.dirname(__FILE__), "./user_compiler_templates/ctable.js.erb")
      ctable_renderer = ERB.new(ctable_erb)
      @src << ctable_renderer.result(context.get_binding)
      
      return @src
    end
  end
end

#Compiler executes all rb code (ERB) inside this context
module Flok
  class UserCompilerContext
    attr_accessor :controllers, :actions, :ons

    def initialize
      @controllers = []
      @actions = []
      @ons = []

      @debug = ENV["FLOK_ENV"] ? true : false
    end

    #Returns a list of events that this controller 'might' respond to
    #Used for things like hook event handlers to provide queryable 
    #information.
    def might_respond_to
      @actions.map{|e| e.ons}.flatten.map{|e| e[:name]}
    end

    #actions_responds_to looks like {"action1" => ["event_a", ..."], "action2" => }...
    #where each action list contains all the events this action responds to
    def actions_respond_to
      @actions.map{|e| [e.name.to_s, e.ons.map{|e| e[:name].to_s}]}.to_h
    end

    def get_binding
      return binding
    end

    def controller name, &block
      @controllers << UserCompilerController.new(name, self, &block)
    end

    def action controller, name, sticky, &block
      @actions << UserCompilerAction.new(controller, sticky, name, self, &block)
    end

    def on controller_name, action_name, name, &block
    end

    def actions_for_controller controller_name
      return @actions.select{|e| e.controller.name == controller_name}
    end

    def spots_for_controller controller_name
      return @controllers.detect{|e| e.name == controller_name}.spots
    end
  end

  #Event handler inside an action
  class UserCompilerOn
    attr_accessor :controller_name, :action_name, :name
  end

  module UserCompilerMacro
    def _macro text
      out = StringIO.new

      text.split("\n").each do |l|
        #EMBED(vc_name, spot_name, context) macro
        if l =~ /Embed/
          l.strip!
          l.gsub!(/Embed\(/, "")
          l.gsub! /\)$/, ""
          l.gsub! /\);$/, ""
          o = l.split(",").map{|e| e.strip}

          vc_name = o.shift.gsub(/"/, "")
          spot_name = o.shift.gsub(/"/, "")
          context = o.shift

          #Get the spot 
          shared_spot = false
          spot_index = @controller.spots.map{|e| e.to_s}.index(spot_name)
          unless spot_index
            #Maybe it's a shared spot?
            shared_spot_index = @controller.mapped_shared_spots.map{|e| e.to_s}.index(spot_name.to_s)
            raise "controller #{@controller.name.inspect} attempted to embed #{spot_name.inspect} inside #{@name.inspect}, but #{spot_name.inspect} was not defined in 'spots' (#{@controller.spots.inspect})" unless shared_spot_index
            spot_index = shared_spot_index+@controller.spots.count
            shared_spot = true
          end

          #Calculate spot index as an offset from the base address using the index of the spot in the spots
          #address offset
          res = ""

          if @debug
          res += %{
            if (__base__.constructor !== Number) { throw "Embed for the controller: #{@controller.name} was not given a number for it's __base__ pointer, but of type: " + __base__.constructor + "with the value: " + __base__};
          }
          end

          #Depending on whether it's a shared spot
          if not shared_spot
            res += %{
              var ptr = _embed("#{vc_name}", __base__+#{spot_index}+1, #{context}, __base__);
              __info__.embeds[#{spot_index-1}].push(ptr);
            }
          else
            res += %{
              //var remote_info = tel_deref(shared['#{spot_name}'].bp);
              var ptr = _embed("#{vc_name}", shared['#{spot_name}'].sbp, #{context}, __base__);
              __info__.embeds[#{spot_index-1}].push(ptr);
              //remote_info.embeds[#{spot_index-1}].push(ptr);
            }
          end

          res += %{
          }
          out.puts res
        #Send(event_name, info)
        elsif l =~ /Send/
          l.strip!
          l.gsub!(/Send\(/, "")
          l.gsub! /\)$/, ""
          l.gsub! /\);$/, ""
          o = l.split(",").map{|e| e.strip}

          event_name = o.shift.gsub(/"/, "")
          info = o.shift

          out << %{
           main_q.push([3, "if_event", __base__, "#{event_name}", #{info}])
          }
        #Raise(event_name, info)
        elsif l =~ /Raise/
          l.strip!
          l.gsub!(/Raise\(/, "")
          l.gsub! /\)$/, ""
          l.gsub! /\);$/, ""
          o = l.split(",").map{|e| e.strip}

          event_name = o.shift
          info = o.shift

          out << %{
            int_event(__info__.event_gw, #{event_name}, #{info});
          }
        #Lower(spot_name, event_name, info)
        elsif l =~ /Lower/
          l.strip!
          l.gsub!(/Lower\(/, "")
          l.gsub! /\)$/, ""
          l.gsub! /\);$/, ""
          o = l.split(",").map{|e| e.strip}

          spot_name = o.shift.gsub(/"/, "")
          event_name = o.shift
          info = o.shift

          #Get the spot 
          spot_index = @controller.spots.index(spot_name)
          raise "controller #{@controller.name.inspect} attempted to lower message to #{spot_name.inspect} inside #{@name.inspect}, but #{spot_name.inspect} was not defined in 'spots' (#{@controller.spots.inspect})" unless spot_index

          #Forward an event to the appropriate spot
          out << %{

            var vcs = __info__.embeds[#{spot_index-1}];
            for (var i = 0; i < vcs.length; ++i) {
              int_event(vcs[i], #{event_name}, #{info});
            }
          }
        #GOTO(action_name)
        elsif l =~ /Goto/
          l.strip!
          l.gsub!(/Goto\(/, "")
          l.gsub! /\)$/, ""
          l.gsub! /\);$/, ""
          o = l.split(",").map{|e| e.strip}

          action_name = o.shift.gsub(/"/, "")

          to_action = @ctx.actions_for_controller(@controller.name).select{|e| e.name.to_s == action_name.to_s}.first
          from_action = @ctx.actions_for_controller(@controller.name).select{|e| e.name.to_s == @name.to_s}.first
          #This section frees the views if the last action was not marked sticky
          free_section_one = ""
          if from_action and not from_action.is_sticky
            free_section_one = %{
                //Free if 'free_asap' is not set, this is usually configured via the 'goto' hook
                if (__free_asap === true) {
                  main_q.push([1, "if_free_view", embeds[i][j]+1]);
                } else {
                  views_to_free[views_to_free_id].push(embeds[i][j]+1);
                }

                //Call dealloc on the controller, it will also recursively call deallocs
                tel_deref(embeds[i][j]).cte.__dealloc__(embeds[i][j], collected_shared_spot_embeds);
            }

            free_section_init = ""
          else
            free_section_one = %{
                //Free if 'free_asap' is not set, this is usually configured via the 'goto' hook
                if (__free_asap === true) {
                  var hvbp = embeds[i][j]+1;
                  //Only hide the view
                  main_q.push([2, "if_hide_view", hvbp, true]);
                } else {
                  //Assume that interceptor will hide it
                }
            }

            free_section_init = %{
              //Save our hidden views to the heap
              __info__.heap["#{@name}"] = __info__.embeds;
            }
          end

          #Called to load the destination view
          if to_action and to_action.is_sticky
            #Target is sticky, might just need to re-show views marked hidden via the heap
            init_target_section_one = %{
              var to_action_heap = __info__.heap["#{action_name}"]; 
              if (to_action_heap !== undefined) {
                for (var i = 0; i < to_action_heap.length; ++i) {
                  for (var ii = 0; ii < to_action_heap[i].length; ++ii) {
                    main_q.push([2, "if_hide_view", to_action_heap[i][ii]+1, false]);
                  }
                }
                __info__.embeds = __info__.heap["#{action_name}"];
                delete __info__.heap["#{action_name}"];
              } else {
                __info__.cte.actions[__info__.action].on_entry(__base__)
              }
            }
          else
            #Target is not sticky, just create
            init_target_section_one = %{
              __info__.cte.actions[__info__.action].on_entry(__base__)
            }
          end

          #Switch the actions, reset embeds, and call on_entry
          res = %{
            var old_action = __info__.action;
            __info__.action = "#{action_name}";

            var __free_asap = true;
            //HOOK_ENTRY[controller_will_goto] #{{"controller_name" => @controller.name, "might_respond_to" => @ctx.might_respond_to, "actions_responds_to" => @ctx.actions_respond_to, "from_action" => @name, "to_action" => action_name, "handling_event_named" => @handling_event_named}.to_json}

            //If views are configured to not free right away, set up a new stack of views to free
            //This is usually picked up by the hook GOTO
            if (__free_asap === false) {
              var views_to_free_id = tels(1);
              views_to_free[views_to_free_id] = views_to_free[views_to_free_id] || [];
            }
            
            //Remove all views, we don't have to recurse because removal of a view
            //is supposed to remove *all* view controllers of that tree as well.
            var embeds = __info__.embeds;
            #{free_section_init}
            var collected_shared_spot_embeds = [];
            for (var i = 0; i < __info__.embeds.length; ++i) {
              for (var j = 0; j < __info__.embeds[i].length; ++j) {
                //Free +1 because that will be the 'main' view

                #{free_section_one}
              }
            }

            //TODO: Support sticky actions
            //Reap any shared spots
            for (var i = 0; i < collected_shared_spot_embeds.length; ++i) {
              if (__free_asap === true) {
                main_q.push([1, "if_free_view", collected_shared_spot_embeds[i]+1]);
              } else {
                views_to_free[views_to_free_id].push(collected_shared_spot_embeds[i]+1);
              }
            }

            //Prep embeds array, embeds[0] refers to the spot bp+2 (bp is vc, bp+1 is main)
            __info__.embeds =  #{(1...@controller.all_spots.count).to_a.map{|e| []}.to_json};

            //Call on_entry for the new action via the singleton on_entry
            //located in ctable if the destination was not stickied
            #{init_target_section_one}

            //HOOK_ENTRY[controller_did_goto] #{{"controller_name" => @controller.name, "might_respond_to" => @ctx.might_respond_to, "actions_responds_to" => @ctx.actions_respond_to, "from_action" => @name, "to_action" => action_name, "handling_event_named" => @handling_event_named}.to_json}
            //'choose_action' pseudo-action will be sent as 'null' as it's the initial state
            if (old_action === "choose_action") {
              old_action = null;
            }

            //Send off event for action change
            main_q.push([3, "if_event", __base__, "action", {
              from: old_action,
              to: "#{action_name}"
            }]);

          }
          out.puts res
        elsif l =~ /Push/
          l.strip!
          l.gsub!(/Push\(/, "")
          l.gsub! /\)$/, ""
          l.gsub! /\);$/, ""
          o = l.split(",").map{|e| e.strip}

          action_name = o.shift.gsub(/"/, "")

          #Switch the actions, reset embeds, and call on_entry
          res = %{
            //Save state
            var old_action = __info__.action;
            var old_embeds = __info__.embeds;
            __info__.stack.push({action: old_action, embeds: old_embeds});

            __info__.action = "#{action_name}";

            //HOOK_ENTRY[controller_will_push] #{{"controller_name" => @controller.name, "might_respond_to" => @ctx.might_respond_to, "actions_responds_to" => @ctx.actions_respond_to, "from_action" => @name, "to_action" => action_name, "handling_event_named" => @handling_event_named}.to_json}

            //Prep embeds array, embeds[0] refers to the spot bp+2 (bp is vc, bp+1 is main)
            __info__.embeds =  #{(1...@controller.all_spots.count).to_a.map{|e| []}.to_json};

            //Call on_entry for the new action via the singleton on_entry
            //located in ctable
            __info__.cte.actions[__info__.action].on_entry(__base__)

            //HOOK_ENTRY[controller_did_push] #{{"controller_name" => @controller.name, "might_respond_to" => @ctx.might_respond_to, "actions_responds_to" => @ctx.actions_respond_to, "from_action" => @name, "to_action" => action_name, "handling_event_named" => @handling_event_named}.to_json}

            //Send off event for action change
            main_q.push([3, "if_event", __base__, "action", {
              from: old_action,
              to: "#{action_name}"
            }]);
          }
          out.puts res
        elsif l =~ /Pop/
          l.strip!
          l.gsub!(/Pop\(/, "")
          l.gsub! /\)$/, ""
          l.gsub! /\);$/, ""
          o = l.split(",").map{|e| e.strip}
          #Switch the actions, reset embeds, and call on_entry
          res = %{
            var restore_info = __info__.stack.pop();

            //Retrieve the original action info
            var orig_action = restore_info.action;
            var orig_embeds = restore_info.embeds;

            //Save the old action
            //var old_action = __info__.action;

            var __free_asap = true;
            //HOOK_ENTRY[controller_will_pop] #{{"controller_name" => @controller.name, "might_respond_to" => @ctx.might_respond_to, "actions_responds_to" => @ctx.actions_respond_to, "from_action" => @name, "handling_event_named" => @handling_event_named}.to_json}

            //If views are configured to not free right away, set up a new stack of views to free
            //This is usually picked up by the hook POP
            if (__free_asap === false) {
              var views_to_free_id = tels(1);
              views_to_free[views_to_free_id] = views_to_free[views_to_free_id] || [];
            }

            //Restore the action we pushed from
            __info__.action = orig_action;

            //Remove all views, we don't have to recurse because removal of a view
            //is supposed to remove *all* view controllers of that tree as well.
            var collected_shared_spot_embeds = [];  //collect all the shared spots that wont be removed from the hierarchy
            var embeds = __info__.embeds;
            for (var i = 0; i < __info__.embeds.length; ++i) {
              for (var j = 0; j < __info__.embeds[i].length; ++j) {
                //Free +1 because that will be the 'main' view
                //Free if 'free_asap' is not set, this is usually configured via the 'pop' hook
                if (__free_asap === true) {
                  main_q.push([1, "if_free_view", embeds[i][j]+1]);
                } else {
                  views_to_free[views_to_free_id].push(embeds[i][j]+1);
                }

                //Call dealloc on the controller
                tel_deref(embeds[i][j]).cte.__dealloc__(embeds[i][j], collected_shared_spot_embeds);
              }
            }

            //Reap any shared spots
            for (var i = 0; i < collected_shared_spot_embeds.length; ++i) {
              if (__free_asap === true) {
                main_q.push([1, "if_free_view", collected_shared_spot_embeds[i]+1]);
              } else {
                views_to_free[views_to_free_id].push(collected_shared_spot_embeds[i]+1);
              }
            }

            //Restore embeds
            __info__.embeds = orig_embeds;

            //HOOK_ENTRY[controller_did_pop] #{{"controller_name" => @controller.name, "might_respond_to" => @ctx.might_respond_to, "actions_responds_to" => @ctx.actions_respond_to, "from_action" => @name, "handling_event_named" => @handling_event_named}.to_json}
          }

          out.puts res
        #Request(service_instance_name, ename, info)
        elsif l =~ /Request/
          l.strip!
          l.gsub!(/Request\(/, "")
          l.gsub! /\)$/, ""
          l.gsub! /\);$/, ""
          o = l.split(",").map{|e| e.strip}

          name = o.shift.gsub(/"/, "")
          ename = o.shift.gsub(/"/, "")
          info = o.shift.gsub(/"/, "")
          raise "You tried to Request the service #{name.inspect}, but you haven't added that to your 'services' for this controller (#{@controller.name.inspect})" unless @controller._services.include? name
          out << %{
            #{name}_on_#{ename}(__base__, #{info});
          }
        #VM Page macros
        elsif l =~ /NewPage/
          le = (l.split /NewPage/)
          lvar = le[0].strip #Probably var x = 
          exp = le[1].strip

          #For CopyPage(original_page), page_var is original_page
          #This only supports variable names at this time
          exp.match /\((.*?),(.*?)\);?/
          exp.match /\((.*)\)/ if $1 == nil


          #Get the id value the user wants, but we have to be careful
          #because if nothing is passed, then we need to set it to null
          type_var = $1
          id_var = $2

          type_var = type_var.gsub(/"/, "").strip
          id_var = (id_var || "null").strip

          raise "NewPage was not given a type" if type_var == ""
          raise "NewPage type is not valid #{type_var.inspect}" unless ["array", "hash"].include? type_var

          type_var_to_entries = {
            "array" => "[]",
            "hash" => "{}",
          }

          out << %{
            #{lvar} {
              _head: null,
              _next: null,
              entries: #{type_var_to_entries[type_var]},
              _id: #{id_var},
              _type: "#{type_var}",
            }
          }
        elsif l =~ /CopyPage/
          le = (l.split /CopyPage/)
          lvar = le[0].strip #Probably var x = 
          exp = le[1].strip

          #For CopyPage(original_page), page_var is original_page
          #This only supports variable names at this time
          exp.match /\((.*)\);?/
          page_var = $1

          out << %{
            
            var __page__ = {
              _head: #{page_var}._head,
              _next: #{page_var}._next,
              _id: #{page_var}._id,
              _type: #{page_var}._type,
            }

            //This is a shallow clone, but we own this array
            //When a mutable entry needs to be created, an entry will be cloned
            //and swappend out
            if (#{page_var}._type === "array") {
              __page__.entries = [];
              for (var i = 0; i < #{page_var}.entries.length; ++i) {
                __page__.entries.push(#{page_var}.entries[i]);
              }
            } else if (#{page_var}._type === "hash") {
              __page__.entries = {};
              var keys = Object.keys(#{page_var}.entries);
              for (var i = 0; i < keys.length; ++i) {
                var key = keys[i];
                __page__.entries[key] = #{page_var}.entries[key];
              }
            }

            #{lvar} __page__;
          }
        elsif l =~ /EntryDel/
          le = (l.split /EntryDel/)
          lvar = le[0].strip #Probably var x = 
          exp = le[1].strip

          #For CopyPage(original_page), page_var is original_page
          #This only supports variable names at this time
          exp.match /\((.*?),(.*)\);?/
          page_var = $1
          index_var = $2

          out << %{
            if (#{page_var}._type === "array") {
              #{page_var}.entries.splice(#{index_var}, 1);
            } else if (#{page_var}._type === "hash") {
              delete #{page_var}.entries[#{index_var}];
            }
          }

        elsif l =~ /EntryInsert/
          le = (l.split /EntryInsert/)
          lvar = le[0].strip #Probably var x = 
          exp = le[1].strip

          #For CopyPage(original_page), page_var is original_page
          #This only supports variable names at this time
          exp.match /\((.*?),(.*),(.*)\);?/
          page_var = $1
          index_var = $2
          entry_var = $3

          page_var.strip!
          index_var.strip!
          entry_var.strip!

          out << %{

            if (#{page_var}._type === "array") {
              #{entry_var}._id = gen_id();
              #{entry_var}._sig = gen_id();
              #{page_var}.entries.splice(#{index_var}, 0, #{entry_var});
            } else if (#{page_var}._type === "hash") {
              #{entry_var}._sig = gen_id();
              #{page_var}.entries[#{index_var}] = #{entry_var};
            }

          }

        elsif l =~ /SetPageNext/
          le = (l.split /SetPageNext/)
          lvar = le[0].strip #Probably var x = 
          exp = le[1].strip

          #For CopyPage(original_page), page_var is original_page
          #This only supports variable names at this time
          exp.match /\((.*?),(.*)\);?/
          page_var = $1
          value_var = $2

          out << %{
            #{page_var}._next = #{value_var};
          }

        elsif l =~ /SetPageHead/
          le = (l.split /SetPageHead/)
          lvar = le[0].strip #Probably var x = 
          exp = le[1].strip

          #For CopyPage(original_page), page_var is original_page
          #This only supports variable names at this time
          exp.match /\((.*?),(.*)\);?/
          page_var = $1
          value_var = $2

          out << %{
            #{page_var}._head = #{value_var};
          }

        elsif l =~ /EntryMutable/
          le = (l.split /EntryMutable/)
          lvar = le[0].strip #Probably var x = 
          exp = le[1].strip

          #For CopyPage(original_page), page_var is original_page
          #This only supports variable names at this time
          exp.match /\((.*?),(.*)\);?/
          page_var = $1
          index_var = $2


          out << %{
            if (#{page_var}._type === "array") {
              //Duplicate entry
              #{page_var}.entries.splice(#{index_var}, 1, JSON.parse(JSON.stringify(#{page_var}.entries[#{index_var}])));

              //Here's our new entry
              var ne = #{page_var}.entries[#{index_var}];
              ne._sig = gen_id();

              #{lvar} #{page_var}.entries[#{index_var}];
            } else if (#{page_var}._type === "hash") {
              //Duplicate entry
              #{page_var}.entries[#{index_var}] = JSON.parse(JSON.stringify(#{page_var}.entries[#{index_var}]));

              //Here's our new entry
              var ne = #{page_var}.entries[#{index_var}];
              ne._sig = gen_id();

              #{lvar} #{page_var}.entries[#{index_var}];

            }
          }
        else
          out.puts l
        end
      end

      return out.string
    end

  end

  class UserCompilerAction
    attr_accessor :controller, :name, :every_handlers, :is_sticky
    include UserCompilerMacro

    def initialize controller, is_sticky, name, ctx, &block
      @controller = controller
      @name = name
      @ctx = ctx
      @_on_entry_src = ""
      @_ons = [] #Event handlers
      @every_handlers = []
      @is_sticky = is_sticky

      self.instance_eval(&block)
    end

    def on_entry js_src
      #returns a string
      @_on_entry_src = _macro(js_src)
    end

    def on_entry_src
      return @_on_entry_src
    end

    def on name, js_src
      #We need this guard because we run a two pass compile on the ons. When 'ons' is accessed, it is assumed that we are now
      #in the compilation phase and we build all the entries. This is because some macros in the ons source code requires
      #prior-knowledge of controller-level information like all possible events in all actions for hooks
      raise "Uh oh, you tried to add an event handler but we already assumed that compilation took place so we cached everything..." if @__ons_did_build or @__ons_is_building

      @_ons << {:name => name, :src => js_src}
    end

    def ons 
      #Return the un-compiled version as some macros access this data and the real ons
      #would cause infinite recursion
      return @_ons if @__ons_is_building
      @__ons_is_building = true

      #We need this guard because we run a two pass compile on the ons. When 'ons' is accessed, it is assumed that we are now
      #in the compilation phase and we build all the entries. This is because some macros in the ons source code requires
      #prior-knowledge of controller-level information like all possible events in all actions for hooks
      unless @__ons_did_build
        @__ons_did_build = true
        @__ons = @_ons.map do |e|
          @handling_event_named = e[:name]
          src = _macro(e[:src])
          @handling_event_named = nil
          {:name => e[:name], :src => src}
        end
      end

      @__ons_is_building = false
      return @__ons
    end

    def every seconds, str
      @every_handlers << {
        :name => "#{seconds}_sec_#{SecureRandom.hex[0..6]}",
        :ticks => seconds*4,
        :src => _macro(str)
      }
    end

    #You can def things in controller and use them as macros inside actions
    #But these defs. live in the UserCompilerController instance and we need
    #to delegate these calls to the controller that are not available in the action
    def method_missing method, *args, &block
      if macro = @controller.macros[method]
        #Call the macro in our context
        @current_action = name
          self.instance_eval(&macro)
        @current_action = nil
      else
        raise "No macro found named: #{method} for controller #{@controller.name} in action #{@name}"
      end
    end
  end

  class UserCompilerController
    include UserCompilerMacro

    attr_accessor :name, :spots, :macros, :_services, :_on_entry, :shares, :mapped_shares, :shared_spots, :mapped_shared_spots
    def initialize name, ctx, &block
      @name = name
      @ctx = ctx
      @spots = ['main']
      @macros = {}
      @shares = []
      @mapped_shares = []
      @_services = []
      @mapped_shared_spots = []
      @shared_spots = []

      #Some macros expect controller instance
      @controller = self

      self.instance_eval(&block)

      #Ensure that choose_action exists
      actions = @ctx.actions_for_controller(@name)
      unless actions.detect{|e| e.name === :choose_action}
        @ctx.action self, :choose_action, false do
          on_entry %{
            Goto("#{actions[0].name}");
          }
        end
      end
    end

    #Create an action macro
    def macro name, &block
      @macros[name] = block
    end

    def on_entry str
      @_on_entry = _macro(str)
    end

    def choose_action &block
      @ctx.action self, :choose_action, false, &block
    end

    #Names of spots
    def spots *spots
      @spots += spots
    end

    def services *instance_names
      @_services = instance_names.map{|e| e.to_s}
    end

    def share key
      @shares << key
    end

    #This will cause a shared key to be added to this controller's
    #shared structure or an exception if it's not available in some
    #super controller. use as map_share "user" => "user"
    def map_share key
      @mapped_shares << key
    end

    #Use as share_spot :content => :alt_name
    def share_spot params
      raise "share_spot requires a name and alias, like :content => 'user_root.content'" if params.class != Hash
      name = params.keys[0]
      name_as = params.values[0]
      if name_as.nil? or name.nil?
        raise "share_spot requires a name and alias, like :content => 'user_root.content'"
      end

      @shared_spots << {"name" => name, "name_as" => name_as}
    end

    def map_shared_spot spot_name
      @mapped_shared_spots << spot_name
    end

    def all_spots
      return @spots+@mapped_shared_spots
    end

    #Pass through action
    def action name, &block
      @ctx.action self, name, false, &block
    end

    def sticky_action name, &block
      @ctx.action self, name, true, &block
    end

  end
end
