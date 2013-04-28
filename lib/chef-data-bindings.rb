require 'chef-data-bindings/errors'
require 'chef-data-bindings/definition'
require 'chef-data-bindings/monkey_patcher'

module ChefDataBindings
  def self.init
    MonkeyPatcher.install_monkey_patches
  end
end
