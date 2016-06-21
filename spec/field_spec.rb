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

          def exists?(*_)
            true
          end

          def valid?(*_)
            true
          end

          def coerce(value, key, context)
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

      it 'raises if filter not found' do
        expect{
          subject.filter(:foobar)
        }.to raise_exception Parametric::ConfigurationError
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
        test_no_error(context) do
          subject.options(['a', 'b', 'c'])
          test_field(subject, {a_key: 'b'}, 'b')
        end
      end

      it 'resolves if value is array within options' do
        test_no_error(context) do
          subject.options(['a', 'b', 'c'])
          test_field(subject, {a_key: ['b', 'c']}, ['b', 'c'])
        end
      end

      it 'does not resolve if missing key' do
        test_no_error(context) do
          test_field_noop(subject.options(['a', 'b']), {foobar: 'd'})
        end
      end

      it 'does resolve if missing key and default set' do
        test_no_error(context) do
          test_field(subject.options(['a', 'b']).default('c'), {foo: 1}, 'c')
        end
      end

      it 'is invalid if required and missing key' do
        test_error(context) do
          test_field_noop(subject.options(['a', 'b']).required, {foobar: 'd'})
        end
      end

      context 'value outside options' do
        before { subject.options(['a', 'b', 'c']) }

        it 'does not resolve' do
          test_field_noop(subject, {a_key: 'd'})
        end

        it 'validates single value and adds error to context' do
          test_error(context) do
            subject.resolve({a_key: 'd'}, context)
          end
        end

        it 'validates array and adds error to context' do
          test_error(context) do
            subject.resolve({a_key: ['a', 'd']}, context)
          end
        end

        context 'with default' do
          before { subject.default('b') }

          it 'is valid and returns if default' do
            test_no_error(context) do
              test_field(subject, {a_key: 'd'}, 'b')
            end
            test_no_error(context) do
              test_field(subject, {a_key: ['a', 'd']}, 'b')
            end
          end
        end
      end
    end

    describe '#default' do
      it 'returns default if key is missing' do
        test_field(subject.default('nope'), {foo: 'd'}, 'nope')
      end

      it 'returns value if key is present' do
        test_field(subject.default('nope'), {a_key: 'yai'}, 'yai')
        test_field(subject.default('nope'), {a_key: nil}, nil)
      end
    end

    describe '#required' do
      before { subject.required }

      it 'is valid when key is present' do
        test_no_error(context) do
          test_field(subject, {a_key: 'yes'}, 'yes')
          test_field(subject, {a_key: true}, true)
          test_field(subject, {a_key: false}, false)
          test_field(subject, {a_key: nil}, nil)
        end
      end

      it 'is invalid when key is missing' do
        test_error(context) do
          subject.resolve({foo: 123}, context)
        end
      end
    end

    describe '#present' do
      before { subject.present }

      it 'is valid when value is present' do
        test_no_error(context) do
          test_field(subject, {a_key: 'yes'}, 'yes')
          test_field(subject, {a_key: true}, true)
          test_field(subject, {a_key: false}, false)
        end
      end

      it 'is invalid when key is missing' do
        test_error(context) do
          subject.resolve({foo: 123}, context)
        end
      end

      it 'is invalid when value is nil' do
        test_error(context) do
          subject.resolve({a_key: nil}, context)
        end
      end
    end

    describe '#validate' do
      let(:validator) do
        Class.new do
          def initialize(num)
            @num = num
          end

          def message
            "foo"
          end

          def coerce(value, key, context)
            value
          end

          def exists?(*args)
            true
          end

          def valid?(value, key, *args)
            value.to_i < @num
          end
        end
      end

      it 'raises if validator not found' do
        expect{
          subject.validate(:foobar)
        }.to raise_exception Parametric::ConfigurationError
      end

      it 'works with symbol to registered class' do
        subject.validate(:format, /^Foo/)

        test_error(context) do
          subject.resolve({a_key: 'lalalade'}, context)
        end
        test_no_error(context) do
          test_field(subject, {a_key: 'Foobar'}, 'Foobar')
        end
      end

      it 'works with a class' do
        subject.validate(validator, 10)

        test_error(context) do
          subject.resolve({a_key: 11}, context)
        end
        test_no_error(context) do
          test_field(subject, {a_key: 9}, 9)
        end
      end

      it 'works with an instance' do
        subject.validate(validator.new(10))

        test_error(context) do
          subject.resolve({a_key: 11}, context)
        end
        test_no_error(context) do
          test_field(subject, {a_key: 9}, 9)
        end
      end
    end

    describe '#schema' do
      context 'with block' do
        before do
          subject.schema do
            field :name
          end
        end

        it 'works' do
          test_no_error(context) do
            test_field(subject, {a_key: {name: "Ismael", title: "Mr."}}, {name: "Ismael"})
          end
        end
      end

      context 'with schema instance' do
        let(:schema) do
          Parametric::Schema.new do
            field :last_name
          end
        end

        it 'works' do
          subject.schema(schema)
          test_no_error(context) do
            test_field(subject, {a_key: {last_name: "Celis", title: "Mr."}}, {last_name: "Celis"})
          end
        end
      end
    end
  end
end
