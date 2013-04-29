# Chef Data Binding DSL

This code implements a data binding DSL for Chef. It's basically a
wrapper for reusable functions in your recipes. If you've used RSpec
2's `let` bindings, this is pretty much the same thing, but in a Chef
flavor.

This code is work-in-progress; the feature set and API may change quite
a bit. The ultimate goal is to determine if this idea is useful enough
to become a part of core Chef, therefore all feedback is welcome.

## Installation

Installation is a work in progress. At some point I'll add a cookbook to
this repo that will install the code for you.

## Usage

### Definition

#### Static Values

```ruby
define(:listen_address).as("0.0.0.0")
```

#### Lambda Values

```ruby
define(:random_number) { Kernel.rand(42) }
```

#### Node Attribute Values

```ruby
define(:server_hostname).as_attribute(:ec2, :public_hostname)
```

#### Search Queries

_not implemented yet_ (but can be done with lambdas)

#### Data Bags

_not implemented yet_ (but can be done with lambdas)

### Reading Values

Under the hood, data bindings are just ruby methods, so you call them
like any other method:

```ruby
define(:config_file_path).as("/etc/app.conf")
define(:config_file_owner).as("app_user")

# Usage in recipe context:
template config_file_path do
  # usage in resource context
  owner config_file_owner
end
```

The above is equivalent to:

```ruby
template "/etc/app.conf" do
  owner "app_user"
end
```


### Overriding Values

_API in progress..._

## Motivation

This proposal combines a handful of ideas I've been gnawing on for a few
years now:

### Lightweight Data Source Abstraction

Chef data bindings provides a _consistent_ and _overridable_ abstraction
layer between data and its source. This is intented to provide a handful
of benefits:

1. Maintainability of first-party (i.e., *your own*) cookbooks: by using
   data bindings to define the pieces of data used by your cookbooks,
   you can later change the source of that data between node attributes,
   data bags, search, or arbitrary ruby code in a single place.
2. Cookbook portability: by overriding data bindings in wrapper
   cookbooks, your client/server specific cookbooks can be used with
   chef-solo for development or testing.
3. Recipe readability: by binding data to names that make sense in the
   context of what a recipe does and stripping the rest, your recipes
   become more readable.

### Better Trainwreck Errors

In the Ruby on Rails community, a `NoMethodError` on `NilClass`
generated inside a chain of method calls (e.g.,
`post.comments.first.author`) is called a trainwreck. In Chef we see the
same issue with node attributes. I think the most viable solution to
this problem is to lookup nested attributes as a group: instead of
asking for the value of `postgres`, getting a value, then asking that
value for `server`, getting a result and asking it for `shared_mem_max`,
we can create a single query with that search path. With the additional
context, you won't magically fix the trainwreck, but you can give a much
better error message, like this:

> You tried to get the value of `node['foo']['bar']['baz']`, but
`node['foo']['bar']` is nil. You must set these attributes correctly for
cookbook "monkeypants" to function.

### Readability

This is mentioned above, but it deserves more discussion.  I've been
unhappy with what I would call "attribute sprawl" or "attribute
spaghetti" for quite a while (<strong>NOTE:</strong> This is not any
cookbook author's fault, because attributes are the only real way to
pass input into a recipe). Look at any popular cookbook, and you see
that in order to meet everyone's use case, you have attributes for
everything, even attributes used as keys to look up other attributes.
This drives me nuts when I'm reading a new cookbook because I can hardly
tell what it's doing without keeping the value of a half dozen
attributes in my head.  So I've been looking for a customization
mechanism that's easier to understand.

