require 'spec_helper'

describe 'default validators' do

  def test_validator(payload, key, name, exists, valid, *args)
    validator = Parametric.registry.validators[name]
    validator = validator.new(*args) if validator.respond_to?(:new)
    expect(validator.exists?(payload[key], key, payload)).to eq exists
    expect(validator.valid?(payload[key], key, payload)).to eq valid
  end

  describe ':format' do
    it {
      test_validator({key: 'Foobar'}, :key, :format, true, true, /^Foo/)
      test_validator({key: 'Foobar'}, :key, :format, true, false, /^Bar/)
      test_validator({foo: 'Foobar'}, :key, :format, false, true, /^Foo/)
    }
  end

  describe ':email' do
    it {
      test_validator({key: 'foo@bar.com'}, :key, :email, true, true)
      test_validator({key: 'foo@'}, :key, :email, true, false)
      test_validator({foo: 'foo@bar.com'}, :key, :email, false, true)
    }
  end

  describe ':required' do
    it {
      test_validator({key: 'foo'}, :key, :required, true, true)
      test_validator({key: ''}, :key, :required, true, true)
      test_validator({key: nil}, :key, :required, true, true)
      test_validator({foo: 'foo'}, :key, :required, true, false)
    }
  end

  describe ':present' do
    it {
      test_validator({key: 'foo'}, :key, :present, true, true)
      test_validator({key: ''}, :key, :present, true, false)
      test_validator({key: nil}, :key, :present, true, false)
      test_validator({foo: 'foo'}, :key, :present, true, false)
    }
  end

  describe ':gt' do
    it {
      test_validator({key: 10}, :key, :gt, true, true, 9)
      test_validator({key: '10'}, :key, :gt, true, true, 9)
      test_validator({key: 10}, :key, :gt, true, false, 11)
      test_validator({key: '10'}, :key, :gt, true, false, 11)
      test_validator({foo: '10'}, :key, :gt, true, true, 11)
    }
  end

  describe ':lt' do
    it {
      test_validator({key: 10}, :key, :lt, true, true, 11)
      test_validator({key: '10'}, :key, :lt, true, true, 11)
      test_validator({key: 10}, :key, :lt, true, false, 9)
      test_validator({key: '10'}, :key, :lt, true, false, 9)
      test_validator({foo: '10'}, :key, :lt, true, true, 9)
    }
  end

  describe ':options' do
    it {
      test_validator({key: 'b'}, :key, :options, true, true, %w(a b c))
      test_validator({key: 'd'}, :key, :options, false, false, %w(a b c))
      test_validator({key: ['c', 'b']}, :key, :options, true, true, %w(a b c))
      test_validator({key: ['c', 'b', 'd']}, :key, :options, false, false, %w(a b c))
      test_validator({foo: 'b'}, :key, :options, false, true, %w(a b c))
    }
  end
end
