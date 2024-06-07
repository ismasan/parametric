# frozen_string_literal: true

require 'spec_helper'
require 'parametric/v2'

include Parametric::V2

RSpec.describe Parametric::V2::Types do
  describe 'Result' do
    specify '#success and #halt' do
      result = Result.wrap(10)
      expect(result.success?).to be(true)
      expect(result.value).to eq(10)
      result = result.success(20)
      expect(result.value).to eq(20)
      result = result.halt(error: 'nope')
      expect(result.success?).to be(false)
      expect(result.halt?).to be(true)
      expect(result.error).to eq('nope')
    end
  end

  describe 'Step' do
    specify '#>>' do
      step1 = Step.new { |r| r.success(r.value + 5) }
      step2 = Step.new { |r| r.success(r.value - 2) }
      step3 = Step.new { |r| r.halt }
      step4 = ->(minus) { Step.new { |r| r.success(r.value - minus) } }
      pipeline = Types::Any >> step1 >> step2 >> step3 >> ->(r) { r.success(r.value + 1) }

      expect(pipeline.resolve(10).success?).to be(false)
      expect(pipeline.resolve(10).value).to eq(13)
      expect((step1 >> step2 >> step4.call(1)).resolve(10).value).to eq(12)
      expect((step1 >> ->(r) { r.success(r.value.to_s) }).resolve(10).value).to eq('15')
    end

    specify '#transform' do
      to_i = Types::Any.transform(::Integer, &:to_i)
      plus_ten = Types::Any.transform(::Integer) { |value| value + 10 }
      pipeline = to_i >> plus_ten
      expect(pipeline.resolve('5').value).to eq(15)
    end

    specify Types::Static do
      assert_result(Types::Static['hello'].resolve('hello'), 'hello', true)
      assert_result(Types::Static['hello'].resolve('nope'), 'hello', true)
      expect(Types::Static['hello'].ast).to eq([:static, { default: 'hello', const: 'hello', type: String }, []])
    end

    specify '#ast' do
      type = (
        (Types::String.transform(::Integer, &:to_i) | Types::Integer) \
        >> Types::Integer.transform(::Integer) { |v| v + 5 }
      )

      expect(type.ast).to eq(
        [:and,
         {},
         [[:or,
           {},
           [[:and, {}, [[:rules, {}, [[:is_a, { type: String }, []]]], [:transform, { type: Integer }, []]]],
            [:rules, {}, [[:is_a, { type: Integer }, []]]]]],
          [:and, {}, [[:rules, {}, [[:is_a, { type: Integer }, []]]], [:transform, { type: Integer }, []]]]]]
      )
    end

    specify '#with_ast' do
      type = Types::Any.transform(::Integer, &:to_i).with_ast([:foo, { type: 'bar' }, []])
      expect(type.ast).to eq([:foo, { type: 'bar' }, []])

      expect do
        Types::Any.with_ast([:foo, { type: 'bar' }])
      end.to raise_error(ArgumentError)
    end

    specify '#match' do
      type = Types::Any.match(/^(\([0-9]{3}\))?[0-9]{3}-[0-9]{4}$/)
      expect(type.resolve('(888)555-1212x').success?).to be(false)
      expect(type.resolve('(888)555-1212').success?).to be(true)
    end

    specify '#check' do
      is_a_string = Types::Any.check('not a string') { |value| value.is_a?(::String) }
      expect(is_a_string.resolve('yup').success?).to be(true)
      expect(is_a_string.resolve(10).success?).to be(false)
      expect(is_a_string.resolve(10).error).to eq('not a string')
    end

    specify '#present' do
      assert_result(Types::Any.present.resolve, Undefined, false)
      assert_result(Types::Any.present.resolve(''), '', false)
      assert_result(Types::Any.present.resolve('foo'), 'foo', true)
      assert_result(Types::Any.present.resolve([]), [], false)
      assert_result(Types::Any.present.resolve([1, 2]), [1, 2], true)
      assert_result(Types::Any.present.resolve(nil), nil, false)
    end

    specify '#[](value)' do
      type = Types::String['hello']
      assert_result(type.resolve('hello'), 'hello', true)
      assert_result(type.resolve('nope'), 'nope', false)

      type = Types::Lax::String['10']
      assert_result(type.resolve(10), '10', true)
    end

    specify '#is_a' do
      pipeline = Types::Any.is_a(::Integer).transform(::Integer) { |v| v + 5 }
      assert_result(pipeline.resolve(10), 15, true)
      assert_result(pipeline.resolve('nope'), 'nope', false)
    end

    specify '#cast' do
      integer = Types::Any.is_a(::Integer)
      expect { integer.cast('10') }.to raise_error(Parametric::V2::TypeError)
      expect(integer.cast(10)).to eq(10)
    end

    specify '#|' do
      integer = Types::Any.is_a(::Integer)
      string = Types::Any.is_a(::String)
      to_s = Types::Any.transform(::Integer, &:to_s)
      title = Types::Any.transform(::Integer) { |v| "The number is #{v}" }

      pipeline = string | (integer >> to_s >> title)

      assert_result(pipeline.resolve('10'), '10', true)
      assert_result(pipeline.resolve(10), 'The number is 10', true)

      pipeline = Types::String | Types::Integer
      failed = pipeline.resolve(10.3)
      expect(failed.error).to eq(['must be a String', 'must be a Integer'])
    end

    specify '#meta' do
      to_s = Types::Any.transform(::String, &:to_s).meta(type: :string)
      to_i = Types::Any.transform(::Integer, &:to_i).meta(type: :integer).meta(foo: 'bar')
      pipe = to_s >> to_i
      expect(to_s.metadata[:type]).to eq(:string)
      expect(pipe.metadata[:type]).to eq(:integer)
      expect(pipe.metadata[:foo]).to eq('bar')
    end

    describe '#metadata' do
      specify 'AND (>>) chains' do
        type = Types::String >> Types::Integer.meta(foo: 'bar')
        expect(type.metadata).to eq({ type: ::Integer, foo: 'bar' })
      end

      specify 'OR (|) chains' do
        type = Types::String | Types::Integer.meta(foo: 'bar')
        expect(type.metadata).to eq({ type: [::String, ::Integer], foo: 'bar' })
      end

      specify 'AND (>>) with OR (|)' do
        type = Types::String >> (Types::Integer | Types::Boolean).meta(foo: 'bar')
        expect(type.metadata).to eq({ type: [::Integer, 'boolean'], foo: 'bar' })

        type = Types::String | (Types::Integer >> Types::Boolean).meta(foo: 'bar')
        expect(type.metadata).to eq({ type: [::String, 'boolean'], foo: 'bar' })
      end
    end

    specify '#not' do
      string = Types::Any.check('not a string') { |v| v.is_a?(::String) }
      assert_result(Types::Any.not(string).resolve(10), 10, true)
      assert_result(Types::Any.not(string).resolve('hello'), 'hello', false)

      assert_result(string.not.resolve(10), 10, true)
    end

    specify '#halt' do
      type = Types::Integer.rule(lte: 10).halt(error: 'nope')
      assert_result(type.resolve(9), 9, false)
      assert_result(type.resolve(19), 19, true)
      expect(type.resolve(9).error).to eq('nope')
    end

    specify '#default' do
      assert_result(Types::Any.default('hello').resolve('bye'), 'bye', true)
      assert_result(Types::Any.default('hello').resolve(nil), nil, true)
      assert_result(Types::Any.default('hello').resolve(Undefined), 'hello', true)
      assert_result(Types::String.default('hello').resolve(Undefined), 'hello', true)
    end

    specify '#optional' do
      assert_result(Types::String.optional.resolve('bye'), 'bye', true)
      assert_result(Types::String.resolve(nil), nil, false)
      assert_result(Types::String.optional.resolve(nil), nil, true)
    end

    specify '#coerce' do
      assert_result(Types::Any.coerce(::Numeric, &:to_i).resolve(10.5), 10, true)
      assert_result(Types::Any.coerce(::Numeric, &:to_i).resolve('10.5'), '10.5', false)
      assert_result(Types::Any.coerce((0..3), &:to_s).resolve(2), '2', true)
      assert_result(Types::Any.coerce((0..3), &:to_s).resolve(4), 4, false)
      assert_result(Types::Any.coerce(/true/i) { |_| true }.resolve('True'), true, true)
      assert_result(Types::Any.coerce(/true/i) { |_| true }.resolve('TRUE'), true, true)
      assert_result(Types::Any.coerce(/true/i) { |_| true }.resolve('nope'), 'nope', false)
      assert_result(Types::Any.coerce(1) { |_| true }.resolve(1), true, true)
    end

    describe '#pipeline' do
      let(:pipeline) do
        Types::Lax::Integer.pipeline do |pl|
          pl.step { |r| r.success(r.value * 2) }
          pl.step Types::Any.transform(::Integer, &:to_s)
          pl.step { |r| r.success('The number is %s' % r.value) }
        end
      end

      specify '#metadata' do
        pipe = pipeline.meta(foo: 'bar')
        expect(pipe.metadata).to eq({ type: Integer, foo: 'bar' })
      end

      it 'builds a step composed of many steps' do
        assert_result(pipeline.resolve(2), 'The number is 4', true)
        assert_result(pipeline.resolve('2'), 'The number is 4', true)
        assert_result(pipeline.transform(::String) { |v| v + '!!' }.resolve(2), 'The number is 4!!', true)
        assert_result(pipeline.resolve('nope'), 'nope', false)
      end

      it 'is a Steppable and can be further composed' do
        expect(pipeline).to be_a(Parametric::V2::Steppable)
        pipeline2 = pipeline.pipeline do |pl|
          pl.step { |r| r.success(r.value + ' the end') }
        end

        assert_result(pipeline2.resolve(2), 'The number is 4 the end', true)
      end

      it 'is chainable' do
        type = Types::Any.transform(::Integer) { |v| v + 5 } >> pipeline
        assert_result(type.resolve(2), 'The number is 14', true)
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
            result = step.resolve(result)
            list << 'after: %s' % result.value
            result
          end
          pl.step(Types::Any.transform(::String) { |v| "-#{v}-" })
          pl.around do |step, result|
            counts += 1
            step.resolve(result)
          end
          pl.step(Types::Any.transform(::String) { |v| "*#{v}*" })
        end

        assert_result(pipeline.resolve(1), '*-1-*', true)
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
      assert_result(Types::Any.constructor(custom).resolve('Ismael'), custom.new('Ismael'), true)
      with_block = Types::Any.constructor(custom) { |v| custom.new('mr. %s' % v) }
      expect(with_block.resolve('Ismael').value.name).to eq('mr. Ismael')
      with_symbol = Types::Any.constructor(custom, :build)
      expect(with_symbol.resolve('Ismael').value.name).to eq('Ismael')
    end

    describe '#rule' do
      specify 'rules not supported by current underlying type' do
        custom_class = Class.new
        custom = Types::Any.meta(type: custom_class)
        expect do
          custom.rule(size: 10)
        end.to raise_error(Parametric::V2::Rules::UnsupportedRuleError)
      end

      specify ':eq' do
        custom = Struct.new(:value) do
          def ==(other)
            value == other
          end
        end

        assert_result(Types::Integer.rule(eq: 1).resolve(1), 1, true)
        assert_result(Types::Integer.rule(eq: 1).resolve(2), 2, false)
        assert_result(Types::Integer.rule(eq: custom.new(1)).resolve(1), 1, true)
        expect(Types::Integer.rule(eq: 1).metadata[:eq]).to eq(1)
      end

      specify ':not_eq' do
        assert_result(Types::Integer.rule(not_eq: 1).resolve(1), 1, false)
        assert_result(Types::Integer.rule(not_eq: 1).resolve(2), 2, true)
      end

      specify ':gt, :lt' do
        assert_result(Types::Integer.rule(gt: 10, lt: 20).resolve(11), 11, true)
        assert_result(Types::Integer.rule(gt: 10, lt: 20).resolve(9), 9, false)
        assert_result(Types::Integer.rule(gt: 20).resolve(21), 21, true)
        assert_result(Types::Integer.rule(gt: 10, lt: 20).resolve(20), 20, false)
        expect(Types::Integer.rule(gt: 10, lt: 20).resolve(9).error).to eq('must be greater than 10')
      end

      specify ':gt, :lt with array' do
        assert_result(Types::Array.rule(gt: 1, lt: 3).resolve([1, 2]), [1, 2], true)
        assert_result(Types::Array.rule(gt: 1, lt: 3).resolve([1, 2, 3]), [1, 2, 3], false)
      end

      specify ':match' do
        assert_result(Types::String.rule(match: /hello/).resolve('hello world'), 'hello world', true)
        assert_result(Types::String.rule(match: /hello/).resolve('bye world'), 'bye world', false)
        assert_result(Types::Integer.rule(match: (1..10)).resolve(8), 8, true)
        assert_result(Types::Integer.rule(match: (1..10)).resolve(11), 11, false)
      end

      specify ':included_in' do
        assert_result(Types::String.rule(included_in: %w[a b c]).resolve('b'), 'b', true)
        assert_result(Types::String.rule(included_in: %w[a b c]).resolve('d'), 'd', false)
      end

      specify ':excluded_from' do
        assert_result(Types::String.rule(excluded_from: %w[a b c]).resolve('b'), 'b', false)
        assert_result(Types::String.rule(excluded_from: %w[a b c]).resolve('d'), 'd', true)
      end

      specify ':respond_to' do
        assert_result(Types::String.rule(respond_to: :strip).resolve('b'), 'b', true)
        assert_result(Types::String.rule(respond_to: %i[strip chomp]).resolve('b'), 'b', true)
        assert_result(Types::String.rule(respond_to: %i[strip nope]).resolve('b'), 'b', false)
        assert_result(Types::String.rule(respond_to: :nope).resolve('b'), 'b', false)
      end

      specify ':is_a' do
        assert_result(Types::Any.rule(is_a: String).resolve('b'), 'b', true)
        assert_result(Types::Any.rule(is_a: String).resolve(1), 1, false)
      end
    end

    describe 'built-in types' do
      specify Types::String do
        assert_result(Types::String.resolve('aa'), 'aa', true)
        assert_result(Types::String.resolve(10), 10, false)
      end

      specify Types::Integer do
        assert_result(Types::Integer.resolve(10), 10, true)
        assert_result(Types::Integer.resolve('10'), '10', false)
      end

      specify Types::True do
        assert_result(Types::True.resolve(true), true, true)
        assert_result(Types::True.resolve(false), false, false)
      end

      specify Types::Boolean do
        assert_result(Types::Boolean.resolve(true), true, true)
        assert_result(Types::Boolean.resolve(false), false, true)
        assert_result(Types::Boolean.resolve('true'), 'true', false)
      end

      specify Types::Value do
        assert_result(Types::Value['hello'].resolve('hello'), 'hello', true)
        assert_result(Types::Value['hello'].resolve('nope'), 'nope', false)
        assert_result(Types::Lax::String.value('10').resolve(10), '10', true)
        assert_result(Types::Lax::String.value('11').resolve(10), '10', false)
      end

      specify Types::Interface do
        obj = Data.define(:name, :age) do
          def test(foo, bar = 1, opt: 2)
            [foo, bar, opt]
          end
        end.new(name: 'Ismael', age: 42)

        assert_result(Types::Interface[:name, :age].resolve(obj), obj, true)
        assert_result(Types::Interface[:name, :age, :test].resolve(obj), obj, true)
        assert_result(Types::Interface[:name, :nope, :test].resolve(obj), obj, false)

        expect(Types::Interface[:name, :age].ast).to eq(
          [:interface, { method_names: %i[name age] }, []]
        )
      end

      specify Types::Lax::String do
        assert_result(Types::Lax::String.resolve('aa'), 'aa', true)
        assert_result(Types::Lax::String.resolve(11), '11', true)
        assert_result(Types::Lax::String.resolve(11.10), '11.1', true)
        assert_result(Types::Lax::String.resolve(BigDecimal('111.2011')), '111.2011', true)
        assert_result(Types::String.resolve(true), true, false)
      end

      specify Types::Lax::Integer do
        assert_result(Types::Lax::Integer.resolve(113), 113, true)
        assert_result(Types::Lax::Integer.resolve(113.10), 113, true)
        assert_result(Types::Lax::Integer.resolve('113'), 113, true)
        assert_result(Types::Lax::Integer.resolve('113.10'), 113, true)
        assert_result(Types::Lax::Integer.resolve('nope'), 'nope', false)
      end

      specify Types::Forms::Boolean do
        assert_result(Types::Forms::Boolean.resolve(true), true, true)
        assert_result(Types::Forms::Boolean.resolve(false), false, true)
        assert_result(Types::Forms::Boolean.resolve('true'), true, true)

        assert_result(Types::Forms::Boolean.resolve('false'), false, true)
        assert_result(Types::Forms::Boolean.resolve('1'), true, true)
        assert_result(Types::Forms::Boolean.resolve('0'), false, true)
        assert_result(Types::Forms::Boolean.resolve(1), true, true)
        assert_result(Types::Forms::Boolean.resolve(0), false, true)

        assert_result(Types::Forms::Boolean.resolve('nope'), 'nope', false)
      end
    end

    describe Types::Tuple do
      specify 'no member types defined' do
        assert_result(Types::Tuple.resolve(1), 1, false)
      end

      specify '#[]' do
        type = Types::Tuple[
          Types::Any.value('ok') | Types::Any.value('error'),
          Types::Boolean,
          Types::String
        ]

        assert_result(
          type.resolve(['ok', true, 'Hi!']),
          ['ok', true, 'Hi!'],
          true
        )

        assert_result(
          type.resolve(['ok', 'nope', 'Hi!']),
          ['ok', 'nope', 'Hi!'],
          false
        )

        assert_result(
          type.resolve(['ok', true, 'Hi!', 'nope']),
          ['ok', true, 'Hi!', 'nope'],
          false
        )
      end

      specify 'with static values' do
        type = Types::Tuple[2, Types::String]
        assert_result(
          type.resolve([2, 'yup']),
          [2, 'yup'],
          true
        )
        assert_result(
          type.resolve(%w[nope yup]),
          %w[nope yup],
          false
        )
      end
    end

    describe Types::Array do
      specify 'no member types defined' do
        assert_result(Types::Array.resolve(1), 1, false)
        assert_result(Types::Array.resolve([]), [], true)
      end

      specify '#of' do
        assert_result(
          Types::Array[Types::Boolean].resolve([true, true, false]),
          [true, true, false],
          true
        )
        assert_result(
          Types::Array.of(Types::Boolean).resolve([]),
          [],
          true
        )
        Types::Array.of(Types::Boolean).resolve([true, 'nope', false, 1]).tap do |result|
          expect(result.success?).to be false
          expect(result.value).to eq [true, 'nope', false, 1]
          expect(result.error[1]).to eq(['must be a TrueClass', 'must be a FalseClass'])
          expect(result.error[3]).to eq(['must be a TrueClass', 'must be a FalseClass'])
        end
      end

      specify '#of with unions' do
        assert_result(
          Types::Array.of(Types::Any.value('a') | Types::Any.value('b')).resolve(%w[a b a]),
          %w[a b a],
          true
        )
        assert_result(
          Types::Array.of(Types::Boolean).default([true]).resolve(Undefined),
          [true],
          true
        )
      end

      specify '#[] (#of) Hash argument wraps subtype in Types::Hash' do
        type = Types::Array[foo: Types::String]
        assert_result(type.resolve([{ foo: 'bar' }]), [{ foo: 'bar' }], true)
      end

      specify '#[] (#of) with non-steppable argument' do
        expect do
          Types::Array['bar']
        end.to raise_error(ArgumentError)
      end

      specify '#present (non-empty)' do
        non_empty_array = Types::Array.of(Types::Boolean).present
        assert_result(
          non_empty_array.resolve([true, true, false]),
          [true, true, false],
          true
        )
        assert_result(
          non_empty_array.resolve([]),
          [],
          false
        )
      end

      specify '#metadata' do
        type = Types::Array[Types::Boolean].meta(foo: 1)
        expect(type.metadata).to eq(type: Array, foo: 1)
      end

      specify '#concurrent' do
        slow_type = Types::Any.transform(NilClass) do |r|
          sleep(0.02)
          r
        end
        array = Types::Array.of(slow_type).concurrent
        assert_result(array.resolve(1), 1, false)
        result, elapsed = bench do
          array.resolve(%w[a b c])
        end
        assert_result(result, %w[a b c], true)
        expect(elapsed).to be < 30

        assert_result(array.optional.resolve(nil), nil, true)
      end
    end

    describe Types::Hash do
      specify 'no schema' do
        assert_result(Types::Hash.resolve({ foo: 1 }), { foo: 1 }, true)
        assert_result(Types::Hash.resolve(1), 1, false)
      end

      specify '#schema' do
        hash = Types::Hash.schema(
          title: Types::String.default('Mr'),
          name: Types::String,
          age: Types::Lax::Integer,
          friend: Types::Hash.schema(name: Types::String)
        )

        assert_result(hash.resolve({ name: 'Ismael', age: '42', friend: { name: 'Joe' } }),
                      { title: 'Mr', name: 'Ismael', age: 42, friend: { name: 'Joe' } }, true)

        hash.resolve({ title: 'Dr', name: 'Ismael', friend: {} }).tap do |result|
          expect(result.success?).to be false
          expect(result.value).to eq({ title: 'Dr', name: 'Ismael', friend: {} })
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

        assert_result(hash.resolve({ friend: { name: 'Joe' } }),
                      { title: 'Mr', name: 'Ismael', age: 45, friend: { name: 'Joe' } }, true)
      end

      specify '#|' do
        hash1 = Types::Hash.schema(foo: Types::String)
        hash2 = Types::Hash.schema(bar: Types::Integer)
        union = hash1 | hash2

        assert_result(union.resolve(foo: 'bar'), { foo: 'bar' }, true)
        assert_result(union.resolve(bar: 10), { bar: 10 }, true)
        assert_result(union.resolve(bar: '10'), { bar: '10' }, false)
      end

      specify '#+' do
        s1 = Types::Hash.schema(name: Types::String)
        s2 = Types::Hash.schema(name?: Types::String, age: Types::Integer)
        s3 = s1 + s2

        assert_result(s3.resolve(name: 'Ismael', age: 42), { name: 'Ismael', age: 42 }, true)
        assert_result(s3.resolve(age: 42), { age: 42 }, true)
      end

      specify '#defer' do
        linked_list = Types::Hash[
          value: Types::Any,
          next: Types::Any.defer { linked_list } | Types::Nil
        ]
        assert_result(
          linked_list.resolve(value: 1, next: { value: 2, next: { value: 3, next: nil } }),
          { value: 1, next: { value: 2, next: { value: 3, next: nil } } },
          true
        )
        expect(linked_list.metadata).to eq(type: Hash)
      end

      specify '#defer with Tuple' do
        type = Types::Tuple[
          Types::String,
          Types::Hash,
          Types::Array[Types::Any.defer { type }]
        ]
        assert_result(
          type.resolve(['hello', { foo: 'bar' }, [['ok', {}, []]]]),
          ['hello', { foo: 'bar' }, [['ok', {}, []]]],
          true
        )
        assert_result(
          type.resolve(['hello', { foo: 'bar' }, [['ok', {}, 1]]]),
          ['hello', { foo: 'bar' }, [['ok', {}, 1]]],
          false
        )
      end

      specify '#defer with Array' do
        type = Types::Array[Types::Any.defer { Types::String }]
        assert_result(
          type.resolve(['hello']),
          ['hello'],
          true
        )
        expect(type.metadata).to eq(type: Array)
        # TODO: Deferred #ast cannot delegate to the deferred type
        # to avoid infinite recursion. Deferred should only be used
        # for recursive types such as Linked Lists, Trees, etc.
        # expect(type.ast).to eq([:array, {}, [:string, {}]])
      end

      specify '#&' do
        s1 = Types::Hash.schema(name: Types::String, age: Types::Integer, company: Types::String)
        s2 = Types::Hash.schema(name?: Types::String, age: Types::Integer, email: Types::String)
        s3 = s1 & s2

        assert_result(s3.resolve(name: 'Ismael', age: 42, company: 'ACME', email: 'me@acme.com'),
                      { name: 'Ismael', age: 42 }, true)
        assert_result(s3.resolve(age: 42), { age: 42 }, true)
      end

      specify '#metadata' do
        s1 = Types::Hash.schema(name: Types::String, age: Types::Integer, company: Types::String)
        expect(s1.metadata).to eq(type: Hash)
      end

      specify '#tagged_by' do
        t1 = Types::Hash[kind: 't1', name: Types::String]
        t2 = Types::Hash[kind: 't2', name: Types::String]
        type = Types::Hash.tagged_by(:kind, t1, t2)

        assert_result(type.resolve(kind: 't1', name: 'T1'), { kind: 't1', name: 'T1' }, true)
        assert_result(type.resolve(kind: 't2', name: 'T2'), { kind: 't2', name: 'T2' }, true)
        assert_result(type.resolve(kind: 't3', name: 'T2'), { kind: 't3', name: 'T2' }, false)
      end

      specify '#>>' do
        s1 = Types::Hash.schema(name: Types::String)
        s2 = Types::Any.transform(::String) { |v| "Name is #{v[:name]}" }

        pipe = s1 >> s2
        assert_result(pipe.resolve(name: 'Ismael', age: 42), 'Name is Ismael', true)
        assert_result(pipe.resolve(age: 42), {}, false)
      end

      specify '#present' do
        assert_result(Types::Hash.resolve({}), {}, true)
        assert_result(Types::Hash.present.resolve({}), {}, false)
      end

      specify 'optional keys' do
        hash = Types::Hash.schema(
          title: Types::String.default('Mr'),
          name?: Types::String,
          age?: Types::Lax::Integer
        )

        assert_result(hash.resolve({}), { title: 'Mr' }, true)
      end

      specify '#schema(key_type, value_type) "Map"' do
        s1 = Types::Hash.schema(Types::String, Types::Integer)
        expect(s1.metadata).to eq(type: Hash)
        assert_result(s1.resolve('a' => 1, 'b' => 2), { 'a' => 1, 'b' => 2 }, true)
        s1.resolve(a: 1, 'b' => 2).tap do |result|
          assert_result(result, { a: 1, 'b' => 2 }, false)
          expect(result.error).to eq('key :a must be a String')
        end
        s1.resolve('a' => 1, 'b' => {}).tap do |result|
          assert_result(result, { 'a' => 1, 'b' => {} }, false)
          expect(result.error).to eq('value {} must be a Integer')
        end
        assert_result(s1.present.resolve({}), {}, false)
      end

      specify '#[] alias to #schema' do
        s1 = Types::Hash[Types::String, Types::Integer]
        expect(s1.metadata).to eq(type: Hash)
        assert_result(s1.resolve('a' => 1, 'b' => 2), { 'a' => 1, 'b' => 2 }, true)
      end
    end
  end

  private

  def assert_result(result, value, is_success, debug: false)
    debugger if debug
    expect(result.value).to eq value
    expect(result.success?).to be(is_success)
  end

  def bench
    start = Time.now
    result = yield
    elapsed = (Time.now - start).to_f * 1000
    [result, elapsed]
  end
end
