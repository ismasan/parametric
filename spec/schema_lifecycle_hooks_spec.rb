require 'spec_helper'

describe Parametric::Schema do
  describe '#before_resolve' do
    it 'passes payload through before_resolve block, if defined' do
      schema = described_class.new do
        before_resolve do |payload, _context|
          payload[:slug] = payload[:name].to_s.downcase.gsub(/\s+/, '-') unless payload[:slug]
          payload
        end

        field(:name).policy(:string).present
        field(:slug).policy(:string).present
        field(:variants).policy(:array).schema do
          before_resolve do |payload, _context|
            payload[:slug] = "v: #{payload[:name].to_s.downcase}"
            payload
          end
          field(:name).policy(:string).present
          field(:slug).type(:string).present
        end
      end

      result = schema.resolve({ name: 'A name', variants: [{ name: 'A variant' }] })
      expect(result.valid?).to be true
      expect(result.output[:slug]).to eq 'a-name'
      expect(result.output[:variants].first[:slug]).to eq 'v: a variant'
    end

    it 'collects errors added in before_resolve blocks' do
      schema = described_class.new do
        field(:variants).type(:array).schema do
          before_resolve do |payload, context|
            context.add_error 'nope!' if payload[:name] == 'with errors'
            payload
          end
          field(:name).type(:string)
        end
      end

      results = schema.resolve({ variants: [ {name: 'no errors'}, {name: 'with errors'}]})
      expect(results.valid?).to be false
      expect(results.errors['$.variants[1]']).to eq ['nope!']
    end

    it 'copies before_resolve hooks to merged schemas' do
      schema1 = described_class.new do
        before_resolve do |payload, _context|
          payload[:slug] = payload[:name].to_s.downcase.gsub(/\s+/, '-') unless payload[:slug]
          payload
        end
        field(:name).present.type(:string)
        field(:slug).present.type(:string)
      end

      schema2 = described_class.new do
        before_resolve do |payload, _context|
          payload[:slug] = "slug-#{payload[:slug]}" if payload[:slug]
          payload
        end

        field(:age).type(:integer)
      end

      schema3 = schema1.merge(schema2)

      results = schema3.resolve({ name: 'Ismael Celis', age: 41 })
      expect(results.output[:slug]).to eq 'slug-ismael-celis'
    end

    it 'works with any callable' do
      slug_maker = Class.new do
        def initialize(slug_field, from:)
          @slug_field, @from = slug_field, from
        end

        def call(payload, _context)
          payload.merge(
            @slug_field => payload[@from].to_s.downcase.gsub(/\s+/, '-')
          )
        end
      end

      schema = described_class.new do |sc, _opts|
        sc.before_resolve slug_maker.new(:slug, from: :name)

        sc.field(:name).type(:string)
        sc.field(:slug).type(:string)
      end

      results = schema.resolve(name: 'Ismael Celis')
      expect(results.output[:slug]).to eq 'ismael-celis'
    end
  end
end
