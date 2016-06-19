require 'spec_helper'

describe Parametric::Field do
  let(:key) { :a_key }
  let(:context) { Parametric::Context.new }
  let(:registry) { Parametric.registry }
  subject { described_class.new(key, registry) }

  def test_field(field, payload, expected)
    field.resolve(payload, context) do |r|
      expect(r).to eq expected
      return
    end
    raise "did not resolve"
  end

  def test_field_noop(field, payload)
    result = :noop
    field.resolve(payload, context) do |r|
      result = r
    end
    expect(result).to eq :noop
  end

  def test_error(ctx, &block)
    expect(ctx).to receive(:add_error)
    yield
  end

  def test_no_error(ctx, &block)
    expect(ctx).not_to receive(:add_error)
    yield
  end

  describe '#resolve' do
    it 'returns value' do
      test_field(subject, {a_key: 'value'}, 'value')
    end

    describe '#type' do
      it 'coerces integer' do
        subject.type(:integer)
        test_field(subject, {a_key: '10.0'}, 10)
      end

      it 'coerces number' do
        subject.type(:number)
        test_field(subject, {a_key: '10.0'}, 10.0)
      end

      it 'coerces string' do
        subject.type(:string)
        test_field(subject, {a_key: 10.0}, '10.0')
      end
    end

    describe '#filter' do
      let(:custom_klass) do
        Class.new do
          def initialize(title = 'Sr.')
            @title = title
          end

          def call(value, key, context)
            "#{@title} #{value}"
          end
        end
      end

      it 'works with lambdas' do
        subject.filter(->(value, key, context){ "Mr. #{value}" })
        test_field(subject, {a_key: 'Ismael'}, 'Mr. Ismael')
      end

      it 'works with class' do
        subject.filter(custom_klass)
        test_field(subject, {a_key: 'Ismael'}, 'Sr. Ismael')
      end

      it 'works with class and arguments' do
        subject.filter(custom_klass, 'Lord')
        test_field(subject, {a_key: 'Ismael'}, 'Lord Ismael')
      end

      it 'works with instance' do
        subject.filter(custom_klass.new('Dr.'))
        test_field(subject, {a_key: 'Ismael'}, 'Dr. Ismael')
      end

      it 'works with filter in registry' do
        registry.filter :foo, ->(v, k, c){ "Hello #{v}" }
        subject.filter(:foo)
        test_field(subject, {a_key: 'Ismael'}, 'Hello Ismael')
      end

      it 'chains filters' do
        subject
          .filter(custom_klass, 'General')
          .filter(custom_klass, 'Commander')

        test_field(subject, {a_key: 'Ismael'}, 'Commander General Ismael')
      end
    end

    describe '#options' do
      it 'resolves if value within options' do
        subject.options(['a', 'b', 'c'])
        test_field(subject, {a_key: 'b'}, 'b')
      end

      context 'value outside options' do
        before { subject.options(['a', 'b', 'c']) }

        it 'does not resolve' do
          test_field_noop(subject, {a_key: 'd'})
        end

        it 'validates and adds error to context' do
          test_error(context) do
            subject.resolve({a_key: 'd'}, context)
          end
        end

        it 'is valid and returns if default' do
          subject.default('b')
          test_no_error(context) do
            test_field(subject, {a_key: 'd'}, 'b')
          end
        end
      end
    end

    describe '#default' do

    end

    describe '#required' do

    end

    describe '#validate' do

    end

    describe '#schema' do

    end
  end
end
