# frozen_string_literal: true

require 'spec_helper'
require 'parametric/pipes'

include Parametric

RSpec.describe Pipes do
  describe 'Pipes::Result' do
    specify 'piping results with #map' do
      init = Pipes::Result.wrap(10)
      add_tax = ->(r) { r.success(r.value + 5) }
      halt = ->(r) { r.halt }
      result = init.map(add_tax).map(halt).map(add_tax)
      expect(result.value).to eq(15)
    end
  end

  describe 'Pipes::Step' do
    specify '#>>' do
      step1 = Pipes::Step.new { |r| r.success(r.value + 5) }
      step2 = Pipes::Step.new { |r| r.success(r.value - 2) }
      step3 = Pipes::Step.new { |r| r.halt }
      pipeline = Pipes::Noop >> step1 >> step2 >> step3 >> ->(r) { r.success(r.value + 1) }

      expect(pipeline.call(10).success?).to be(false)
      expect(pipeline.call(10).value).to eq(13)
    end

    specify '#transform' do
      to_i = Pipes::Noop.transform(&:to_i)
      plus_ten = Pipes::Noop.transform { |value| value + 10 }
      pipeline = to_i >> plus_ten
      expect(pipeline.call('5').value).to eq(15)
    end

    specify '#check' do
      is_a_string = Pipes::Noop.check('not a string') { |value| value.is_a?(::String) }
      expect(is_a_string.call('yup').success?).to be(true)
      expect(is_a_string.call(10).success?).to be(false)
      expect(is_a_string.call(10).error).to eq('not a string')
    end

    specify '#is_a' do
      pipeline = Pipes::Noop.is_a(::Integer).transform { |v| v + 5 }
      assert_result(pipeline.call(10), 15, true)
      assert_result(pipeline.call('nope'), 'nope', false)
    end

    specify '#|' do
      integer = Pipes::Noop.is_a(::Integer)
      string = Pipes::Noop.is_a(::String)
      to_s = Pipes::Noop.transform(&:to_s)
      title = Pipes::Noop.transform { |v| "The number is #{v}" }

      pipeline = string | (integer >> to_s >> title)

      assert_result(pipeline.call('10'), '10', true)
      assert_result(pipeline.call(10), 'The number is 10', true)
    end

    specify '#meta' do
      to_s = Pipes::Noop.transform(&:to_s).meta(type: :string)
      to_i = Pipes::Noop.transform(&:to_i).meta(type: :integer).meta(foo: 'bar')
      pipe = to_s >> to_i
      expect(to_s.metadata[:type]).to eq(:string)
      expect(pipe.metadata[:type]).to eq(:integer)
      expect(pipe.metadata[:foo]).to eq('bar')
    end

    specify '#not' do
      string = Pipes::Noop.check('not a string') { |v| v.is_a?(::String) }
      assert_result(Pipes::Noop.not(string).call(10), 10, true)
      assert_result(Pipes::Noop.not(string).call('hello'), 'hello', false)

      assert_result(string.not.call(10), 10, true)
    end

    specify '#value' do
      assert_result(Pipes::Noop.value('hello').call('hello'), 'hello', true)
      assert_result(Pipes::Noop.value('hello').call('nope'), 'nope', false)
    end

    specify '#static' do
      assert_result(Pipes::Noop.static('hello').call('hello'), 'hello', true)
      assert_result(Pipes::Noop.static('hello').call('nope'), 'hello', true)
      assert_result(Pipes::Noop.static { |_| 'hello' }.call('nope'), 'hello', true)
    end

    specify '#default' do
      assert_result(Pipes::Noop.default('hello').call('bye'), 'bye', true)
      assert_result(Pipes::Noop.default('hello').call(nil), nil, true)
      assert_result(Pipes::Noop.default('hello').call(Pipes::Undefined), 'hello', true)
    end

    specify '#optional' do
      assert_result(Pipes::Types::String.optional.call('bye'), 'bye', true)
      assert_result(Pipes::Types::String.call(nil), nil, false)
      assert_result(Pipes::Types::String.optional.call(nil), nil, true)
    end

    specify '#coerce' do
      assert_result(Pipes::Noop.coerce(::Numeric, &:to_i).call(10.5), 10, true)
      assert_result(Pipes::Noop.coerce(::Numeric, &:to_i).call('10.5'), '10.5', false)
      assert_result(Pipes::Noop.coerce((0..3), &:to_s).call(2), '2', true)
      assert_result(Pipes::Noop.coerce((0..3), &:to_s).call(4), 4, false)
      assert_result(Pipes::Noop.coerce(/true/i) { |_| true }.call('True'), true, true)
      assert_result(Pipes::Noop.coerce(/true/i) { |_| true }.call('TRUE'), true, true)
      assert_result(Pipes::Noop.coerce(/true/i) { |_| true }.call('nope'), 'nope', false)
      assert_result(Pipes::Noop.coerce(1) { |_| true }.call(1), true, true)
    end

    specify '#constructor' do
      custom = Struct.new(:name) do
        def self.build(name)
          new(name)
        end
      end
      assert_result(Pipes::Noop.constructor(custom).call('Ismael'), custom.new('Ismael'), true)
      with_block = Pipes::Noop.constructor(custom){ |v| custom.new('mr. %s' % v) }
      expect(with_block.call('Ismael').value.name).to eq('mr. Ismael')
      with_symbol = Pipes::Noop.constructor(custom, :build)
      expect(with_symbol.call('Ismael').value.name).to eq('Ismael')
    end

    describe '#rule' do
      specify ':eq' do
        custom = Struct.new(:value) do
          def ==(v)
            value == v
          end
        end

        assert_result(Pipes::Types::Integer.rule(eq: 1).call(1), 1, true)
        assert_result(Pipes::Types::Integer.rule(eq: 1).call(2), 2, false)
        assert_result(Pipes::Types::Integer.rule(eq: custom.new(1)).call(1), 1, true)
      end

      specify ':not_eq' do
        assert_result(Pipes::Types::Integer.rule(not_eq: 1).call(1), 1, false)
        assert_result(Pipes::Types::Integer.rule(not_eq: 1).call(2), 2, true)
      end

      specify ':gt, :lt' do
        assert_result(Pipes::Types::Integer.rule(gt: 10, lt: 20).call(11), 11, true)
        assert_result(Pipes::Types::Integer.rule(gt: 10, lt: 20).call(9), 9, false)
        assert_result(Pipes::Types::Integer.rule(gt: 20).call(21), 21, true)
        assert_result(Pipes::Types::Integer.rule(gt: 10, lt: 20).call(20), 20, false)
        expect(Pipes::Types::Integer.rule(gt: 10, lt: 20).call(9).error).to eq('must be greater than 10')
      end

      specify ':match' do
        assert_result(Pipes::Types::String.rule(match: /hello/).call('hello world'), 'hello world', true)
        assert_result(Pipes::Types::String.rule(match: /hello/).call('bye world'), 'bye world', false)
        assert_result(Pipes::Types::Integer.rule(match: (1..10)).call(8), 8, true)
        assert_result(Pipes::Types::Integer.rule(match: (1..10)).call(11), 11, false)
      end

      specify ':included_in' do
        assert_result(Pipes::Types::String.rule(included_in: %w(a b c)).call('b'), 'b', true)
        assert_result(Pipes::Types::String.rule(included_in: %w(a b c)).call('d'), 'd', false)
      end

      specify ':excluded_from' do
        assert_result(Pipes::Types::String.rule(excluded_from: %w(a b c)).call('b'), 'b', false)
        assert_result(Pipes::Types::String.rule(excluded_from: %w(a b c)).call('d'), 'd', true)
      end

      specify ':respond_to' do
        assert_result(Pipes::Types::String.rule(respond_to: :strip).call('b'), 'b', true)
        assert_result(Pipes::Types::String.rule(respond_to: %i[strip chomp]).call('b'), 'b', true)
        assert_result(Pipes::Types::String.rule(respond_to: %i[strip nope]).call('b'), 'b', false)
        assert_result(Pipes::Types::String.rule(respond_to: :nope).call('b'), 'b', false)
      end

      specify ':is_a' do
        assert_result(Pipes::Noop.rule(is_a: String).call('b'), 'b', true)
        assert_result(Pipes::Noop.rule(is_a: String).call(1), 1, false)
      end
    end

    describe 'built-in types' do
      specify Pipes::Types::String do
        assert_result(Pipes::Types::String.call('aa'), 'aa', true)
        assert_result(Pipes::Types::String.call(10), 10, false)
      end

      specify Pipes::Types::Integer do
        assert_result(Pipes::Types::Integer.call(10), 10, true)
        assert_result(Pipes::Types::Integer.call('10'), '10', false)
      end

      specify Pipes::Types::True do
        expect(Pipes::Types::True.metadata[:type]).to eq('Parametric::Pipes::Types::True')
        assert_result(Pipes::Types::True.call(true), true, true)
        assert_result(Pipes::Types::True.call(false), false, false)
      end

      specify Pipes::Types::Boolean do
        expect(Pipes::Types::Boolean.metadata[:type]).to eq('Parametric::Pipes::Types::Boolean')
        assert_result(Pipes::Types::Boolean.call(true), true, true)
        assert_result(Pipes::Types::Boolean.call(false), false, true)
        assert_result(Pipes::Types::Boolean.call('true'), 'true', false)
      end

      specify Pipes::Types::Lax::String do
        assert_result(Pipes::Types::Lax::String.call('aa'), 'aa', true)
        assert_result(Pipes::Types::Lax::String.call(11), '11', true)
        assert_result(Pipes::Types::Lax::String.call(11.10), '11.1', true)
        assert_result(Pipes::Types::Lax::String.call(BigDecimal('111.2011')), '111.2011', true)
        assert_result(Pipes::Types::String.call(true), true, false)
      end

      specify Pipes::Types::Lax::Integer do
        assert_result(Pipes::Types::Lax::Integer.call(113), 113, true)
        assert_result(Pipes::Types::Lax::Integer.call(113.10), 113, true)
        assert_result(Pipes::Types::Lax::Integer.call('113'), 113, true)
        assert_result(Pipes::Types::Lax::Integer.call('113.10'), 113, true)
        assert_result(Pipes::Types::Lax::Integer.call('nope'), 'nope', false)
      end

      specify Pipes::Types::Forms::Boolean do
        assert_result(Pipes::Types::Forms::Boolean.call(true), true, true)
        assert_result(Pipes::Types::Forms::Boolean.call(false), false, true)
        assert_result(Pipes::Types::Forms::Boolean.call('true'), true, true)

        assert_result(Pipes::Types::Forms::Boolean.call('false'), false, true)
        assert_result(Pipes::Types::Forms::Boolean.call('1'), true, true)
        assert_result(Pipes::Types::Forms::Boolean.call('0'), false, true)
        assert_result(Pipes::Types::Forms::Boolean.call(1), true, true)
        assert_result(Pipes::Types::Forms::Boolean.call(0), false, true)

        assert_result(Pipes::Types::Forms::Boolean.call('nope'), 'nope', false)
      end
    end

    specify Pipes::Types::Array do
      assert_result(Pipes::Types::Array.call(1), 1, false)
      assert_result(Pipes::Types::Array.call([]), [], true)
      assert_result(
        Pipes::Types::Array.of(Pipes::Types::Boolean).call([true, true, false]),
        [true, true, false],
        true
      )
      Pipes::Types::Array.of(Pipes::Types::Boolean).call([true, 'nope', false, 1]).tap do |result|
        expect(result.success?).to be false
        expect(result.value).to eq [true, 'nope', false, 1]
        expect(result.error[1]).to match(/must be/)
        expect(result.error[3]).to match(/must be/)
      end
      assert_result(
        Pipes::Types::Array.of(Pipes::Noop.value('a') | Pipes::Noop.value('b')).call(['a', 'b', 'a']),
        %w[a b a],
        true
      )
      assert_result(
        Pipes::Types::Array.of(Pipes::Types::Boolean).default([true]).call(Pipes::Undefined),
        [true],
        true
      )
    end

    specify 'Types::Array.concurrent' do
      slow_type = Pipes::Noop.transform { |r| sleep(0.02); r }
      array = Pipes::Types::Array.of(slow_type).concurrent
      assert_result(array.call(1), 1, false)
      result, elapsed = bench do
        array.call(%w[a b c])
      end
      assert_result(result, %w[a b c], true)
      expect(elapsed).to be < 30

      assert_result(array.optional.call(nil), nil, true)
    end

    describe Pipes::Types::Hash do
      specify do
        assert_result(Pipes::Types::Hash.call({foo: 1}), {foo: 1}, true)
        assert_result(Pipes::Types::Hash.call(1), 1, false)

        hash = Pipes::Types::Hash.schema(
          title: Pipes::Types::String.default('Mr'),
          name: Pipes::Types::String,
          age: Pipes::Types::Lax::Integer,
          friend: Pipes::Types::Hash.schema(name: Pipes::Types::String)
        )

        assert_result(hash.call({name: 'Ismael', age: '42', friend: { name: 'Joe' }}), {title: 'Mr', name: 'Ismael', age: 42, friend: { name: 'Joe' }}, true)

        hash.call({title: 'Dr', name: 'Ismael', friend: {}}).tap do |result|
          expect(result.success?).to be false
          expect(result.value).to eq({title: 'Dr', name: 'Ismael', friend: { }})
          expect(result.error[:age]).to be_a(::String)
          expect(result.error[:friend][:name]).to be_a(::String)
        end
      end

      specify '#|' do
        hash1 = Pipes::Types::Hash.schema(foo: Pipes::Types::String)
        hash2 = Pipes::Types::Hash.schema(bar: Pipes::Types::Integer)
        union = hash1 | hash2

        assert_result(union.call(foo: 'bar'), { foo: 'bar' }, true)
        assert_result(union.call(bar: 10), { bar: 10 }, true)
        assert_result(union.call(bar: '10'), { bar: '10' }, false)
      end

      specify 'optional keys' do
        hash = Pipes::Types::Hash.schema(
          title: Pipes::Types::String.default('Mr'),
          name?: Pipes::Types::String,
          age?: Pipes::Types::Lax::Integer
        )

        assert_result(hash.call({}), {title: 'Mr'}, true)
      end

      specify '&' do
        s1 = Pipes::Types::Hash.schema(name: Pipes::Types::String)
        s2 = Pipes::Types::Hash.schema(age: Pipes::Types::Integer)
        s3 = s1 & s2

        assert_result(s3.call(name: 'Ismael', age: 42), {name: 'Ismael', age: 42}, true)
        assert_result(s3.call(age: 42), {age: 42}, false)
      end
    end
  end

  module TestNamespace
    extend Pipes::TypeNamespace

    define(:Foo) { Pipes::Noop }
  end

  specify Pipes::TypeNamespace do
    expect(TestNamespace::Foo.metadata[:type]).to eq('TestNamespace::Foo')
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
