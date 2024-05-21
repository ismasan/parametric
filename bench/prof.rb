require 'ruby-prof'
require 'parametric/v2'

module Types
  include Parametric::V2::Types
end

V2Schema = Parametric::V2::Schema.new do |sc|
  sc.field(:name).type(Types::String).default('Mr')
  sc.field(:friend).schema do |s|
    s.field(:name).type(Types::String)
    s.field(:age).type(Types::Lax::Integer)
  end
  sc.field(:companies).array do |f|
    f.field(:name).type(Types::String)
  end
end

data = {
  name: 'Ismael',
  friend: {
    name: 'Joe',
    age: '42'
  },
  companies: [
    { name: 'Foo' },
    { name: 'Bar' }
  ],
  foo: 'bar'
}

# result = Parametric::V2::Result.wrap(data)

profile = RubyProf::Profile.new(measure_mode: RubyProf::ALLOCATIONS, track_allocations: true)
result = profile.profile do
  V2Schema.resolve(data)
end

# printer = RubyProf::GraphPrinter.new(result)
printer = RubyProf::GraphHtmlPrinter.new(result)
printer.print(STDOUT, {})
