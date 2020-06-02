# frozen_string_literal: true

require 'spec_helper'
require 'parametric/types'

include Parametric

RSpec.describe Types do
  specify 'building types' do
    type = Types::Type.new('test')
    assert_result(type.call(1), 1, true)

    str = type.rule(:is_a?, ::String)
    expect(str.object_id).not_to eq type.object_id
    assert_result(str.call(1), 1, false)
    assert_result(str.call('foo'), 'foo', true)

    coerced_str = str.coercion(10) { |v| 'ten' }
    expect(coerced_str.object_id).not_to eq str.object_id
    assert_result(coerced_str.call(10), 'ten', true)

    # it's frozen
    expect {
      coerced_str.send(:coercion!, :is_a?, ::Numeric)
    }.to raise_error(FrozenError)
  end

  specify Types::String do
    assert_result(Types::String.call('aa'), 'aa', true)
    assert_result(Types::String.call(10), 10, false)
  end

  specify Types::Integer do
    assert_result(Types::Integer.call(10), 10, true)
    assert_result(Types::Integer.call('10'), '10', false)
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

  specify Types::True do
    assert_result(Types::True.call(true), true, true)
    assert_result(Types::True.call(false), false, false)
  end

  specify Types::Boolean do
    assert_result(Types::Boolean.call(true), true, true)
    assert_result(Types::Boolean.call(false), false, true)
    assert_result(Types::Boolean.call('true'), 'true', false)
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

  specify Types::Union do
    union = Types::String | Types::Boolean | Types::Integer
    assert_result(union.call('foo'), 'foo', true)
    assert_result(union.call(false), false, true)
    assert_result(union.call(10), 10, true)
    assert_result(union.call({}), {}, false)
    assert_result(Types.union(Types::String, Types::Boolean).call('foo'), 'foo', true)
    assert_result(Types.union(Types::String, Types::Boolean).call(true), true, true)
    assert_result(Types.union(Types::String, Types::Boolean).call(11), 11, false)
  end

  specify Types::Nothing do
    assert_result(Types::Nothing.call(), Parametric::Undefined, true)
    assert_result(Types::Nothing.call(''), '', false)
  end

  specify Types::Static do
    type = Types::Static.new('foo')
    assert_result(type.call(1), 'foo', true)
    assert_result(type.call('dd'), 'foo', true)

    type = Types::Static.new { 'bar' }
    assert_result(type.call(1), 'bar', true)
  end

  specify Types::Transform do
    type = Types::Transform.new{ |v| "Mr. #{v}" }
    assert_result(type.call('Ismael'), 'Mr. Ismael', true)
  end

  specify '#transform' do
    type = Types::String.transform { |v| "Mr. #{v}" }
    assert_result(type.call('Ismael'), 'Mr. Ismael', true)
  end

  specify Types::Pipeline do
    pipeline = Types::Pipeline.new([Types::String, Types::Transform.new{|v| "Mr. #{v}" }])
    assert_result(pipeline.call('Ismael'), 'Mr. Ismael', true)
    assert_result(pipeline.call(1), 1, false)

    pipeline = Types::String > Types::Transform.new{|v| "Mrs. #{v}" }
    assert_result(pipeline.call('Joan'), 'Mrs. Joan', true)

    meta_pipeline = pipeline > Types::Transform.new{|v| "Hello, #{v}" }
    assert_result(meta_pipeline.call('Joan'), 'Hello, Mrs. Joan', true)

    # custom default for blank string
    default_if_blank = (Types.value('') > Types::Static.new('nope')) | Types::String
    assert_result(default_if_blank.call(''), 'nope', true)
    assert_result(default_if_blank.call('yes'), 'yes', true)
    assert_result(default_if_blank.call(10), 10, false)
  end

  specify '.maybe' do
    union = Types::Nil | Types::String
    assert_result(union.call(nil), nil, true)
    assert_result(union.call('foo'), 'foo', true)
    assert_result(union.call(11), 11, false)

    assert_result(Types.maybe(Types::String).call(nil), nil, true)
    assert_result(Types.maybe(Types::String).call('foo'), 'foo', true)
    assert_result(Types.maybe(Types::String).call(11), 11, false)
    assert_result(Types.maybe(Types::Lax::String).call(11), '11', true)
  end

  specify '#optional' do
    type = Types::String.optional
    assert_result(type.call('nope'), 'nope', true)
    assert_result(type.call(nil), nil, true)
    assert_result(type.call(10), 10, false)
  end

  specify Types::CSV do
    assert_result(
      Types::CSV.call('one,two, three , four'),
      %w[one two three four],
      true
    )
  end

  specify Types::Array do
    assert_result(Types::Array.call([]), [], true)
    assert_result(
      Types::Array.of(Types::Boolean).call([true, true, false]),
      [true, true, false],
      true
    )
    Types::Array.of(Types::Boolean).call([true, 'nope', false]).tap do |result|
      expect(result.success?).to be false
      expect(result.value).to eq [true, 'nope', false]
      expect(result.error[1]).to match(/failed/)
    end
    assert_result(
      Types::Array.of(Types.value('a') | Types.value('b')).call(['a', 'b', 'a']),
      %w[a b a],
      true
    )
  end

  specify Types::Any do
    obj = Struct.new(:name).new('Joe')

    assert_result(Types::Any.call(1), 1, true)
    assert_result(Types::Any.call('foobar'), 'foobar', true)
    assert_result(Types::Any.call(obj), obj, true)
  end

  specify Types::Value do
    assert_result(Types::Value.new(1).call(1), 1, true)
    assert_result(Types::Value.new(1).call(10), 10, false)
    assert_result(Types::Value.new('foo').call('foo'), 'foo', true)
    assert_result(Types::Value.new('foo').call('bar'), 'bar', false)

    assert_result(Types.value('foo').call('foo'), 'foo', true)
    assert_result(Types.value('foo').call('bar'), 'bar', false)
  end

  specify '#default' do
    assert_result(Types::String.default('nope').call('yup'), 'yup', true)
    assert_result(Types::String.default('nope').call(), 'nope', true)
    assert_result(Types::String.default('nope').call(Parametric::Undefined), 'nope', true)

    assert_result(Types::Any.default(10).call(11), 11, true)
    assert_result(Types::Any.default(10).call(), 10, true)
    assert_result(Types::Any.default(10).default(13).call(), 13, true)

    # it works with procs
    val = 'foo'
    type = Types::String.default { val }
    assert_result(type.call(), val, true)

    # it can be union'd
    with_default = Types::String.default('nope')

    union = with_default | Types::Integer
    assert_result(union.call(), 'nope', true)
    assert_result(union.call(10), 10, true)
  end

  specify RuleRegistry do
    registry = RuleRegistry.new.tap do |r|
      r.define :is_a? do |value, type|
        value.is_a?(type)
      end
    end

    expect(registry[:is_a?].call('foo', ::String)).to be true
    expect(registry[:is_a?].call(1, ::String)).to be false

    set = RuleSet.new(registry)
    set.rule(:is_a?, ::String)
    expect(set.call('foo')).to eq [true, nil]
    expect(set.call(1)).to eq [false, %[failed is_a?(1, String)]]
  end

  specify '#options' do
    type = Types::String.options(%w[one two three])

    assert_result(type.call('one'), 'one', true)
    assert_result(type.call('two'), 'two', true)
    assert_result(type.call('three'), 'three', true)
    assert_result(type.call('four'), 'four', false)

    # it works alongside Default
    assert_result(Types::String.default('two').options(%w[one two]).call(), 'two', true)
    assert_result(Types::String.options(%w[one two]).default('two').call(), 'two', true)

    # it copies options
    copy = type.clone
    assert_result(copy.call('three'), 'three', true)
    assert_result(copy.call('four'), 'four', false)

    # it can be union'd
    union = type | Types::Integer
    assert_result(union.call('two'), 'two', true)
    assert_result(union.call(10), 10, true)
    assert_result(union.call('twenty'), 'twenty', false)
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
        expect(result.error[:age]).to match(/failed is_a\?/)
        expect(result.error[:friend][:name]).to match(/failed is_a\?/)
      end
    end

    specify 'optional keys' do
      hash = Types::Hash.schema(
        title: Types::String.default('Mr'),
        Types::Key.new(:name, optional: true) => Types::String,
        Types::Key.new(:age, optional: true) => Types::Lax::Integer
      )

      assert_result(hash.call({}), {title: 'Mr'}, true)
    end

    specify '&' do
      s1 = Types::Hash.schema(name: Types::String)
      s2 = Types::Hash.schema(age: Types::Integer)
      s3 = s1 & s2

      assert_result(s3.call(name: 'Ismael', age: 42), {name: 'Ismael', age: 42}, true)
      assert_result(s3.call(age: 42), {age: 42}, false)
    end

    specify '>' do
      s1 = Types::Hash.schema(name: Types::String)
      s2 = Types::Hash.schema(age: Types::Integer)

      pipe = s1 > s2
      assert_result(pipe.call(name: 'Ismael', age: 42), {name: 'Ismael', age: 42}, true)
      assert_result(pipe.call(age: 42), {}, false)
    end
  end

  describe Types::Registry do
    specify do
      root = Types::Registry.new
      root[:integer] = Types::Integer
      root[:string] = Types::String
      child = Types::Registry.new(parent: root)
      child[:integer] = Types::Integer.coercion(::String, &:to_i)

      assert_result(root[:integer].call(10), 10, true)
      assert_result(root[:integer].call('10'), '10', false)
      assert_result(child[:integer].call('10'), 10, true)
      assert_result(child[:string].call('hi'), 'hi', true)
    end
  end

  describe Types::Schema do
    specify 'defining a nested schema' do
      schema = Types::Schema.new do |sc|
        sc.field(:title).type(:string).default('Mr')
        sc.field(:name).type(:string)
        sc.field?(:age).type(:integer)
        sc.field(:friend).type(:hash).schema do |s|
          s.field(:name).type(:string)
        end
      end

      assert_result(schema.call({name: 'Ismael', age: 42, friend: { name: 'Joe' }}), {title: 'Mr', name: 'Ismael', age: 42, friend: { name: 'Joe' }}, true)
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
    end
  end

  private

  def assert_result(result, value, is_success, debug: false)
    byebug if debug
    expect(result.value).to eq value
    expect(result.success?).to be is_success
  end
end
