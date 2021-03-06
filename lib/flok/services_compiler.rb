#Compile a controller ruby file into a javascript string
require 'active_support'
require 'active_support/core_ext/numeric'

require 'erb'
module Flok
  module ServicesCompiler
    #Compile a ruby file containing flok controller definitions (from the services)
    #The config is outlined in the documentation under docs/services.md
    def self.compile rb_src, rb_config
      #Execute the configuration file first
      config_context = ServicesCompilerConfigContext.new
      config_context.instance_eval(rb_config, __FILE__, __LINE__)

      #Execute code in this context, the context will hold all the information
      #that is used to then generate code
      context = ServicesCompilerContext.new(config_context)
      context.instance_eval(rb_src, __FILE__, __LINE__)
      context.ready
      
      @src = ""
      services_erb = File.read File.join(File.dirname(__FILE__), "./service_compiler_templates/services.js.erb")
      services_renderer = ERB.new(services_erb)
      @src << services_renderer.result(context.get_binding)

      return @src
    end
  end
end

#Compiler executes all rb code inside this context
module Flok
  class ServicesCompilerConfigContext
    #Each service instance contains a :instance_name and :class
    attr_accessor :service_instances

    def initialize
      @service_instances = []
    end

    def service_instance instance_name, name, options={}
      @service_instances.push({
        :instance_name => instance_name,
        :class => name,
        :options => options
      })
    end
  end

 class ServicesCompilerContext
    attr_accessor :services, :config

    def initialize config_context
      @config = config_context

      #A hash containing the 'class' name of the service to a block that can be used with Service.new
      @_services = {}

      @services = []
    end

    def ready
      #Create an array from the service_instances where each element in the array is the full code of the service
      @config.service_instances.each do |i|
        #Get the instance name and class name of the service, normally defined in a ./config/services.rb file
        sname = i[:instance_name]
        sclass = i[:class]
        soptions = i[:options]

        sblock = @_services[sclass]
        raise "No service found for service_name: #{sclass.inspect} when trying to create service with instance name #{sname.inspect}. @_services contained: #{@_services.inspect} \n@config.service_instances contained: #{@config.service_instances.inspect}" unless sblock
        service = Service.new(sname, soptions)
        service.instance_eval(&sblock)
        @services << service
      end
    end

    def get_binding
      return binding
    end

    def service name, &block
      @_services[name] = block
    end
  end

  class Service
    attr_accessor :name, :_global, :_on_wakeup, :_on_sleep, :_on_connect, :_on_disconnect, :event_handlers, :every_handlers, :options
    def initialize name, options
      @name = name
      @options = options

      #These are the 'on' handlers
      @event_handlers = []

      #These are for every 5.seconds
      @every_handlers = []

      @debug = true if ENV["FLOK_ENV"] == "DEBUG"
      @release = true if ENV["FLOK_ENV"] == "RELEASE"
    end

    def get_on_init
      return @on_init
    end

    def get_on_request
      return @on_request
    end

    def global(str)
      render = ERB.new(str)
      str = render.result(binding)
      @_global = macro(str)
    end

    def on_wakeup(str) 
      render = ERB.new(str)
      str = render.result(binding)
      @_on_wakeup  = macro(str)
    end

    def on_sleep(str) 
      render = ERB.new(str)
      str = render.result(binding)

      @_on_sleep = macro(str)
    end

    def on_connect(str) 
      render = ERB.new(str)
      str = render.result(binding)
      @_on_connect = macro(str)
    end

    def on_disconnect(str) 
      render = ERB.new(str)
      str = render.result(binding)
      @_on_disconnect = macro(str)
    end

    def on(name, str)
      render = ERB.new(str)
      str = render.result(binding)

      @event_handlers << {
        :name => name,
        :str => macro(str)
      }
    end

    def every(seconds, str)
      @every_handlers << {
        :name => "#{seconds}_sec_#{SecureRandom.hex[0..6]}",
        :ticks => seconds*4,
        :str => macro(str)
      }
    end

    def type str
      @_type = str.to_s
      unless ["daemon", "agent"].include? @_type
        raise "You gave a type for the service, #{@_type.inspect} but this wasn't a valid type of service. Should be \
        either 'daemon' or 'agent'"
      end
    end

    def macro text
      return Flok.macro_process(text)
      #out = StringIO.new

      #text.split("\n").each do |l|
        ##Request(vc_name, spot_name, context) macro
        #if l =~ /Request/
          #l.strip!
          #l.gsub!(/Request\(/, "")
          #l.gsub! /\)$/, ""
          #l.gsub! /\);$/, ""
          #o = l.split(",").map{|e| e.strip}

          #service_name = o.shift.gsub(/"/, "")
          #info = o.shift.gsub(/"/, "")
          #event_name = o.shift.gsub(/"/, "")

          #out << %{
          #}
        #else
          #out.puts l
        #end
      #end

      #return out.string
    end
  end
end
