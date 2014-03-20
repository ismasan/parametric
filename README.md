# Parametric
[![Build Status](https://travis-ci.org/ismasan/parametric.png)](https://travis-ci.org/ismasan/parametric)
[![Gem Version](https://badge.fury.io/rb/parametric.png)](http://badge.fury.io/rb/parametric)

DSL for declaring allowed parameters with options, regexp patern and default values.

Useful for building self-documeting APIs, search or form objects.

## Usage

Declare your parameters

```ruby
class OrdersSearch
  include Parametric::Params
  param :q, 'Full text search query'
  param :page, 'Page number', default: 1
  param :per_page, 'Items per page', default: 30
  param :status, 'Order status', options: ['checkout', 'pending', 'closed', 'shipped'], multiple: true
end
```

Populate and use. Missing keys return defaults, if provided.

```ruby
order_search = OrdersSearch.new(page: 2, q: 'foobar')
order_search.params[:page] # => 2
order_search.params[:per_page] # => 30
order_search.params[:q] # => 'foobar'
order_search.params[:status] # => nil
```

Undeclared keys are ignored.

```ruby
order_search = OrdersSearch.new(page: 2, foo: 'bar')
order_params.params.has_key?(:foo) # => false
```

```ruby
order_search = OrderParams.new(status: 'checkout,closed')
order_search.params[:status] #=> ['checkout', 'closed']
```

### Search object pattern

A class that declares allowed params and defaults, and builds a query.

```ruby
class OrdersSearch
  include Parametric::Params
  param :q, 'Full text search query'
  param :page, 'Page number', default: 1
  param :per_page, 'Items per page', default: 30
  param :status, 'Order status', options: ['checkout', 'pending', 'closed', 'shipped'], multiple: true
  param :sort, 'Sort', options: ['updated_on-desc', 'updated_on-asc'], default: 'updated_on-desc'

  def results
    query = Order.sort(params[:sort])
    query = query.where(["code LIKE ? OR user_name ?", params[:q]]) if params[:q]
    query = query.where(status: params[:status]) if params[:status].any?
    query = query.paginate(page: params[:page], per_page: params[:per_page])
  end
end
```

### :match

Pass a regular expression to match parameter value. Non-matching values will be ignored or use default value, if available.

```ruby
class OrdersSearch
  include Parametric::Params
  param :email, 'Valid email address', match: /\w+@\w+\.\w+/
end
```

### :options array

Declare allowed values in an array. Values not in the options will be ignored or use default value.

```ruby
class OrdersSearch
  include Parametric::Params
  param :sort, 'Sort', options: ['updated_on-desc', 'updated_on-asc'], default: 'updated_on-desc'
end
```

### :multiple values

`:multiple` values are separated on "," and treated as arrays.

```ruby
class OrdersSearch
  include Parametric::Params
  param :status, 'Order status', multiple: true
end

search = OrdersSearch.new(status: 'closed,shipped,abandoned')
search.params[:status] # => ['closed', 'shipped', 'abandoned']
```

If `:options` array is declared, values outside of the options will be filtered out.

```ruby
class OrdersSearch
  include Parametric::Params
  param :status, 'Order status', options: ['checkout', 'pending', 'closed', 'shipped'], multiple: true
end

search = OrdersSearch.new(status: 'closed,shipped,abandoned')
search.params[:status] # => ['closed', 'shipped']
```

When using `:multiple`, results and defaults are always returned as an array, for consistency.

```ruby
class OrdersSearch
  include Parametric::Params
  param :status, 'Order status', multiple: true, default: 'closed'
end

search = OrdersSearch.new
search.params[:status] # => ['closed']
```

## `available_params`

`#available_params` returns the subset of keys that were populated (including defaults). Useful for building query strings.

```ruby
order_search = OrdersSearch.new(page: 2, foo: 'bar')
order_search.available_params # => {page: 2, per_page: 50}
```

## `schema`

`#schema` returns a data structure including meta-data on each parameter, such as "label" and "options". Useful for building forms or self-documented Hypermedia APIs (or maybe [json-schema](http://json-schema.org/example2.html) endpoints).

```ruby
order_search.schema[:q].label # => 'Full text search query'
order_search.schema[:q].value # => ''

order_search.schema[:page].label # => 'Page number'
order_search.schema[:page].value # => 1

order_search.schema[:status].label # => 'Order status'
order_search.schema[:status].value # => ['pending']
order_search.schema[:status].options # => ['checkout', 'pending', 'closed', 'shipped']
order_search.schema[:status].multiple # => true
order_search.schema[:status].default # => 'closed'
```

## Parametric::Hash

The alternative `Parametric::Hash` class makes your objects quack like a hash, instead of exposing the `#params` object directly.

```ruby
class OrdersParams < Parametric::Hash
  param :q, 'Full text search query'
  param :page, 'Page number', default: 1
  param :per_page, 'Items per page', default: 30
  param :status, 'Order status', options: ['checkout', 'pending', 'closed', 'shipped'], multiple: true
end
```

```ruby
order_params = OrdersParams.new(page: 2, q: 'foobar')
order_params[:page] # => 2
order_params[:per_page] # => 30
order_params.each{|key, value| ... }
```

## Nested structures

You can also nest parameter definitions. This is useful if you need to model POST payloads, for example.

```ruby
class AccountPayload
  include Parametric::Params
  param :status, 'Account status', default: 'pending', options: ['pending', 'active', 'cancelled']
  param :users, 'Users in this account', multiple: true do
    param :name, 'User name'
    param :title, 'Job title', default: 'Employee'
    param :email, 'User email', match: /\w+@\w+\.\w+/
  end
  param :owner, 'Owner user' do
    param :name, 'User name'
    param :email, 'User email', match: /\w+@\w+\.\w+/
  end
end
```

The example above expects a data structure like the following:

```ruby
{
  status: 'active',
  users: [
    {name: 'Joe Bloggs', email: 'joe@bloggs.com'},
    {name: 'jane Bloggs', email: 'jane@bloggs.com', title: 'CEO'}
  ],
  owner: {
    name: 'Olivia Owner',
    email: 'olivia@owner.com'
  }
}
```

## Use cases

### In Rails

You can use one-level param definitions in GET actions

```ruby
def index
  @search = OrdersSearch.new(params)
  @results = @search.results
end
```

I use this along with [Oat](https://github.com/ismasan/oat) in API projects:

```ruby
def index
  search = OrdersSearch.new(params)
  render json: OrdersSerializer.new(search)
end
```

You can use nested definitions on POST/PUT actions, for example as part of your own strategy objects.

```ruby
def create
  @payload = AccountPayload.new(params)
  if @payload.save
    render json: AccountSerializer.new(@payload.order)
  else
    render json: ErrorSerializer.new(@payload.errors), status: 422
  end
end
```

You can also use the `#schema` metadata to build Hypermedia "actions" or forms.

```ruby
# /accounts/new.json
def new
  @payload = AccountPayload.new
  render json: JsonSchemaSerializer.new(@payload.schema)
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
