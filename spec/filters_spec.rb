require 'spec_helper'

describe 'default filters' do
  def test_filter(key, value, expected)
    filter = Parametric.registry.filters[key]
    expect(filter.call(value, nil, nil)).to eq expected
  end

  describe ':integer' do
    it {
      test_filter(:integer, '10', 10)
      test_filter(:integer, '10.20', 10)
      test_filter(:integer, 10.20, 10)
      test_filter(:integer, 10, 10)
    }
  end

  describe ':number' do
    it {
      test_filter(:number, '10', 10.0)
      test_filter(:number, '10.20', 10.20)
      test_filter(:number, 10.20, 10.20)
      test_filter(:number, 10, 10.0)
    }
  end

  describe ':string' do
    it {
      test_filter(:string, '10', '10')
      test_filter(:string, '10.20', '10.20')
      test_filter(:string, 10.20, '10.2')
      test_filter(:string, 10, '10')
      test_filter(:string, true, 'true')
      test_filter(:string, 'hello', 'hello')
    }
  end

  describe ':boolean' do
    it {
      test_filter(:boolean, true, true)
      test_filter(:boolean, '10', true)
      test_filter(:boolean, '', true)
      test_filter(:boolean, nil, false)
      test_filter(:boolean, false, false)
    }
  end

  describe ':split' do
    it {
      test_filter(:split, 'aaa,bb,cc', ['aaa', 'bb', 'cc'])
      test_filter(:split, 'aaa ,bb,  cc', ['aaa', 'bb', 'cc'])
      test_filter(:split, 'aaa', ['aaa'])
      test_filter(:split, ['aaa', 'bb', 'cc'], ['aaa', 'bb', 'cc'])
    }
  end
end
