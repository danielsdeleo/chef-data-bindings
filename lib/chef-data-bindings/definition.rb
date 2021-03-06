require 'chef-data-bindings/bind_types'
module ChefDataBindings
  module Definition

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
      setup_bindings("#{recipe_name}::#{cookbook_name}", nil, nil) if need_to_setup?
      @local_context.define(*args, &block)
    end

    def need_to_setup?
      @local_context.nil?
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

      # this is also unfortunate. We use an otherwise useless object
      # passed in to Chef::Resource objects when created to add our
      # binding contexts to resources
      @params = {:bindings => {:global => @global_context, :local => @local_context, :override => @override_context}}

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
end


