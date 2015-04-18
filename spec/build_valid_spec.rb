#This spec checks to make sure that for each driver, the emitted javascript file actually executes correctly
#In addition, it runs a sanity check by calling flok()

require 'execjs'
require 'helpers'
require 'flok/build'

def build_world_for_platform platform
  Flok.system!("rake build_world PLATFORM=#{platform}")
end

RSpec.describe "Emitted build products are valid for all platforms" do
  it "can run application.js on execjs environment without runtime initial failure" do
    #get a list of the platforms based on the drev folder names
    platforms = (Dir["./app/drivers/*"]).map!{|e| File.basename(e)} - ["iface"]

    platforms.each do |p|
      puts "testing #{p}"
      puts "\t-building world for $platform=#{p}"
      build_world_for_platform(p)

      puts "\t-executing world"
      ctx = ExecJS.compile(File.read("./products/#{p}/application.js"))
    end
  end

  it "can run application.js and supports IFACES" do
    #get a list of the platforms based on the drev folder names
    platforms = (Dir["./app/drivers/*"]).map!{|e| File.basename(e)} - ["iface"]

    platforms.each do |p|
      puts "testing #{p}"
      puts "\t-building world for $platform=#{p}"
      build_world_for_platform(p)

      puts "\t-executing world"
      ctx = ExecJS.compile(File.read("./products/#{p}/application.js"))
      ifaces = ctx.eval("IFACES")
    end
  end

end
