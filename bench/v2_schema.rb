require 'benchmark/ips'
require 'parametric'
require 'parametric/v2'

module Types
  include Parametric::V2::Types
end

LegacySchema = Parametric::Schema.new do |sc, _|
  sc.field(:name).type(:string).default('Mr')
  sc.field(:friend).schema do |s|
    s.field(:name).type(:string)
    s.field(:age).type(:integer)
  end
end

V2Schema = Parametric::V2::Schema.new do |sc|
  sc.field(:name).type(Types::String).default('Mr')
  sc.field(:friend).schema do |s|
    s.field(:name).type(Types::String)
    s.field(:age).type(Types::Lax::Integer)
  end
end

V2Hash = Types::Hash[
  name: Types::String,
  friend: Types::Hash[
    name: Types::String,
    age: Types::Lax::Integer
  ]
]

data = {
  name: 'Ismael',
  friend: {
    name: 'Joe',
    age: '42'
  },
  foo: 'bar'
}

# result = Parametric::V2::Result.wrap(data)

# p result
# p V2Schema.call(result)
Benchmark.ips do |x|
  x.report('Parametric::Schema') {
    LegacySchema.resolve(data)
  }
  x.report('Parametric::V2::Schema') {
    V2Schema.resolve(data)
  }
  # x.report('Parametric::V2::Hash') {
  #   V2Hash.resolve(data)
  # }
  x.compare!
end
