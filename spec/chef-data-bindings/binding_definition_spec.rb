require 'spec_helper'

module Chef::DSL::DataBindings

  module BindTypes
    class Static
      def initialize(name, value)
        @name = name
        @value = value
      end

      def call(context_object)
        @value
      end
    end

    class Lambda
      def initialize(name, block)
        @name = name
        @block = block
      end

      def call(context_object)
        @block.call
      end
    end

    class AttributePath

      attr_reader :name

      class MissingNodeAttribute < StandardError
      end

      def initialize(name, *path_specs)
        @name = name
        @path_specs = path_specs
      end

      def call(context_object)
        searched_path = []
        @path_specs.inject(context_object.node) do |attrs_so_far, attr_key|
          searched_path << attr_key
          next_attrs = attrs_so_far[attr_key]
          if !next_attrs.nil?
            next_attrs
          else
            current_lookup = "node[:#{searched_path.join('][:')}]"
            desired_lookup = "node[:#{@path_specs.join('][:')}]"
            raise MissingNodeAttribute,
             "Error finding value `#{name}' from attributes `#{desired_lookup}`: `#{current_lookup}` is nil"
          end
        end
      end
    end


  end

  class DataBindingDefinition

    attr_reader :name

    def initialize(name, &block)
      @name = name
      if block_given?
        @data_binding = BindTypes::Lambda.new(name, block)
      else
        @data_binding = nil
      end
    end

    def as(value)
      @data_binding = BindTypes::Static.new(name, value)
    end

    def as_attribute(*path_specs)
      # Target object needs to define #node to return the Chef::Node object
      @data_binding = BindTypes::AttributePath.new(name, *path_specs)
    end

    def call(context_object)
      @data_binding.call(context_object)
    end
  end

  module BindingContext

    def self.for_name(recipe_name)
      # Create a module that is the same as this one for the purposes of #extend
      extension_module = Module.new
      extension_module.extend(self)

      # Create a constant name for the module. Not required, but it makes
      # debugging easier when error messages have real class/module names
      # instead of '#<Module:0x007fe53594e270>'
      clean_name = recipe_name.gsub(/[^\w]/, '_')
      const_base_name = "BindingContextFor_#{clean_name}"
      self.const_set(const_base_name, extension_module)

      extension_module
    end

    def data_bindings
      @data_bindings ||= {}
    end

    def define(binding_name, &block)
      binding_defn = DataBindingDefinition.new(binding_name, &block)
      data_bindings[binding_name] = binding_defn
      define_method(binding_name) do
        binding_defn.call(binding_context)
      end
      binding_defn
    end

  end

  def define(*args, &block)
    @local_context.define(*args, &block)
  end

  # Set up a "class hierarchy" of global_context < local_context < override_context
  def setup_bindings(object_name, override_context, global_context)
    # This is unfortunate, but since Chef recipes are objects and not
    # classes, we're forced to reinvent class hierarchy with metaprogramming :|
    #
    @local_context = BindingContext.for_name(object_name)

    # enable future debugging capabilities
    @override_context = override_context
    @global_context = global_context
    extend global_context if global_context
    extend @local_context
    extend override_context if override_context
    self
  end

  def binding_context
    self
  end

  def include_customized_recipe(recipe_spec, &customizer_block)
    override_context = BindingContext.for_name("Override_#{recipe_spec}")
    unless customizer_block && customizer_block.arity == 1
      raise ArgumentError, "you have to pass a block with 1 argument to #include_customized_recipe"
    end
    customizer_block.call(override_context)

    run_context.load_customized_recipe(recipe_spec, override_context)

  end
end

class Chef::RunContext

  # The definition #load_recipe doesn't give us access to the recipe before it
  # gets evaluated, so we have to monkey patch
  def load_customized_recipe(recipe_name, override_context)
    Chef::Log.debug("Loading Recipe #{recipe_name} via include_recipe")

    cookbook_name, recipe_short_name = Chef::Recipe.parse_recipe_name(recipe_name)
    if loaded_fully_qualified_recipe?(cookbook_name, recipe_short_name)
      Chef::Log.debug("I am not loading #{recipe_name}, because I have already seen it.")
      false
    else
      loaded_recipe(cookbook_name, recipe_short_name)

      cookbook = cookbook_collection[cookbook_name]
      cookbook.load_recipe(recipe_short_name, self, override_context)
    end
  end
end


class Chef::CookbookVersion

  # The definition #load_recipe doesn't give us access to the recipe before it
  # gets evaluated, so we have to monkey patch
  def load_customized_recipe(recipe_name, run_context, override_context)
    unless recipe_filenames_by_name.has_key?(recipe_name)
      raise Chef::Exceptions::RecipeNotFound, "could not find recipe #{recipe_name} for cookbook #{name}"
    end

    Chef::Log.debug("Found recipe #{recipe_name} in cookbook #{name}")
    recipe = Chef::Recipe.new(name, recipe_name, run_context)

    # HERES THE MAGIC
    recipe.setup_bindings("#{name}::#{recipe_name}", override_context, nil) # no global context yet

    recipe_filename = recipe_filenames_by_name[recipe_name]

    unless recipe_filename
      raise Chef::Exceptions::RecipeNotFound, "could not find #{recipe_name} files for cookbook #{name}"
    end

    recipe.from_file(recipe_filename)
    recipe
  end
end

class DataBindingImplementor
  include Chef::DSL::DataBindings
end

describe Chef::DSL::DataBindings do

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
      error_class = Chef::DSL::DataBindings::BindTypes::AttributePath::MissingNodeAttribute
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
      Chef::DSL::DataBindings::BindingContext.for_name("GlobalContext#{iteration}")
    end

    let(:override_context) do
      Chef::DSL::DataBindings::BindingContext.for_name("override cookbook::some_recipe-#{iteration}")
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
