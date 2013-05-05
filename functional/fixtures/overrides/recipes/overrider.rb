include_customized_recipe("overrides::overridee") do |r|
  r.define(:test_value).as("overrider")
end
