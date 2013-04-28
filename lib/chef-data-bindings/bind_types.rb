module ChefDataBindings
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
end
