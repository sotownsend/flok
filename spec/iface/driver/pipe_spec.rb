Dir.chdir File.join File.dirname(__FILE__), '../../../'
require './spec/env/iface.rb'

RSpec.describe "iface:driver:pipe_spec" do
  include_context "iface:driver"
  pipe_suite
end