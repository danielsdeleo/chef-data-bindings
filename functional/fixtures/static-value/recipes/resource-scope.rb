define(:test_value).as("expected result")

ruby_block("make test pass") do
  executed_in_resource_scope = test_value
  block do
    TestMessages.push([:resource_scope, executed_in_resource_scope])
  end
end
