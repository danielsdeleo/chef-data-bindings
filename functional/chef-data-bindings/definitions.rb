require File.expand_path('../../spec_helper', __FILE__)

describe "Data definitions in recipes" do

  before do
    TestMessages.reset
  end

  def run_chef(*run_list)
    Ohai::Config[:disabled_plugins].clear
    Ohai::Config[:disabled_plugins] << 'darwin::system_profiler' << 'darwin::kernel' << 'darwin::ssh_host_key' << 'network_listeners'
    Ohai::Config[:disabled_plugins] << 'darwin::uptime' << 'darwin::filesystem' << 'dmi' << 'lanuages' << 'perl' << 'python' << 'java' 
    Ohai::Config[:disabled_plugins] << 'c' << 'php' << 'mono' << 'groovy' << 'lua' << 'erlang'

    Chef::Config[:solo] = true
    Chef::Config[:cookbook_path] = File.expand_path("../../fixtures", __FILE__)
    Chef::Config[:client_fork] = false
    client = Chef::Client.new({"run_list" => run_list})
    client.run
    client
  end

  it "Adds the data binding definition API to recipes" do
    run_chef("init-data-bindings::init")
    message = TestMessages.read[0]
    expect(message[0]).to eql(:recipe_methods)
    expect(message[1]).to include(:define)
  end

  it "defines a static value in recipe scope" do
    run_chef("init-data-bindings::init", "static-value::recipe-scope")
    message = TestMessages.read[1]

    expect(message[0]).to eql(:binding_call)
    expect(message[1]).to eql("expected result")
  end

  it "defines a static value in recipe scope and reads it in resource scope" do
    run_chef("init-data-bindings::init", "static-value::resource-scope")
    message = TestMessages.read[1]

    expect(message[0]).to eql(:resource_scope)
    expect(message[1]).to eql("expected result")
  end
end
