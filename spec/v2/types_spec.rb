# frozen_string_literal: true

require 'spec_helper'
require 'parametric/v2/types'

include Parametric::V2

RSpec.describe Parametric::V2::Types do
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

    specify '#cast' do
      integer = Types::Any.is_a(::Integer)
      expect { integer.cast('10') }.to raise_error(Parametric::V2::TypeError)
      expect(integer.cast(10)).to eq(10)
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
      assert_result(Types.value('hello').call('hello'), 'hello', true)
      assert_result(Types.value('hello').call('nope'), 'nope', false)
      assert_result(Types::Lax::String.value('10').call(10), '10', true)
      assert_result(Types::Lax::String.value('11').call(10), '10', false)
    end

    specify '.static' do
      assert_result(Types.static('hello').call('hello'), 'hello', true)
      assert_result(Types.static('hello').call('nope'), 'hello', true)
      assert_result(Types.static { |_| 'hello' }.call('nope'), 'hello', true)
    end

    specify '#default' do
      assert_result(Types::Any.default('hello').call('bye'), 'bye', true)
      assert_result(Types::Any.default('hello').call(nil), nil, true)
      assert_result(Types::Any.default('hello').call(Undefined), 'hello', true)
      assert_result(Types::String.default('hello').call(Undefined), 'hello', true)
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
        Types::Lax::Integer.pipeline do |pl|
          pl.step { |r| r.success(r.value * 2) }
          pl.step Types::Any.transform(&:to_s)
          pl.step { |r| r.success('The number is %s' % r.value) }
        end
      end

      it 'builds a step composed of many steps' do
        assert_result(pipeline.call(2), 'The number is 4', true)
        assert_result(pipeline.call('2'), 'The number is 4', true)
        assert_result(pipeline.transform{ |v| v + '!!' }.call(2), 'The number is 4!!', true)
        assert_result(pipeline.call('nope'), 'nope', false)
      end

      it 'is a Steppable and can be further composed' do
        expect(pipeline).to be_a(Parametric::V2::Steppable)
        pipeline2 = pipeline.pipeline do |pl|
          pl.step { |r| r.success(r.value + ' the end') }
        end

        assert_result(pipeline2.call(2), 'The number is 4 the end', true)
      end

      it 'is chainable' do
        type = Types::Any.transform { |v| v + 5 } >> pipeline
        assert_result(type.call(2), 'The number is 14', true)
      end
    end

    describe Parametric::V2::Pipeline do
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

    describe Types::Tuple do
      specify 'no member types defined' do
        assert_result(Types::Tuple.call(1), 1, false)
      end

      specify '#of' do
        type = Types::Tuple.of(
          Types.value('ok') | Types.value('error'),
          Types::Boolean,
          Types::String
        )

        assert_result(
          type.call(['ok', true, 'Hi!']),
          ['ok', true, 'Hi!'],
          true
        )

        assert_result(
          type.call(['ok', 'nope', 'Hi!']),
          ['ok', 'nope', 'Hi!'],
          false
        )

        assert_result(
          type.call(['ok', true, 'Hi!', 'nope']),
          ['ok', true, 'Hi!', 'nope'],
          false
        )

      end

      specify 'with primitives' do
        type = Types::Tuple.of(2, Types::String)
        assert_result(
          type.call([2, 'yup']),
          [2, 'yup'],
          true
        )
        assert_result(
          type.call(['nope', 'yup']),
          ['nope', 'yup'],
          false
        )
      end
    end

    describe Types::Array do
      specify 'no member types defined' do
        assert_result(Types::Array.call(1), 1, false)
        assert_result(Types::Array.call([]), [], true)
      end

      specify '#of' do
        assert_result(
          Types::Array.of(Types::Boolean).call([true, true, false]),
          [true, true, false],
          true
        )
        assert_result(
          Types::Array.of(Types::Boolean).call([]),
          [],
          true
        )
        Types::Array.of(Types::Boolean).call([true, 'nope', false, 1]).tap do |result|
          expect(result.success?).to be false
          expect(result.value).to eq [true, 'nope', false, 1]
          expect(result.error[1]).to eq(['must be a TrueClass', 'must be a FalseClass'])
          expect(result.error[3]).to eq(['must be a TrueClass', 'must be a FalseClass'])
        end
      end

      specify '#of with unions' do
        assert_result(
          Types::Array.of(Types.value('a') | Types.value('b')).call(['a', 'b', 'a']),
          %w[a b a],
          true
        )
        assert_result(
          Types::Array.of(Types::Boolean).default([true]).call(Undefined),
          [true],
          true
        )
      end

      specify '#present (non-empty)' do
        non_empty_array = Types::Array.of(Types::Boolean).present
        assert_result(
          non_empty_array.call([true, true, false]),
          [true, true, false],
          true
        )
        assert_result(
          non_empty_array.call([]),
          [],
          false
        )
      end

      specify '#concurrent' do
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
    end

    describe Types::Hash do
      specify 'no schema' do
        assert_result(Types::Hash.call({foo: 1}), {foo: 1}, true)
        assert_result(Types::Hash.call(1), 1, false)
      end

      specify '#schema' do
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

      specify '#schema with static values' do
        hash = Types::Hash.schema(
          title: Types::String.default('Mr'),
          name: 'Ismael',
          age: 45,
          friend: Types::Hash.schema(name: Types::String)
        )

        assert_result(hash.call({ friend: { name: 'Joe' } }), { title: 'Mr', name: 'Ismael', age: 45, friend: { name: 'Joe' } }, true)
      end

      specify '#[](key)' do
        title = Types::String.default('Mr')
        hash = Types::Hash.schema(
          title: title,
          name: Types::String,
        )
        expect(hash[:title]).to eq(title)
      end

      specify '#|' do
        hash1 = Types::Hash.schema(foo: Types::String)
        hash2 = Types::Hash.schema(bar: Types::Integer)
        union = hash1 | hash2

        assert_result(union.call(foo: 'bar'), { foo: 'bar' }, true)
        assert_result(union.call(bar: 10), { bar: 10 }, true)
        assert_result(union.call(bar: '10'), { bar: '10' }, false)
      end

      specify '#discriminated' do
        t1 = Types::Hash.schema(kind: 't1', name: Types::String)
        t2 = Types::Hash.schema(kind: 't2', name: Types::String)
        type = Types::Hash.discriminated(:kind, t1, t2)

        assert_result(type.call(kind: 't1', name: 'T1'), { kind: 't1', name: 'T1' }, true)
        assert_result(type.call(kind: 't2', name: 'T2'), { kind: 't2', name: 'T2' }, true)
        assert_result(type.call(kind: 't3', name: 'T2'), { kind: 't3', name: 'T2' }, false)
      end

      specify '#>>' do
        s1 = Types::Hash.schema(name: Types::String)
        s2 = Types::Any.transform { |v| "Name is #{v[:name]}" }

        pipe = s1 >> s2
        assert_result(pipe.call(name: 'Ismael', age: 42), 'Name is Ismael', true)
        assert_result(pipe.call(age: 42), {}, false)
      end

      specify '#present' do
        assert_result(Types::Hash.call({}), {}, true)
        assert_result(Types::Hash.present.call({}), {}, false)
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

      specify '#schema(key_type, value_type) "Map"' do
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
        assert_result(s1.present.call({}), {}, false)
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
