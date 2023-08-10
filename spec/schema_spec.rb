require 'spec_helper'

describe Parametric::Schema do
  before do
    Parametric.policy :flexible_bool do
      coerce do |v, k, c|
        case v
        when '1', 'true', 'TRUE', true
          true
        else
          false
        end
      end
    end
  end

  subject do
    described_class.new do
      field(:title).policy(:string).present
      field(:price).policy(:integer).meta(label: "A price")
      field(:status).policy(:string).options(['visible', 'hidden'])
      field(:tags).policy(:split).policy(:array)
      field(:description).policy(:string)
      field(:variants).policy(:array).schema do
        field(:name).policy(:string).present
        field(:sku)
        field(:stock).policy(:integer).default(1)
        field(:available_if_no_stock).policy(:boolean).policy(:flexible_bool).default(false)
      end
    end
  end

  describe "#structure" do
    it "represents data structure and meta data" do
      sc = subject.structure
      expect(sc[:title][:present]).to be true
      expect(sc[:title][:type]).to eq :string
      expect(sc[:price][:type]).to eq :integer
      expect(sc[:price][:label]).to eq "A price"
      expect(sc[:variants][:type]).to eq :array
      sc[:variants][:structure].tap do |sc|
        expect(sc[:name][:type]).to eq :string
        expect(sc[:name][:present]).to be true
        expect(sc[:stock][:default]).to eq 1
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
      expect(results.errors['$.variants']).to be_nil
      expect(results.errors['$.status']).to be_nil
    end

    resolve(subject, {title: 'Foobar', variants: [{name: 'v1'}, {sku: '345'}]}) do |results|
      expect(results.valid?).to be false
      expect(results.errors['$.variants[1].name']).not_to be_nil
    end
  end

  it "ignores nil fields if using :declared policy" do
    schema = described_class.new do
      field(:id).type(:integer)
      field(:title).declared.type(:string)
    end

    resolve(schema, {id: 123}) do |results|
      expect(results.output.keys).to eq [:id]
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

    it "replaces previous policies" do
      subject.policy(:declared)
      subject.policy(:present)

      resolve(subject, {title: "hello"}) do |results|
        expect(results.valid?).to be false
        expect(results.errors.keys).to match_array(%w(
          $.price
          $.status
          $.tags
          $.description
          $.variants
        ))
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
          field(:title).policy(:string).present
          field(:price).policy(:integer)
        end
      }

      let!(:schema2) {
        described_class.new do
          field(:price).policy(:string)
          field(:description).policy(:string)
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

      it 'can merge from a block' do
        new_schema = schema1.merge do
          field(:price).policy(:string)
          field(:description).policy(:string)
        end

        expect(schema1.fields[:price].meta_data[:type]).to eq :integer
        expect(new_schema.fields[:title].meta_data[:type]).to eq :string
        expect(new_schema.fields[:price].meta_data[:type]).to eq :string
      end
    end

    context "with options" do
      let!(:schema1) {
        described_class.new(price_type: :integer, label: "Foo") do |opts|
          field(:title).policy(:string).present
          field(:price).policy(opts[:price_type]).meta(label: opts[:label])
        end
      }

      let!(:schema2) {
        described_class.new(price_type: :string) do
          field(:description).policy(:string)
        end
      }

      it "inherits options" do
        new_schema = schema1.merge(schema2)
        expect(new_schema.fields[:price].meta_data[:type]).to eq :string
        expect(new_schema.fields[:price].meta_data[:label]).to eq "Foo"
      end

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

  describe "#clone" do
    let!(:schema1) {
      described_class.new do |opts|
        field(:id).present
        field(:title).policy(:string).present
        field(:price)
      end
    }

    it "returns a copy that can be further manipulated" do
      schema2 = schema1.clone.policy(:declared).ignore(:id)
      expect(schema1.fields.keys).to match_array([:id, :title, :price])
      expect(schema2.fields.keys).to match_array([:title, :price])

      results1 = schema1.resolve(id: "abc", price: 100)
      expect(results1.errors.keys).to eq ["$.title"]

      results2 = schema2.resolve(id: "abc", price: 100)
      expect(results2.errors.keys).to eq []
    end
  end

  context 'yielding schema to definition, to preserve outer context' do
    it 'yields schema instance and options to definition block, can access outer context' do
      schema1 = described_class.new do
        field(:name).type(:string)
      end
      schema2 = described_class.new do |sc, _opts|
        sc.field(:user).schema schema1
      end

      out = schema2.resolve(user: { name: 'Joe' }).output
      expect(out[:user][:name]).to eq 'Joe'
    end
  end

  describe '#one_of for multiple sub-schemas' do
    let(:user_schema) do
      described_class.new do
        field(:name).type(:string).present
        field(:age).type(:integer).present
      end
    end

    let(:company_schema) do
      described_class.new do
        field(:name).type(:string).present
        field(:company_code).type(:string).present
      end
    end

    it 'picks the right sub-schema' do
      schema = described_class.new do |sc, _|
        sc.field(:type).type(:string)
        sc.field(:sub).type(:object).one_of do |sub|
          sub.index_by(:type)
          sub.on('user', user_schema)
          sub.on('company', company_schema)
        end
      end

      result = schema.resolve(type: 'user', sub: { name: 'Joe', age: 30 })
      expect(result.valid?).to be true
      expect(result.output).to eq({ type: 'user', sub: { name: 'Joe', age: 30 } })

      result = schema.resolve(type: 'company', sub: { name: 'ACME', company_code: 123 })
      expect(result.valid?).to be true
      expect(result.output).to eq({ type: 'company', sub: { name: 'ACME', company_code: '123' } })

      result = schema.resolve(type: 'company', sub: { name: nil, company_code: 123 })
      expect(result.valid?).to be false
      expect(result.errors['$.sub.name']).not_to be_empty

      result = schema.resolve(type: 'foo', sub: { name: 'ACME', company_code: 123 })
      expect(result.valid?).to be false
    end

    it 'can be assigned to instance and reused' do
      user_or_company = Parametric::OneOf.new do |sub|
        sub.on('user', user_schema)
        sub.on('company', company_schema)
      end

      schema = described_class.new do |sc, _|
        sc.field(:type).type(:string)
        sc.field(:sub).type(:object).one_of(user_or_company.index_by(:type))
      end

      result = schema.resolve(type: 'user', sub: { name: 'Joe', age: 30 })
      expect(result.valid?).to be true
      expect(result.output).to eq({ type: 'user', sub: { name: 'Joe', age: 30 } })
    end
  end

  describe "#ignore" do
    it "ignores fields" do
      s1 = described_class.new.ignore(:title, :status) do
        field(:status)
        field(:title).policy(:string).present
        field(:price).policy(:integer)
      end

      output = s1.resolve(status: "draft", title: "foo", price: "100").output
      expect(output).to eq({price: 100})
    end

    it "ignores when merging" do
      s1 = described_class.new do
        field(:status)
        field(:title).policy(:string).present
      end

      s1 = described_class.new.ignore(:title, :status) do
        field(:price).policy(:integer)
      end

      output = s1.resolve(title: "foo", status: "draft", price: "100").output
      expect(output).to eq({price: 100})
    end

    it "returns self so it can be chained" do
      s1 = described_class.new do
        field(:status)
        field(:title).policy(:string).present
      end

      expect(s1.ignore(:status)).to eq s1
    end
  end
end
