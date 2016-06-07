require 'spec_helper'

describe Parametric do
  it 'should have a version number' do
    expect(Parametric::VERSION).not_to be_nil
  end

  shared_examples 'a configurable params object' do
    it 'ignores undeclared fields' do
      expect(subject.params.has_key?(:foo)).to be_falsey
    end

    it 'sets passed values' do
      expect(subject.params[:per_page]).to eq(20)
    end

    it 'uses defaults if no value passed' do
      expect(subject.params[:page]).to eq(1)
    end

    it 'does not set value if outside of declared options' do
      expect(subject.params[:status]).to eq([])
    end

    it 'does not set value if it does not :match' do
      expect(klass.new(email: 'my@email').params[:email]).to be_nil
    end

    it 'does set value if it does :match' do
      expect(klass.new(email: 'my@email.com').params[:email]).to eq('my@email.com')
    end

    it 'only sets value for :multiple values that :match' do
      expect(klass.new(emails: 'my@email,your,her@email.com').params[:emails]).to eq(['her@email.com'])
    end

    it 'returns :default wrapped in array if :multiple' do
      expect(klass.new().params[:emails]).to eq(['default@email.com'])
    end

    it 'turns :multiple comma-separated values into arrays' do
      expect(klass.new(status: 'one,three').params[:status]).to eq(['one', 'three'])
    end

    it 'does set value if it does :match' do
      expect(klass.new(email: 'my@email.com').params[:email]).to eq('my@email.com')
    end

    it ':multiple values can be arrays' do
      expect(klass.new(status: ['one','three']).params[:status]).to eq(['one', 'three'])
    end

    it 'defaults work for false values' do
      expect(klass.new(email: 'my@email').params[:email]).to be_nil
    end

    it 'does set value if it does :match' do
      expect(klass.new(available: false).params[:available]).to be_falsey
    end

    it 'turns :multiple separated values with custom separator into arrays' do
      expect(klass.new(piped_status: 'one|three').params[:piped_status]).to eq(['one', 'three'])
    end

    it 'does not turn non-multiple comma-separated values into arrays' do
      expect(klass.new(name: 'foo,bar').params[:name]).to eq('foo,bar')
    end

    it 'filters out undeclared options' do
      expect(klass.new(status: 'one,three,fourteen').params[:status]).to eq(['one', 'three'])
    end

    it 'defaults empty multiple options to empty array' do
      expect(klass.new().params[:status]).to eq([])
    end

    it 'wraps single multiple options in array' do
      expect(klass.new(status: 'one').params[:status]).to eq(['one'])
    end

    it 'does not accept comma-separated values outside of options unless :multiple == true' do
      expect(klass.new(country: 'UK,CL').params[:country]).to be_nil
    end

    it 'does accept single option' do
      expect(klass.new(country: 'UK').params[:country]).to eq('UK')
    end

    it 'does not accept single option if not in declared options' do
      expect(klass.new(country: 'USA').params[:country]).to be_nil
    end

    it 'does not include parameters marked as :nullable' do
      expect(klass.new.params.has_key?(:nullable)).to be_falsey
    end
  end

  describe 'TypedParams' do
    let(:klass) do
      Class.new do
        include Parametric::TypedParams
        string :name, 'User name'
        integer :page, 'page number', default: 1
        integer :per_page, 'items per page', default: 50
        array :status, 'status', options: ['one', 'two', 'three']
        array :piped_status, 'status with pipes', separator: '|'
        string :country, 'country', options: ['UK', 'CL', 'JPN']
        string :email, 'email', match: /\w+@\w+\.\w+/
        array :emails, 'emails', match: /\w+@\w+\.\w+/, default: 'default@email.com'
        param :nullable, 'nullable param', nullable: true
      end
    end

    let(:subject) { klass.new(foo: 'bar', per_page: '20', status: 'four') }
    it_should_behave_like 'a configurable params object'

    it 'does not break when value is nil' do
      klass = Class.new do
        include Parametric::TypedParams
        array :friends, 'friends', nullable: true do
          string :name, 'Name'
        end
      end
      expect(klass.new(friends: nil).params[:friends]).to eq([])
      expect(klass.new(friends: []).params[:friends]).to eq([])
      expect(klass.new(friends: [{name: 'foo'}]).params[:friends].first[:name]).to eq('foo')
      expect(klass.new.params.has_key?(:friends)).to be_falsey
    end
  end

  describe Parametric::Params do

    let(:klass) do
      Class.new do
        include Parametric::Params
        param :name, 'User name'
        param :page, 'page number', default: 1, coerce: :to_i
        param :per_page, 'items per page', default: 50, coerce: lambda{|value| value.to_i}
        param :status, 'status', options: ['one', 'two', 'three'], multiple: true
        param :piped_status, 'status with pipes', multiple: true, separator: '|'
        param :country, 'country', options: ['UK', 'CL', 'JPN']
        param :email, 'email', match: /\w+@\w+\.\w+/
        param :emails, 'emails', match: /\w+@\w+\.\w+/, multiple: true, default: 'default@email.com'
        param :available, 'available', default: true
        param :nullable, 'nullable param', nullable: true
      end
    end

    describe '#params' do
      let(:subject) { klass.new(foo: 'bar', per_page: 20, status: 'four') }
      it_should_behave_like 'a configurable params object'
    end

    describe 'subclassing' do
      let(:subclass){ Class.new(klass) }
      let(:subject){ subclass.new(foo: 'bar', per_page: 20, status: 'four') }
      it_should_behave_like 'a configurable params object'
    end

    describe '#available_params' do
      let(:subject) { klass.new(foo: 'bar', name: 'lala', per_page: 20, status: 'four', emails: 'one@email.com,two@email.com') }

      it 'only includes declared params with values or defaults' do
        expect(subject.available_params.keys.sort).to eq([:available, :emails, :name, :page, :per_page])
        expect(subject.available_params[:emails]).to eq(['one@email.com', 'two@email.com'])
        expect(subject.available_params[:name]).to eq('lala')
        expect(subject.available_params[:per_page]).to eq(20)
        expect(subject.available_params[:page]).to eq(1)
      end

      describe ':coerce option' do
        it 'accepts method_name as a symbol' do
          expect(klass.new(page: '10').available_params[:page]).to eq(10)
        end

        it 'accepts a proc' do
          expect(klass.new(per_page: '10').available_params[:per_page]).to eq(10)
        end
      end

      describe '#flat' do
        it 'joins values back' do
          expect(subject.available_params.flat[:emails]).to eq('one@email.com,two@email.com')
        end
      end
    end

    describe '#schema' do
      let(:subject) { klass.new(foo: 'bar', name: 'lala', per_page: 20, status: 'four') }

      it 'returns full param definitions with populated value' do
        regexp = /\w+@\w+\.\w+/

        expect(subject.schema[:name].label).to eq('User name')
        expect(subject.schema[:name].value).to eq('lala')

        expect(subject.schema[:page].label).to eq('page number')
        expect(subject.schema[:page].value).to eq(1)

        expect(subject.schema[:per_page].label).to eq('items per page')
        expect(subject.schema[:per_page].value).to eq(20)

        expect(subject.schema[:status].label).to eq('status')
        expect(subject.schema[:status].value).to eq('')
        expect(subject.schema[:status].options).to eq(['one', 'two', 'three'])
        expect(subject.schema[:status].multiple).to be_truthy

        expect(subject.schema[:piped_status].label).to eq('status with pipes')
        expect(subject.schema[:piped_status].value).to eq('')
        expect(subject.schema[:piped_status].multiple).to be_truthy

        expect(subject.schema[:country].label).to eq('country')
        expect(subject.schema[:country].value).to eq('')
        expect(subject.schema[:country].options).to eq(['UK', 'CL', 'JPN'])

        expect(subject.schema[:email].label).to eq('email')
        expect(subject.schema[:email].value).to eq('')
        expect(subject.schema[:email].match).to eq(regexp)

        expect(subject.schema[:emails].label).to eq('emails')
        expect(subject.schema[:emails].value).to eq('default@email.com')
        expect(subject.schema[:emails].multiple).to be_truthy
        expect(subject.schema[:emails].match).to eq(regexp)
      end
    end
  end

  describe Parametric::Hash do
    let(:klass) do
      Class.new(Parametric::Hash) do
        string :name, 'User name'
        integer :page, 'page number', default: 1
        param :per_page, 'items per page', default: 50
      end
    end

    let(:subject) { klass.new(name: 'Ismael', page: 2) }

    it 'quacks like a hash' do
      expect(subject[:name]).to eq('Ismael')
      expect(subject[:page]).to eq(2)
      expect(subject[:per_page]).to eq(50)
      expect(subject.map{|k,v| k}.sort).to eq([:name, :page, :per_page])
      expect(subject.keys.sort).to eq([:name, :page, :per_page])
      expect(subject.values.map(&:to_s).sort).to eq(['2', '50', 'Ismael'])
      expect(subject.fetch(:page, 0)).to eq(2)
      expect(subject.fetch(:foo, 0)).to eq(0)
      expect(subject.merge(foo: 22)).to eq({name: 'Ismael', page: 2, per_page: 50, foo: 22})
      expect(subject.select{|k,v| k == :name}).to eq({name: 'Ismael'})
    end

    it 'has #available_params' do
      expect(subject.available_params[:name]).to eq('Ismael')
    end

    it 'has #schema' do
      expect(subject.schema[:name].label).to eq('User name')
      expect(subject.schema[:name].value).to eq('Ismael')
    end
  end
end
