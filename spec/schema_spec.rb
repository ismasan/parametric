require 'spec_helper'

describe Parametric::Schema do
  before do
    Parametric.coercion :flexible_bool, ->(v, k, c){
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
      field(:tags).coerce(:split).type(:array)
      field(:description).type(:string)
      field(:variants).type(:array).schema do
        field(:name).type(:string).present
        field(:sku)
        field(:stock).type(:integer).default(1)
        field(:available_if_no_stock).type(:boolean).coerce(:flexible_bool).default(false)
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

  describe "#policy" do
    it "applies policy to all fields" do
      subject.policy(:declared)

      resolve(subject, {}) do |results|
        expect(results.valid?).to be true
        expect(results.errors.keys).to be_empty
      end
    end

    it "applies :noop policy to all fields" do
      subject.policy(:noop)

      resolve(subject, {}) do |results|
        expect(results.valid?).to be false
        expect(results.errors['$.title']).not_to be_nil
      end
    end
  end

  describe "#merge" do
    context "no options" do
      let!(:schema1) {
        described_class.new do
          field(:title).type(:string).present
          field(:price).type(:integer)
        end
      }

      let!(:schema2) {
        described_class.new do
          field(:price).type(:string)
          field(:description).type(:string)
        end
      }

      it "returns a new schema adding new fields and updating existing ones" do
        new_schema = schema1.merge(schema2)
        expect(new_schema.fields.keys).to match_array([:title, :price, :description])

        # did not mutate original
        expect(schema1.fields[:price].meta_data[:type]).to eq :integer

        expect(new_schema.fields[:title].meta_data[:type]).to eq :string
        expect(new_schema.fields[:price].meta_data[:type]).to eq :string
      end
    end

    context "with options" do
      let!(:schema1) {
        described_class.new(price_type: :integer) do |opts|
          field(:title).type(:string).present
          field(:price).type(opts[:price_type])
        end
      }

      let!(:schema2) {
        described_class.new(price_type: :string) do
          field(:description).type(:string)
        end
      }

      it "re-applies blocks with new options" do
        new_schema = schema1.merge(schema2)
        expect(new_schema.fields.keys).to match_array([:title, :price, :description])

        # did not mutate original
        expect(schema1.fields[:price].meta_data[:type]).to eq :integer

        expect(new_schema.fields[:title].meta_data[:type]).to eq :string
        expect(new_schema.fields[:price].meta_data[:type]).to eq :string
      end
    end
  end
end
