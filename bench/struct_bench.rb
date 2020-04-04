require 'benchmark/ips'
require 'parametric/struct'

StructAccount = Struct.new(:id, :email, keyword_init: true)
StructFriend = Struct.new(:name, keyword_init: true)
StructUser = Struct.new(:name, :age, :friends, :account, keyword_init: true)

class ParametricAccount
  include Parametric::Struct
  schema do
    field(:id).type(:integer).present
    field(:email).type(:string)
  end
end

class ParametricUser
  include Parametric::Struct
  schema do
    field(:name).type(:string).present
    field(:age).type(:integer).default(42)
    field(:friends).type(:array).schema do
      field(:name).type(:string).present
    end
    field(:account).type(:object).schema ParametricAccount
  end
end

Benchmark.ips do |x|
  x.report("Struct") {
    StructUser.new(
      name: 'Ismael',
      age: 42,
      friends: [
        StructFriend.new(name: 'Joe'),
        StructFriend.new(name: 'Joan'),
      ],
      account: StructAccount.new(id: 123, email: 'my@account.com')
    )
  }
  x.report("Parametric::Struct")  {
    ParametricUser.new!(
      name: 'Ismael',
      age: 42,
      friends: [
        { name: 'Joe' },
        { name: 'Joan' }
      ],
      account: { id: 123, email: 'my@account.com' }
    )
  }
  x.compare!
end

