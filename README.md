# Parametric
[![Build Status](https://travis-ci.org/ismasan/parametric.png)](https://travis-ci.org/ismasan/parametric)
[![Gem Version](https://badge.fury.io/rb/parametric.png)](http://badge.fury.io/rb/parametric)

Declaratively define data schemas in your Ruby objects, and use them to whitelist, validate or transform inputs to your programs.

Useful for building self-documeting APIs, search or form objects. Or possibly as an alternative to Rails' _strong parameters_ (it has no dependencies on Rails and can be used stand-alone).

## Schema

Define a schema

```ruby
schema = Parametric::Schema.new do
  field(:title).type(:string).present
  field(:status).options(["draft", "published"]).default("draft")
  field(:tags).type(:array)
end
```

Populate and use. Missing keys return defaults, if provided.

```ruby
form = schema.resolve(title: "A new blog post", tags: ["tech"])

form.output # => {title: "A new blog post", tags: ["tech"], status: "draft"}
form.errors # => {}
```

Undeclared keys are ignored.

```ruby
form = schema.resolve(foobar: "BARFOO", title: "A new blog post", tags: ["tech"])

form.output # => {title: "A new blog post", tags: ["tech"], status: "draft"}
```

Validations are run and errors returned


```ruby
form = schema.resolve({})
form.errors # => {"$.title" => ["is required"]}
```

If options are defined, it validates that value is in options

```ruby
form = schema.resolve({title: "A new blog post", status: "foobar"})
form.errors # => {"$.status" => ["expected one of draft, published but got foobar"]}
```

## Nested schemas

A schema can have nested schemas, for example for defining complex forms.

```ruby
person_schema = Parametric::Schema.new do
  field(:name).type(:string).required
  field(:age).type(:integer)
  field(:friends).type(:array).schema do
    field(:name).type(:string).required
    field(:email).validate(:email)
  end
end
```

It works as expected

```ruby
results = person_schema.resolve(
  name: "Joe",
  age: "38",
  friends: [
    {name: "Jane", email: "jane@email.com"}
  ]
)

results.output # => {name: "Joe", age: 38, friends: [{name: "Jane", email: "jane@email.com"}]}
```

Validation errors use [JSON path](http://goessner.net/articles/JsonPath/) expressions to describe errors in nested structures

```ruby
results = person_schema.resolve(
  name: "Joe",
  age: "38",
  friends: [
    {email: "jane@email.com"}
  ]
)

results.errors # => {"$.friends[0].name" => "is required"}
```

### Reusing nested schemas

You can optionally use an existing schema instance as a nested schema:

```ruby
friends_schema = Parametric::Schema.new do
  field(:friends).type(:array).schema do
    field(:name).type(:string).required
    field(:email).validate(:email)
  end
end

person_schema = Parametric::Schema.new do
  field(:name).type(:string).required
  field(:age).type(:integer)
  # Nest friends_schema
  field(:friends).type(:array).schema(friends_schema)
end
```

## Built-in policies

Type coercions (the `type` method) and validations (the `validate` method) are all _policies_.

Parametric ships with a number of built-in policies.

### :string

Calls `:to_s` on the value

```ruby
field(:title).type(:string)
```

### :integer

Calls `:to_i` on the value

```ruby
field(:age).type(:integer)
```

### :number

Calls `:to_f` on the value

```ruby
field(:price).type(:number)
```

### :boolean

Returns `true` or `false` (`nil` is converted to `false`).


```ruby
field(:published).type(:boolean)
```

### :format

Check value against custom regexp

```ruby
field(:salutation).validate(:format, /^Mr\/s/)
# optional custom error message
field(:salutation).validate(:format, /^Mr\/s\./, "must start with Mr/s.")
```

### :email

```ruby
field(:business_email).validate(:email)
```

### :required

Check that the key exists in the input.

```ruby
field(:name).required

# same as
field(:name).validate(:required)
```

Note that _required_ does not validate that the value is not empty. Use _present_ for that.

### :present

Check that the key exists and the value is not blank.

```ruby
field(:name).present

# same as
field(:name).validate(:present)
```

If the value is a `String`, it validates that it's not blank. If an `Array`, it checks that it's not empty. Otherwise it checks that the value is not `nil`.

### :declared

Check that a key exists in the input, or stop any further validations otherwise.
This is useful when chained to other validations. For example:

```ruby
field(:name).declared.present
```

The example above will check that the value is not empty, but only if the key exists. If the key doesn't exist no validations will run.

### :gt

Validate that the value is greater than a number

```ruby
field(:age).validate(:gt, 21)
```

### :lt

Validate that the value is less than a number

```ruby
field(:age).validate(:lt, 21)
```

### :options

Pass allowed values for a field

```ruby
field(:status).options(["draft", "published"])

# Same as
field(:status).validate(:options, ["draft", "published"])
```

### :split

Split comma-separated string values into an array.
Useful for parsing comma-separated query-string parameters.

```ruby
field(:status).policy(:split) # turns "pending,confirmed" into ["pending", "confirmed"]
```

## Custom policies

You can also register your own custom policy objects. A policy must implement the following methods:

```ruby
class MyPolicy
  # Validation error message, if invalid
  def message
    'is invalid'
  end

  # Whether or not to validate and coerce this value
  # if false, no other policies will be run on the field
  def eligible?(value, key, payload)
    true
  end

  # Transform the value
  def coerce(value, key, context)
    value
  end

  # Is the value valid?
  def valid?(value, key, payload)
    true
  end
end
```

You can register your policy with:

```ruby
Parametric.policy :my_policy, MyPolicy
```

And then refer to it by name when declaring your schema fields

```ruby
field(:title).policy(:my_policy)
```

You can chain custom policies with other policies.

```ruby
field(:title).required.policy(:my_policy)
```

Note that you can also register instances.

```ruby
Parametric.policy :my_policy, MyPolicy.new
```

For example, a policy that can be configured on a field-by-field basis:

```ruby
class AddJobTitle
  def initialize(job_title)
    @job_title = job_title
  end

  def message
    'is invalid'
  end

  # Noop
  def eligible?(value, key, payload)
    true
  end

  # Add job title to value
  def coerce(value, key, context)
    "#{value}, #{@job_title}"
  end

  # Noop
  def valid?(value, key, payload)
    true
  end
end

# Register it
Parametric.policy :job_title, AddJobTitle
```

Now you can reuse the same policy with different configuration

```ruby
manager_schema = Parametric::Schema.new do
  field(:name).type(:string).policy(:job_title, "manager")
end

cto_schema = Parametric::Schema.new do
  field(:name).type(:string).policy(:job_title, "CTO")
end

manager_schema.resolve(name: "Joe Bloggs").output # => {name: "Joe Bloggs, manager"}
cto_schema.resolve(name: "Joe Bloggs").output # => {name: "Joe Bloggs, CTO"}
```

## Custom policies, short version

For simple policies that don't need all policy methods, you can:

```ruby
Parametric.policy :cto_job_title do
  coerce do |value, key, context|
    "#{value}, CTO"
  end
end

# use it
cto_schema = Parametric::Schema.new do
  field(:name).type(:string).policy(:cto_job_title)
end
```

```ruby
Parametric.policy :over_21_and_under_25 do
  coerce do |age, key, context|
    age.to_i
  end

  validate do |age, key, context|
    age > 21 && age < 25
  end
end
```

## Cloning schemas

The `#clone` method returns a new instance of a schema with all field definitions copied over.

```ruby
new_schema = original_schema.clone
```

New copies can be further manipulated without affecting the original.

```ruby
# See below for #policy and #ignore
new_schema = original_schema.clone.policy(:declared).ignore(:id) do |sc|
  field(:another_field).present
end
```

## Merging schemas

The `#merge` method will merge field definitions in two schemas and produce a new schema instance.

```ruby
basic_user_schema = Parametric::Schema.new do
  field(:name).type(:string).required
  field(:age).type(:integer)
end

friends_schema = Parametric::Schema.new do
  field(:friends).type(:array).schema do
    field(:name).required
    field(:email).validate(:email)
  end
end

user_with_friends_schema = basic_user_schema.merge(friends_schema)

results = user_with_friends_schema.resolve(input)
```

Fields defined in the merged schema will override fields with the same name in the original schema.

```ruby
required_name_schema = Parametric::Schema.new do
  field(:name).required
  field(:age)
end

optional_name_schema = Parametric::Schema.new do
  field(:name)
end

# This schema now has :name and :age fields.
# :name has been redefined to not be required.
new_schema = required_name_schema.merge(optional_name_schema)
```

## #meta

The `#meta` field method can be used to add custom meta data to field definitions.
These meta data can be used later when instrospecting schemas (ie. to generate documentation or error notices).

```ruby
create_user_schema = Parametric::Schema.do
  field(:name).required.type(:string).meta(label: "User's full name")
  field(:status).options(["published", "unpublished"]).default("published")
  field(:age).type(:integer).meta(label: "User's age")
  field(:friends).type(:array).meta(label: "User friends").schema do
    field(:name).type(:string).present.meta(label: "Friend full name")
    field(:email).validate(:email).meta(label: "Friend's email")
  end
end
```

## #schema

A `Schema` instance has a `#schema` method that allows instrospecting schema meta data.

```ruby
create_user_schema.schema[:name].label # => "User's full name"
create_user_schema.schema[:age].label # => "User's age"
create_user_schema.schema[:friends].label # => "User friends"
# Recursive schema data
create_user_schema.schema[:friends].schema[:name].label # => "Friend full name"
```

Note that many field methods add field meta data.

```ruby
create_user_schema.schema[:name].type # => :string
create_user_schema.schema[:name].required # => true
create_user_schema.schema[:status].options # => ["published", "unpublished"]
create_user_schema.schema[:status].default # => "published"
```

## #walk

The `#walk` method can recursively walk a schema definition and extract meta data or field attributes.

```ruby
schema_documentation = create_user_schema.walk do |field|
  {type: field.meta_data[:type], label: field.meta_data[:label]}
end

# Returns

{
  name: {type: :string, label: "User's full name"},
  age: {type: :integer, label: "User's age"},
  status: {type: :string, label: nil},
  friends: [
    {
      name: {type: :string, label: "Friend full name"},
      email: {type: nil, label: "Friend email"}
    }
  ]
}
```

When passed a _symbol_, it will collect that key from field meta data.

```ruby
schema_labels = create_user_schema.walk(:label)

# returns

{
  name: "User's full name",
  age: "User's age",
  status: nil,
  friends: [
    {name: "Friend full name", email: "Friend email"}
  ]
}
```

Potential uses for this are generating documentation (HTML, or [JSON Schema](http://json-schema.org/), [Swagger](http://swagger.io/), or maybe even mock API endpoints with example data.

## Form objects DSL

You can use schemas and fields on their own, or include the `DSL` module in your own classes to define form objects.

```ruby
require "parametric/dsl"

class CreateUserForm
  include Parametric::DSL

  schema do
    field(:name).type(:string).required
    field(:email).validate(:email).required
    field(:age).type(:integer)
  end

  attr_reader :params, :errors

  def initialize(input_data)
    results = self.class.schema.resolve(input_data)
    @params = results.output
    @errors = results.errors
  end

  def run!
    if !valid?
      raise InvalidFormError.new(errors)
    end

    run
  end

  def valid?
    !errors.any?
  end

  private

  def run
    User.create!(params)
  end
end
```

### Form object inheritance

Sub classes of classes using the DSL will inherit schemas defined on the parent class.

```ruby
class UpdateUserForm < CreateUserForm
  # All field definitions in the parent are conserved.
  # New fields can be defined
  # or existing fields overriden
  schema do
    # make this field optional
    field(:name).declared.present
  end

  def initialize(user, input_data)
    super input_data
    @user = user
  end

  private
  def run
    @user.update params
  end
end
```

### Schema-wide policies

Sometimes it's useful to apply the same policy to all fields in a schema.

For example, fields that are _required_ when creating a record might be optional when updating the same record (ie. _PATCH_ operations in APIs).

```ruby
class UpdateUserForm < CreateUserForm
  schema.policy(:declared)
end
```

This will prefix the `:declared` policy to all fields inherited from the parent class.
This means that only fields whose keys are present in the input will be validated.

Schemas with default policies can still define or re-define fields.

```ruby
class UpdateUserForm < CreateUserForm
  schema.policy(:declared) do
    # Validation will only run if key exists
    field(:age).type(:integer).present
  end
end
```

### Ignoring fields defined in the parent class

Sometimes you'll want a child class to inherit most fields from the parent, but ignoring some.

```ruby
class CreateUserForm
  include Parametric::DSL

  schema do
    field(:uuid).present
    field(:status).required.options(["inactive", "active"])
    field(:name)
  end
end
```

The child class can use `ignore(*fields)` to ignore fields defined in the parent.

```ruby
class UpdateUserForm < CreateUserForm
  schema.ignore(:uuid, :status) do
    # optionally add new fields here
  end
end
```

## Schema options

Another way of modifying inherited schemas is by passing options.

```ruby
class CreateUserForm
  include Parametric::DSL

  schema(default_policy: :noop) do |opts|
    field(:name).validate(opts[:default_policy]).type(:string).required
    field(:email).validate(opts[:default_policy).validate(:email).required
    field(:age).type(:integer)
  end

  # etc
end
```

The `:noop` policy does nothing. The sub-class can pass it's own _default_policy_.

```ruby
class UpdateUserForm < CreateUserForm
  # this will only run validations keys existing in the input
  schema(default_policy: :declared)
end
```

## A pattern: changing schema policy on the fly.

You can use a combination of `#clone` and `#policy` to change schema-wide field policies on the fly.

For example, you might have a form object that supports creating a new user and defining mandatory fields.

```ruby
class CreateUserForm
  include Parametric::DSL

  schema do
    field(:name).present
    field(:age).present
  end

  attr_reader :errors, :params

  def initialize(payload: {})
    @payload = payload
    results = self.class.schema.resolve(params)
    @errors = results.errors
    @params = results.output
  end

  def run!
    User.create(params)
  end
end
```

Now you might want to use the same form object to _update_ and existing user supporting partial updates.
In this case, however, attributes should only be validated if the attributes exist in the payload. We need to apply the `:declared` policy to all schema fields, only if a user exists.

We can do this by producing a clone of the class-level schema and applying any necessary policies on the fly.

```ruby
class CreateUserForm
  include Parametric::DSL

  schema do
    field(:name).present
    field(:age).present
  end

  attr_reader :errors, :params

  def initialize(payload: {}, user: nil)
    @payload = payload
    @user = user

    # pick a policy based on user
    policy = user ? :declared : :noop
    # clone original schema and apply policy
    schema = self.class.schema.clone.policy(policy)

    # resolve params
    results = schema.resolve(params)
    @errors = results.errors
    @params = results.output
  end

  def run!
    if @user
      @user.update_attributes(params)
    else
      User.create(params)
    end
  end
end
```

## Installation

Add this line to your application's Gemfile:

    gem 'parametric'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install parametric

## Contributing

1. Fork it ( http://github.com/ismasan/parametric/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
