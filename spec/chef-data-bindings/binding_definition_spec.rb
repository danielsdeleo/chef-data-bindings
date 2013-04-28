require 'spec_helper'

class DataBindingImplementor
  include ChefDataBindings::Definition
end

describe ChefDataBindings, "data binding definition API" do

  let(:iteration) do
    $iteration ||= -1
    $iteration += 1
  end

  let(:override_context) { nil }

  let(:global_context) { nil }

  let(:recipe) do
    r = DataBindingImplementor.new
    r.setup_bindings("cookbook::some-recipe#{iteration}", override_context, global_context)
    r
  end

  describe "static data bindings" do

    it "binds a name to a value" do
      recipe.define(:named_value).as("the value")
      recipe.named_value.should == "the value"
    end

  end

  describe "binding a proc" do
    it "binds a name to a proc/lambda" do
      recipe.define(:lambda_value) do
        "this is a lambda value"
      end

      recipe.lambda_value.should == "this is a lambda value"
    end
  end

  describe "binding to node data" do
    let(:node) do
      Chef::Node.new.tap do |n|
        n.automatic_attrs[:ec2][:public_hostname] = "foo.ec2.example.com"
      end
    end

    before do
      recipe.stub!(:node).and_return(node)
    end

    it "binds a name to an attribute path" do
      recipe.define(:public_hostname).as_attribute(:ec2, :public_hostname)
      recipe.public_hostname.should == "foo.ec2.example.com"
    end

    it "raises a not-enraging error message when an intermediate value is nil" do
      recipe.define(:oops).as_attribute(:ec2, :no_attr_here, :derp)
      error_class = ChefDataBindings::Definition::BindTypes::AttributePath::MissingNodeAttribute
      error_message = "Error finding value `oops' from attributes `node[:ec2][:no_attr_here][:derp]`: `node[:ec2][:no_attr_here]` is nil"
      lambda { recipe.oops }.should raise_error(error_class, error_message)
    end
  end

  describe "binding to search results" do
    it "binds a name to a search query" do
      pending "TODO"
      recipe.define(:searchy).as_search_result(:node, "*:*")
      # todo stubz
      recipe.searchy.should == [node1, node2]
    end

    it "binds a name to a partial search query" do
      pending "TODO"
      recipe.define(:p_searchy).as_search_result(:node, "id:*foo*") do |item|
        item.define(:name).as_attribute(:name)
        item.define(:ip).as_attribute(:ipaddress)
        item.define(:kernel_version).as_attribute(:kernel, :version)
      end
      # todo stubz
      recipe.p_searchy[0][:name].should == "node_name"
      recipe.p_searchy[0][:ip].should == "123.45.67.89"
      recipe.p_searchy[0]
    end

  end

  describe "overriding bindings" do

    let(:global_context) do
      ChefDataBindings::Definition::BindingContext.for_name("GlobalContext#{iteration}")
    end

    let(:override_context) do
      ChefDataBindings::Definition::BindingContext.for_name("override cookbook::some_recipe-#{iteration}")
    end

    it "defaults to a global definition if no others override it" do
      global_context.define(:global_thing).as("follow you wherever you may go")
      recipe.global_thing.should == "follow you wherever you may go"
    end

    it "overrides a local definition" do
      override_context.define(:named_thing).as("party time")
      recipe.define(:named_thing).as("sad time")

      recipe.named_thing.should == "party time"
    end

  end

end
