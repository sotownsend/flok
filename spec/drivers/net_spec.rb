require 'phantomjs'
require 'rspec/wait'
require 'webrick'
require "./spec/helpers"
require 'json'

RSpec.describe "Drivers::Net" do
  before(:all) do
    #Respond to kill
    @killable = []
  end

  after(:all) do
    @killable ||= []
    @killable.each {|p| p.kill}

    #Stopgap to kill everything
    `ps -ax | grep net_spec | awk '{print $1}' | grep -v #{Process.pid} | xargs kill -9`
    `ps -ax | grep phantomjs| awk '{print $1}' | xargs kill -9`
  end

  it "can make a get request" do
    #Build driver
    `cd ./app/drivers/browser; rake build`

    cr = ChromeRunner.new "./products/drivers/browser.js"

    #Setup rspec test server
    called = false
    spek = Webbing.get "/" do |params|
      called = true
      {"hello" => "world"}.to_json
    end
    @killable << spek
    cr.eval "drivers.network.request('GET', 'http://localhost:#{spek.port}', {})"
    cr.commit

    #Load synchronously, but execute the code asynchronously, quit after it's been running for 3 seconds
    wait(3).for { called }.to eq(true)
  end

  it "can make a get request with parameters" do
    #Build driver
    `cd ./app/drivers/browser; rake build`

    cr = ChromeRunner.new "./products/drivers/browser.js"

    #Setup rspec test server
    called = false
    result = {}
    spek = Webbing.get "/" do |params|
      result = params
      called = true
      {"hello" => "world"}.to_json
    end
    @killable << spek
    cr.eval "drivers.network.request('GET', 'http://localhost:#{spek.port}', {'a':'b'})"
    cr.commit

    #Load synchronously, but execute the code asynchronously, quit after it's been running for 3 seconds
    wait(3).for { called }.to eq(true)
    expect(result).to eq({'a' => 'b'})
  end

  it "can make a get and respond from callback" do
    #Build driver
    `cd ./app/drivers/browser; rake build`

    cr = ChromeRunner.new "./products/drivers/browser.js"

   #Setup rspec test server
    @spek = Webbing.get "/" do |params|
      {"port" => @spek2.port}.to_json
    end

    called = false
    @spek2 = Webbing.get "/" do |params|
      called = true
    end

    @killable << @spek
    @killable << @spek2
    cr.eval %{
      drivers.network.request('GET', 'http://localhost:#{@spek.port}', {}, function(res) {
        port = res.port;
        drivers.network.request('GET', 'http://localhost:'+port, {});
      })
    }
    cr.commit

    ##Load synchronously, but execute the code asynchronously, quit after it's been running for 3 seconds
    wait(3).for { called }.to eq(true)
  end
end
