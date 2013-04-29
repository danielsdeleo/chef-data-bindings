module ChefDataBindings

  module MonkeyPatcher

    module RunContextPatch

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
          cookbook.load_customized_recipe(recipe_short_name, self, override_context)
        end
      end
    end

    module CookbookVersionPatch

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

    module ResourcePatch
      def self.install_patch
        if Chef::Resource.instance_methods(false).include?(:params=)
          Chef::Resource.send(:remove_method, :params=)
        end
        Chef::Resource.send(:include, self)
      end

      def params=(new_params)
        if data_bindings = new_params[:bindings]
          global_context   = data_bindings[:global]
          local_context    = data_bindings[:local]
          override_context = data_bindings[:override]

          extend global_context if global_context
          extend local_context
          extend override_context if override_context
        end

        @params = new_params
        @params
      end

      def binding_context
        self
      end
    end

    def self.install_monkey_patches
      Chef::Recipe.send(:include, ChefDataBindings::Definition)
      Chef::RunContext.send(:include, RunContextPatch)
      Chef::CookbookVersion.send(:include, CookbookVersionPatch)
      ResourcePatch.install_patch
    end
  end
end

