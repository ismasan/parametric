require 'spec_helper'

describe Parametric::Schema do
  before do
    Parametric.filter :flexible_bool, ->(v, k, c){
      case v
      when '1', 'true', 'TRUE', true
        true
      else
        false
      end
    }

  end

  subject do
    described_class.new do
      field(:title).type(:string).present
      field(:price).type(:integer)
      field(:status).type(:string).options(['visible', 'hidden'])
      field(:tags).type(:array).filter(:split)
      field(:description).type(:string)
      field(:variants).type(:array).schema do
        field(:name).type(:string).present
        field(:sku)
        field(:stock).type(:integer).default(1)
        field(:available_if_no_stock).type(:boolean).filter(:flexible_bool).default(false)
      end
    end
  end

  def resolve(schema, payload, &block)
    yield schema.resolve(payload)
  end

  def test_schema(schema, payload, result)
    resolve(schema, payload) do |results|
      expect(results.output).to eq result
    end
  end

  it 'works' do
    test_schema(subject, {
      title: 'iPhone 6 Plus',
      price: '100.0',
      status: 'visible',
      tags: 'tag1, tag2',
      description: 'A description',
      variants: [{name: 'v1', sku: 'ABC', stock: '10', available_if_no_stock: true}]
    },
    {
      title: 'iPhone 6 Plus',
      price: 100,
      status: 'visible',
      tags: ['tag1', 'tag2'],
      description: 'A description',
      variants: [{name: 'v1', sku: 'ABC', stock: 10, available_if_no_stock: true}]
    })

    test_schema(subject, {
      title: 'iPhone 6 Plus',
      variants: [{name: 'v1', available_if_no_stock: '1'}]
    },
    {
      title: 'iPhone 6 Plus',
      variants: [{name: 'v1', stock: 1, available_if_no_stock: true}]
    })

    resolve(subject, {}) do |results|
      expect(results.valid?).to be false
      expect(results.errors['$.title']).not_to be_nil
      expect(results.errors['$.status']).to be_nil
    end

    resolve(subject, {title: 'Foobar', variants: [{name: 'v1'}, {sku: '345'}]}) do |results|
      expect(results.valid?).to be false
      expect(results.errors['$.variants[1].name']).not_to be_nil
    end
  end
end
