require 'spec_helper'

describe Parametric do

  describe Parametric::Params do

    let(:klass) do
      Class.new do
        include Parametric::Params
        param :name, 'User name'
        param :tags, 'Tags', multiple: true, default: 'defaulttag'
        param :lala, 'Lala' do
          param :foo, 'foo'
        end
        param :account, 'Account' do
          param :name, 'Account name'
          param :admin, 'Admin user' do
            param :name, 'User name'
          end
          param :shop, 'Shop' do
            param :url, 'Shop url', default: 'http://google.com'
          end
        end
        param :variants, 'Product variants', multiple: true do
          param :name, 'variant name', default: 'default'
          param :price
          param :tags, 'Variant tags', multiple: true
        end
      end
    end

    let(:subject) do
      klass.new({
        foo: 'bar',
        name: 'user1',
        account: {
          name: 'account1',
          lala: 1,
          admin: {
            name: 'Joe Bloggs'
          }
        },
        variants: [
          {name: 'red', price: 10},
          {price: 11, tags: 'foo,bar'}
        ]
      })
    end

    describe '#params' do
      it 'filters nested objects' do
        expect(subject.params.has_key?(:foo)).to be_false
        expect(subject.params[:name]).to eql('user1')
        expect(subject.params[:account][:name]).to eql('account1')
        expect(subject.params[:account].has_key?(:lala)).to be_false
        expect(subject.params[:account][:admin][:name]).to eql('Joe Bloggs')
      end

      it 'nullifies nested objects that were not passed' do
        expect(subject.params[:account].has_key?(:shop)).to be_true
        expect(subject.params[:account][:shop]).to be_nil
      end
      
      it 'filters nested :multiple into arrays of objects' do
        expect(subject.params[:variants].size).to eql(2)
        expect(subject.params[:variants][0][:name]).to eql('red')
        expect(subject.params[:variants][0][:price]).to eql(10)
        expect(subject.params[:variants][0][:tags]).to match_array([])
        expect(subject.params[:variants][1][:name]).to eql('default')
        expect(subject.params[:variants][1][:price]).to eql(11)
        expect(subject.params[:variants][1][:tags]).to match_array(['foo', 'bar'])
      end
    end

    describe '#available_params' do
      it 'does not include key for nested objects that were not passed' do
        expect(subject.available_params.has_key?(:lala)).to be_false
        expect(subject.available_params[:account].has_key?(:shop)).to be_false
      end
    end

    describe '#schema' do
      it 'includes nested param schemas' do
        expect(subject.schema[:account].schema[:name].value).to eql('account1')
        expect(subject.schema[:account].schema[:name].label).to eql('Account name')
        expect(subject.schema[:account].schema[:admin].schema[:name].value).to eql('Joe Bloggs')
      end
    end
  end
end