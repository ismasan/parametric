# frozen_string_literal: true

require 'spec_helper'
require 'parametric/types'

include Parametric

RSpec.describe Types do
  describe 'Result' do
    specify 'piping results with #map' do
      init = Result.wrap(10)
      add_tax = ->(r) { r.success(r.value + 5) }
      halt = ->(r) { r.halt }
      result = init.map(add_tax).map(halt).map(add_tax)
      expect(result.value).to eq(15)
    end
  end

  describe 'Step' do
    specify '#>>' do
      step1 = Step.new { |r| r.success(r.value + 5) }
      step2 = Step.new { |r| r.success(r.value - 2) }
      step3 = Step.new { |r| r.halt }
      step4 = ->(minus) { Step.new { |r| r.success(r.value - minus) } }
      pipeline = Types::Any >> step1 >> step2 >> step3 >> ->(r) { r.success(r.value + 1) }

      expect(pipeline.call(10).success?).to be(false)
      expect(pipeline.call(10).value).to eq(13)
      expect((step1 >> step2 >> step4.(1)).call(10).value).to eq(12)
    end

    specify '#transform' do
      to_i = Types::Any.transform(&:to_i)
      plus_ten = Types::Any.transform { |value| value + 10 }
      pipeline = to_i >> plus_ten
      expect(pipeline.call('5').value).to eq(15)
    end

    specify '#check' do
      is_a_string = Types::Any.check('not a string') { |value| value.is_a?(::String) }
      expect(is_a_string.call('yup').success?).to be(true)
      expect(is_a_string.call(10).success?).to be(false)
      expect(is_a_string.call(10).error).to eq('not a string')
    end

    specify '#present' do
      assert_result(Types::Any.present.call, Undefined, false)
      assert_result(Types::Any.present.call(''), '', false)
      assert_result(Types::Any.present.call('foo'), 'foo', true)
      assert_result(Types::Any.present.call([]), [], false)
      assert_result(Types::Any.present.call([1, 2]), [1, 2], true)
      assert_result(Types::Any.present.call(nil), nil, false)
    end

    specify '#is_a' do
      pipeline = Types::Any.is_a(::Integer).transform { |v| v + 5 }
      assert_result(pipeline.call(10), 15, true)
      assert_result(pipeline.call('nope'), 'nope', false)
    end

    specify '#|' do
      integer = Types::Any.is_a(::Integer)
      string = Types::Any.is_a(::String)
      to_s = Types::Any.transform(&:to_s)
      title = Types::Any.transform { |v| "The number is #{v}" }

      pipeline = string | (integer >> to_s >> title)

      assert_result(pipeline.call('10'), '10', true)
      assert_result(pipeline.call(10), 'The number is 10', true)

      pipeline = Types::String | Types::Integer
      failed = pipeline.call(10.3)
      expect(failed.error).to eq(['must be a String', 'must be a Integer'])
    end

    specify '#meta' do
      to_s = Types::Any.transform(&:to_s).meta(type: :string)
      to_i = Types::Any.transform(&:to_i).meta(type: :integer).meta(foo: 'bar')
      pipe = to_s >> to_i
      expect(to_s.metadata[:type]).to eq(:string)
      expect(pipe.metadata[:type]).to eq(:integer)
      expect(pipe.metadata[:foo]).to eq('bar')
    end

    specify '#not' do
      string = Types::Any.check('not a string') { |v| v.is_a?(::String) }
      assert_result(Types::Any.not(string).call(10), 10, true)
      assert_result(Types::Any.not(string).call('hello'), 'hello', false)

      assert_result(string.not.call(10), 10, true)
    end

    specify '#halt' do
      type = Types::Integer.rule(lte: 10).halt(error: 'nope')
      assert_result(type.call(9), 9, false)
      assert_result(type.call(19), 19, true)
      expect(type.call(9).error).to eq('nope')
    end

    specify '#value' do
      assert_result(Types::Any.value('hello').call('hello'), 'hello', true)
      assert_result(Types::Any.value('hello').call('nope'), 'nope', false)
    end

    specify '#static' do
      assert_result(Types::Any.static('hello').call('hello'), 'hello', true)
      assert_result(Types::Any.static('hello').call('nope'), 'hello', true)
      assert_result(Types::Any.static { |_| 'hello' }.call('nope'), 'hello', true)
    end

    specify '#default' do
      assert_result(Types::Any.default('hello').call('bye'), 'bye', true)
      assert_result(Types::Any.default('hello').call(nil), nil, true)
      assert_result(Types::Any.default('hello').call(Undefined), 'hello', true)
      assert_result(Types::String.default('hello').call(Undefined), 'hello', true)
    end

    specify '#bundle' do
      type = (Types::String.value('foo') | Types::String.value('bar')).bundle(error: 'expected foo or bar, but got %s')
      assert_result(type.call('foo'), 'foo', true)
      expect(type.call('nope').error).to eq('expected foo or bar, but got nope')
    end

    specify '#optional' do
      assert_result(Types::String.optional.call('bye'), 'bye', true)
      assert_result(Types::String.call(nil), nil, false)
      assert_result(Types::String.optional.call(nil), nil, true)
    end

    specify '#coerce' do
      assert_result(Types::Any.coerce(::Numeric, &:to_i).call(10.5), 10, true)
      assert_result(Types::Any.coerce(::Numeric, &:to_i).call('10.5'), '10.5', false)
      assert_result(Types::Any.coerce((0..3), &:to_s).call(2), '2', true)
      assert_result(Types::Any.coerce((0..3), &:to_s).call(4), 4, false)
      assert_result(Types::Any.coerce(/true/i) { |_| true }.call('True'), true, true)
      assert_result(Types::Any.coerce(/true/i) { |_| true }.call('TRUE'), true, true)
      assert_result(Types::Any.coerce(/true/i) { |_| true }.call('nope'), 'nope', false)
      assert_result(Types::Any.coerce(1) { |_| true }.call(1), true, true)
    end

    describe '#pipeline' do
      let(:pipeline) do
        Types::Integer.pipeline do |pl|
          pl.step { |r| r.success(r.value * 2) }
          pl.step Types::Any.transform(&:to_s)
          pl.step { |r| r.success('The number is %s' % r.value) }
        end
      end

      it 'builds a step composed of many steps' do
        assert_result(pipeline.call(2), 'The number is 4', true)
        assert_result(pipeline.transform{ |v| v + '!!' }.call(2), 'The number is 4!!', true)
        assert_result(pipeline.call('nope'), 'nope', false)
      end

      it 'is a Steppable and can be further composed' do
        expect(pipeline).to be_a(Parametric::Steppable)
        pipeline2 = pipeline.pipeline do |pl|
          pl.step { |r| r.success(r.value + ' the end') }
        end

        assert_result(pipeline2.call(2), 'The number is 4 the end', true)
      end
    end

    describe Parametric::Pipeline do
      specify '#around' do
        list = []
        counts = 0
        pipeline = described_class.new do |pl|
          pl.step Types::Lax::String
          pl.around do |step, result|
            list << 'before: %s' % result.value
            result = step.call(result)
            list << 'after: %s' % result.value
            result
          end
          pl.step Types::Any.transform { |v| "-#{v}-" }
          pl.around { |step, result| counts += 1; step.call(result) }
          pl.step Types::Any.transform { |v| "*#{v}*" }
        end

        assert_result(pipeline.call(1), '*-1-*', true)
        expect(list).to eq([
          'before: 1',
          'after: -1-',
          'before: -1-',
          'after: *-1-*'
        ])
        expect(counts).to eq(1)
      end
    end

    specify '#constructor' do
      custom = Struct.new(:name) do
        def self.build(name)
          new(name)
        end
      end
      assert_result(Types::Any.constructor(custom).call('Ismael'), custom.new('Ismael'), true)
      with_block = Types::Any.constructor(custom){ |v| custom.new('mr. %s' % v) }
      expect(with_block.call('Ismael').value.name).to eq('mr. Ismael')
      with_symbol = Types::Any.constructor(custom, :build)
      expect(with_symbol.call('Ismael').value.name).to eq('Ismael')
    end

    describe '#rule' do
      specify ':eq' do
        custom = Struct.new(:value) do
          def ==(v)
            value == v
          end
        end

        assert_result(Types::Integer.rule(eq: 1).call(1), 1, true)
        assert_result(Types::Integer.rule(eq: 1).call(2), 2, false)
        assert_result(Types::Integer.rule(eq: custom.new(1)).call(1), 1, true)
        expect(Types::Integer.rule(eq: 1).metadata[:eq]).to eq(1)
      end

      specify ':not_eq' do
        assert_result(Types::Integer.rule(not_eq: 1).call(1), 1, false)
        assert_result(Types::Integer.rule(not_eq: 1).call(2), 2, true)
      end

      specify ':gt, :lt' do
        assert_result(Types::Integer.rule(gt: 10, lt: 20).call(11), 11, true)
        assert_result(Types::Integer.rule(gt: 10, lt: 20).call(9), 9, false)
        assert_result(Types::Integer.rule(gt: 20).call(21), 21, true)
        assert_result(Types::Integer.rule(gt: 10, lt: 20).call(20), 20, false)
        expect(Types::Integer.rule(gt: 10, lt: 20).call(9).error).to eq('must be greater than 10')
      end

      specify ':match' do
        assert_result(Types::String.rule(match: /hello/).call('hello world'), 'hello world', true)
        assert_result(Types::String.rule(match: /hello/).call('bye world'), 'bye world', false)
        assert_result(Types::Integer.rule(match: (1..10)).call(8), 8, true)
        assert_result(Types::Integer.rule(match: (1..10)).call(11), 11, false)
      end

      specify ':included_in' do
        assert_result(Types::String.rule(included_in: %w(a b c)).call('b'), 'b', true)
        assert_result(Types::String.rule(included_in: %w(a b c)).call('d'), 'd', false)
      end

      specify ':excluded_from' do
        assert_result(Types::String.rule(excluded_from: %w(a b c)).call('b'), 'b', false)
        assert_result(Types::String.rule(excluded_from: %w(a b c)).call('d'), 'd', true)
      end

      specify ':respond_to' do
        assert_result(Types::String.rule(respond_to: :strip).call('b'), 'b', true)
        assert_result(Types::String.rule(respond_to: %i[strip chomp]).call('b'), 'b', true)
        assert_result(Types::String.rule(respond_to: %i[strip nope]).call('b'), 'b', false)
        assert_result(Types::String.rule(respond_to: :nope).call('b'), 'b', false)
      end

      specify ':is_a' do
        assert_result(Types::Any.rule(is_a: String).call('b'), 'b', true)
        assert_result(Types::Any.rule(is_a: String).call(1), 1, false)
      end
    end

    class self::TestRegistry < TypeRegistry
      define do
        Foo = 'foo'
        Bar = 'bar'
      end

      class Child < self
        define do
          Bar = 'child::bar'
        end
      end
    end

    describe TypeRegistry do
      specify do
        expect(self.class::TestRegistry::Foo).to eq('foo')
        expect(self.class::TestRegistry::Bar).to eq('bar')
        expect(self.class::TestRegistry[:foo]).to eq('foo')

        expect(self.class::TestRegistry::Child::Foo).to eq('foo')
        expect(self.class::TestRegistry::Child::Bar).to eq('child::bar')
        expect(self.class::TestRegistry::Child[:foo]).to eq('foo')
        expect(self.class::TestRegistry::Child[:bar]).to eq('child::bar')
      end
    end

    describe 'built-in types' do
      specify Types::String do
        assert_result(Types::String.call('aa'), 'aa', true)
        assert_result(Types::String.call(10), 10, false)
      end

      specify Types::Integer do
        assert_result(Types::Integer.call(10), 10, true)
        assert_result(Types::Integer.call('10'), '10', false)
      end

      specify Types::True do
        assert_result(Types::True.call(true), true, true)
        assert_result(Types::True.call(false), false, false)
      end

      specify Types::Boolean do
        assert_result(Types::Boolean.call(true), true, true)
        assert_result(Types::Boolean.call(false), false, true)
        assert_result(Types::Boolean.call('true'), 'true', false)
      end

      specify Types::Lax::String do
        assert_result(Types::Lax::String.call('aa'), 'aa', true)
        assert_result(Types::Lax::String.call(11), '11', true)
        assert_result(Types::Lax::String.call(11.10), '11.1', true)
        assert_result(Types::Lax::String.call(BigDecimal('111.2011')), '111.2011', true)
        assert_result(Types::String.call(true), true, false)
      end

      specify Types::Lax::Integer do
        assert_result(Types::Lax::Integer.call(113), 113, true)
        assert_result(Types::Lax::Integer.call(113.10), 113, true)
        assert_result(Types::Lax::Integer.call('113'), 113, true)
        assert_result(Types::Lax::Integer.call('113.10'), 113, true)
        assert_result(Types::Lax::Integer.call('nope'), 'nope', false)
      end

      specify Types::Forms::Boolean do
        assert_result(Types::Forms::Boolean.call(true), true, true)
        assert_result(Types::Forms::Boolean.call(false), false, true)
        assert_result(Types::Forms::Boolean.call('true'), true, true)

        assert_result(Types::Forms::Boolean.call('false'), false, true)
        assert_result(Types::Forms::Boolean.call('1'), true, true)
        assert_result(Types::Forms::Boolean.call('0'), false, true)
        assert_result(Types::Forms::Boolean.call(1), true, true)
        assert_result(Types::Forms::Boolean.call(0), false, true)

        assert_result(Types::Forms::Boolean.call('nope'), 'nope', false)
      end
    end

    specify Types::Array do
      assert_result(Types::Array.call(1), 1, false)
      assert_result(Types::Array.call([]), [], true)
      assert_result(
        Types::Array.of(Types::Boolean).call([true, true, false]),
        [true, true, false],
        true
      )
      Types::Array.of(Types::Boolean).call([true, 'nope', false, 1]).tap do |result|
        expect(result.success?).to be false
        expect(result.value).to eq [true, 'nope', false, 1]
        expect(result.error[1]).to eq(['must be a TrueClass', 'must be a FalseClass'])
        expect(result.error[3]).to eq(['must be a TrueClass', 'must be a FalseClass'])
      end
      assert_result(
        Types::Array.of(Types::Any.value('a') | Types::Any.value('b')).call(['a', 'b', 'a']),
        %w[a b a],
        true
      )
      assert_result(
        Types::Array.of(Types::Boolean).default([true]).call(Undefined),
        [true],
        true
      )
    end

    specify 'Types::Array.concurrent' do
      slow_type = Types::Any.transform { |r| sleep(0.02); r }
      array = Types::Array.of(slow_type).concurrent
      assert_result(array.call(1), 1, false)
      result, elapsed = bench do
        array.call(%w[a b c])
      end
      assert_result(result, %w[a b c], true)
      expect(elapsed).to be < 30

      assert_result(array.optional.call(nil), nil, true)
    end

    describe Types::Hash do
      specify do
        assert_result(Types::Hash.call({foo: 1}), {foo: 1}, true)
        assert_result(Types::Hash.call(1), 1, false)

        hash = Types::Hash.schema(
          title: Types::String.default('Mr'),
          name: Types::String,
          age: Types::Lax::Integer,
          friend: Types::Hash.schema(name: Types::String)
        )

        assert_result(hash.call({name: 'Ismael', age: '42', friend: { name: 'Joe' }}), {title: 'Mr', name: 'Ismael', age: 42, friend: { name: 'Joe' }}, true)

        hash.call({title: 'Dr', name: 'Ismael', friend: {}}).tap do |result|
          expect(result.success?).to be false
          expect(result.value).to eq({title: 'Dr', name: 'Ismael', friend: { }})
          expect(result.error[:age].any?).to be(true)
          expect(result.error[:friend][:name]).to be_a(::String)
        end
      end

      specify '#|' do
        hash1 = Types::Hash.schema(foo: Types::String)
        hash2 = Types::Hash.schema(bar: Types::Integer)
        union = hash1 | hash2

        assert_result(union.call(foo: 'bar'), { foo: 'bar' }, true)
        assert_result(union.call(bar: 10), { bar: 10 }, true)
        assert_result(union.call(bar: '10'), { bar: '10' }, false)
      end

      specify '#>>' do
        s1 = Types::Hash.schema(name: Types::String)
        s2 = Types::Any.transform { |v| "Name is #{v[:name]}" }

        pipe = s1 >> s2
        assert_result(pipe.call(name: 'Ismael', age: 42), 'Name is Ismael', true)
        assert_result(pipe.call(age: 42), {}, false)
      end

      specify 'optional keys' do
        hash = Types::Hash.schema(
          title: Types::String.default('Mr'),
          name?: Types::String,
          age?: Types::Lax::Integer
        )

        assert_result(hash.call({}), {title: 'Mr'}, true)
      end

      specify '#&' do
        s1 = Types::Hash.schema(name: Types::String)
        s2 = Types::Hash.schema(name?: Types::String, age: Types::Integer)
        s3 = s1 & s2

        assert_result(s3.call(name: 'Ismael', age: 42), {name: 'Ismael', age: 42}, true)
        assert_result(s3.call(age: 42), {age: 42}, true)
      end

      specify '#schema(key_type, value_type)' do
        s1 = Types::Hash.schema(Types::String, Types::Integer)
        expect(s1.metadata).to eq({})
        assert_result(s1.call('a' => 1, 'b' => 2), { 'a' => 1, 'b' => 2 }, true)
        s1.call(a: 1, 'b' => 2).tap do |result|
          assert_result(result, { a: 1, 'b' => 2 }, false)
          expect(result.error).to eq('key :a must be a String')
        end
        s1.call('a' => 1, 'b' => {}).tap do |result|
          assert_result(result, { 'a' => 1, 'b' => {} }, false)
          expect(result.error).to eq('value {} must be a Integer')
        end
      end
    end
  end

  describe Types::Schema do
    specify 'defining a nested schema' do
      schema = Types::Schema.new do |sc|
        sc.field(:title).type(:string).default('Mr')
        sc.field(:name).type(:string)
        sc.field?(:age).type(Types::Lax::Integer)
        sc.field(:friend).type(:hash).schema do |s|
          s.field(:name).type(:string)
        end
      end

      assert_result(schema.call({name: 'Ismael', age: '42', friend: { name: 'Joe' }}), {title: 'Mr', name: 'Ismael', age: 42, friend: { name: 'Joe' }}, true)
    end

    specify 'reusing schemas' do
      friend_schema = Types::Schema.new do |s|
        s.field(:name).type(:string)
      end

      schema = Types::Schema.new do |sc|
        sc.field(:title).type(:string).default('Mr')
        sc.field(:name).type(:string)
        sc.field?(:age).type(:integer)
        sc.field(:friend).type(:hash).schema friend_schema
      end

      assert_result(schema.call({name: 'Ismael', age: 42, friend: { name: 'Joe' }}), {title: 'Mr', name: 'Ismael', age: 42, friend: { name: 'Joe' }}, true)
    end

    specify '#&' do
      s1 = Types::Schema.new do |sc|
        sc.field(:name).type(:string)
      end
      s2 = Types::Schema.new do |sc|
        sc.field?(:name).type(:string)
        sc.field(:age).type(:integer).default(10)
      end
      s3 = s1 & s2
      assert_result(s3.call, { age: 10 }, true)
      assert_result(s3.call(name: 'Joe', foo: 1), { name: 'Joe', age: 10 }, true)

      s4 = s1.merge(s2)
      assert_result(s4.call(name: 'Joe', foo: 1), { name: 'Joe', age: 10 }, true)
    end

    describe 'Field#policy(step)' do
      it 'takes steps as objects or registry symbols' do
        email = Types::Any.rule(match: /\w+@\w+\.\w{3}/)
        field = Types::Schema::Field.new
          .type(:string)
          .policy(email)
          .policy(Types::String.transform{ |v| "<#{v}>"})

        assert_result(field.call('user@email.com'), '<user@email.com>', true)
        assert_result(field.call('nope'), 'nope', false)
        assert_result(field.call(1), 1, false)
      end

      it 'takes rule as :rule_name, matcher' do
        field = Types::Schema::Field.new.type(:string).policy(:format, /^Mr\s/)
        assert_result(field.call('Mr Ismael'), 'Mr Ismael', true)
        assert_result(field.call('Ismael'), 'Ismael', false)
      end

      it 'takes rules as hash' do
        field = Types::Schema::Field.new.type(:integer).policy(gte: 10, lte: 20)
        assert_result(field.call(11), 11, true)
        assert_result(field.call(9), 9, false)
        assert_result(field.call(21), 21, false)
      end
    end

    specify 'Field#meta' do
      field = Types::Schema::Field.new.type(:string).meta(foo: 1).meta(bar: 2)
      expect(field.metadata).to eq(type: ::String, foo: 1, bar: 2)
      expect(field.meta_data).to eq(field.metadata)
    end

    specify 'Field#options' do
      field = Types::Schema::Field.new.type(:string).options(%w(aa bb cc))
      assert_result(field.call('aa'), 'aa', true)
      assert_result(field.call('cc'), 'cc', true)
      assert_result(field.call('dd'), 'dd', false)
      expect(field.metadata[:options]).to eq(%w(aa bb cc))
    end

    specify 'Field#declared' do
      field = Types::Schema::Field.new.type(:string).declared.policy(Types::Any.transform { |v| 'Hello %s' % v })
      assert_result(field.call('Ismael'), 'Hello Ismael', true)
      assert_result(field.call(Undefined), Undefined, false)

      with_default = Types::Schema::Field.new.type(:string).declared.default('no')
      assert_result(with_default.call('Ismael'), 'Ismael', true)
      assert_result(with_default.call(Undefined), 'no', true)
    end

    specify 'Field#optional' do
      field = Types::Schema::Field.new.type(:string).optional.policy(Types::Any.transform { |v| 'Hello %s' % v })
      assert_result(field.call('Ismael'), 'Hello Ismael', true)
      assert_result(field.call(nil), nil, false)
    end

    specify 'Field#present' do
      field = Types::Schema::Field.new.present
      assert_result(field.call('Ismael'), 'Ismael', true)
      assert_result(field.call(nil), nil, false)
      expect(field.call(nil).error).to eq('must be present')
    end

    specify 'Field#required' do
      field = Types::Schema::Field.new.required
      assert_result(field.call, Undefined, false)
      assert_result(field.call(nil), nil, true)
      expect(field.call.error).to eq('is required')
    end

    specify 'Field#policy(:split)' do
      field = Types::Schema::Field.new.policy(:split)
      assert_result(field.call('a ,b  ,c'), %w(a b c), true)
      assert_result(field.call('aa'), %w(aa), true)
    end

    context 'with array schemas' do
      specify 'inline array schemas' do
        schema = Types::Schema.new do |sc|
          sc.field(:friends).type(:array).schema do |f|
            f.field(:name).type(:string)
          end
        end

        input = {friends: [{name: 'Joe'}, {name: 'Joan'}]}

        assert_result(schema.call(input), input, true)
      end

      specify 'reusable array schemas' do
        friend_schema = Types::Schema.new do |s|
          s.field(:name).type(:string)
        end

        schema = Types::Schema.new do |sc|
          sc.field(:friends).type(:array).schema friend_schema
        end

        input = {friends: [{name: 'Joe'}, {name: 'Joan'}]}

        assert_result(schema.call(input), input, true)
        schema.call({friends: [{name: 'Joan'}, {}]}).tap do |result|
          expect(result.success?).to be false
          expect(result.error[:friends][1][:name]).not_to be_nil
        end
      end

      specify 'array.of' do
        schema = Types::Schema.new do |sc|
          sc.field(:numbers).type(:array).of(Types::Integer | Types::String.transform(&:to_i))
        end

        assert_result(schema.call(numbers: [1, 2, '3']), {numbers: [1, 2, 3]}, true)
      end
    end
  end

  private

  def assert_result(result, value, is_success, debug: false)
    byebug if debug
    expect(result.value).to eq value
    expect(result.success?).to be is_success
  end

  def bench(&block)
    start = Time.now
    result = yield
    elapsed = (Time.now - start).to_f * 1000
    [result, elapsed]
  end
end
