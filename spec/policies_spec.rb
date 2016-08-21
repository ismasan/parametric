require 'spec_helper'

describe 'default coercions' do
  def test_coercion(key, value, expected)
    coercion = Parametric.registry.coercions[key]
    expect(coercion.new.coerce(value, nil, nil)).to eq expected
  end

  describe ':integer' do
    it {
      test_coercion(:integer, '10', 10)
      test_coercion(:integer, '10.20', 10)
      test_coercion(:integer, 10.20, 10)
      test_coercion(:integer, 10, 10)
    }
  end

  describe ':number' do
    it {
      test_coercion(:number, '10', 10.0)
      test_coercion(:number, '10.20', 10.20)
      test_coercion(:number, 10.20, 10.20)
      test_coercion(:number, 10, 10.0)
    }
  end

  describe ':string' do
    it {
      test_coercion(:string, '10', '10')
      test_coercion(:string, '10.20', '10.20')
      test_coercion(:string, 10.20, '10.2')
      test_coercion(:string, 10, '10')
      test_coercion(:string, true, 'true')
      test_coercion(:string, 'hello', 'hello')
    }
  end

  describe ':boolean' do
    it {
      test_coercion(:boolean, true, true)
      test_coercion(:boolean, '10', true)
      test_coercion(:boolean, '', true)
      test_coercion(:boolean, nil, false)
      test_coercion(:boolean, false, false)
    }
  end

  describe ':split' do
    it {
      test_coercion(:split, 'aaa,bb,cc', ['aaa', 'bb', 'cc'])
      test_coercion(:split, 'aaa ,bb,  cc', ['aaa', 'bb', 'cc'])
      test_coercion(:split, 'aaa', ['aaa'])
      test_coercion(:split, ['aaa', 'bb', 'cc'], ['aaa', 'bb', 'cc'])
    }
  end
end
