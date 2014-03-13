# Parametric

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

### In Rails

```ruby
def index
  @search = OrdersSearch.new(params)
  @results = @search.results
end
```

## `available_params`

`#available_params` returns the subset of keys that were populated (including defaults). Useful to build query strings.

```ruby
order_search = OrdersSearch.new(page: 2, foo: 'bar')
order_search.available_params # => {page: 2, per_page: 50}
```

## `schema`

`#schema` returns a data structure including meta-data on each parameter, such as "label" and "options". Useful for building forms or self-documented Hypermedia APIs (or maybe [json-schema](http://json-schema.org/example2.html) endpoints).

```ruby
order_search.schema # =>

{
  q: {label: 'Full text search query', value: ''},
  page: {label: 'Page number', value: 1},
  per_page: {label: 'Items per page', value: 30},
  status: {label: 'Order status', value: '', options: ['checkout', 'pending', 'closed', 'shipped'], multiple: true},
  sort: {label: 'Sort', value: 'updated_on-desc', options: ['updated_on-desc', 'updated_on-asc']}
}
```

## Parametric::Hash

The alternative `Parametric::Hash` module makes your objects quack like a hash, instead of exposing the `#params` object directly.

```ruby
class OrdersParams
  include Parametric::Hash
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

## Installation

Add this line to your application's Gemfile:

    gem 'parametric'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install parametric

## Contributing

1. Fork it ( http://github.com/<my-github-username>/parametric/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
