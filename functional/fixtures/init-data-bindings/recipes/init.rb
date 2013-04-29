$:.unshift File.expand_path("../../../../../lib/", __FILE__)

require 'chef-data-bindings'
ChefDataBindings.init

::TestMessages.push([:recipe_methods, methods])
