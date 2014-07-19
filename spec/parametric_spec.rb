require 'spec_helper'

describe Parametric do
  it 'should have a version number' do
    Parametric::VERSION.should_not be_nil
  end

  shared_examples 'a configurable params object' do
    it 'ignores undeclared fields' do
      subject.params.has_key?(:foo).should be_false
    end

    it 'sets passed values' do
      subject.params[:per_page].should == 20
    end

    it 'uses defaults if no value passed' do
      subject.params[:page].should == 1
    end

    it 'does not set value if outside of declared options' do
      subject.params[:status].should == []
    end

    it 'does not set value if it does not :match' do
      klass.new(email: 'my@email').params[:email].should be_nil
    end

    it 'does set value if it does :match' do
      klass.new(email: 'my@email.com').params[:email].should == 'my@email.com'
    end

    it 'only sets value for :multiple values that :match' do
      klass.new(emails: 'my@email,your,her@email.com').params[:emails].should == ['her@email.com']
    end

    it 'returns :default wrapped in array if :multiple' do
      klass.new().params[:emails].should == ['default@email.com']
    end

    it 'turns :multiple comma-separated values into arrays' do
      klass.new(status: 'one,three').params[:status].should == ['one', 'three']
    end

    it 'does set value if it does :match' do
      klass.new(email: 'my@email.com').params[:email].should == 'my@email.com'
    end

    it ':multiple values can be arrays' do
      klass.new(status: ['one','three']).params[:status].should == ['one', 'three']
    end

    it 'defaults work for false values' do
      klass.new(email: 'my@email').params[:email].should be_nil
    end

    it 'does set value if it does :match' do
      klass.new(available: false).params[:available].should be_false
    end

    it 'turns :multiple separated values with custom separator into arrays' do
      klass.new(piped_status: 'one|three').params[:piped_status].should == ['one', 'three']
    end

    it 'does not turn non-multiple comma-separated values into arrays' do
      klass.new(name: 'foo,bar').params[:name].should == 'foo,bar'
    end

    it 'filters out undeclared options' do
      klass.new(status: 'one,three,fourteen').params[:status].should == ['one', 'three']
    end

    it 'defaults empty multiple options to empty array' do
      klass.new().params[:status].should == []
    end

    it 'wraps single multiple options in array' do
      klass.new(status: 'one').params[:status].should == ['one']
    end

    it 'does not accept comma-separated values outside of options unless :multiple == true' do
      klass.new(country: 'UK,CL').params[:country].should be_nil
    end

    it 'does accept single option' do
      klass.new(country: 'UK').params[:country].should == 'UK'
    end

    it 'does not accept single option if not in declared options' do
      klass.new(country: 'USA').params[:country].should be_nil
    end

    it 'accepts value if validator returns true' do
      klass.new(even_number: 2).params[:even_number].should == 2
    end

    it 'does not accept value if validator returns false' do
      klass.new(even_number: 3).params[:even_number].should == nil
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
        integer :even_number, 'even number', validator: ->(n) { n.even? }
      end
    end

    let(:subject) { klass.new(foo: 'bar', per_page: '20', status: 'four') }
    it_should_behave_like 'a configurable params object'
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
        param :even_number, 'even number', validator: ->(n) { n.even? }
      end
    end

    describe '#params' do
      let(:subject) { klass.new(foo: 'bar', per_page: 20, status: 'four') }
      it_should_behave_like 'a configurable params object'
    end

    describe '#available_params' do
      let(:subject) { klass.new(foo: 'bar', name: 'lala', per_page: 20, status: 'four', emails: 'one@email.com,two@email.com') }

      it 'only includes declared params with values or defaults' do
        subject.available_params.keys.sort.should == [:available, :emails, :name, :page, :per_page]
        subject.available_params[:emails].should == ['one@email.com', 'two@email.com']
        subject.available_params[:name].should == 'lala'
        subject.available_params[:per_page].should == 20
        subject.available_params[:page].should == 1
      end

      describe ':coerce option' do
        it 'accepts method_name as a symbol' do
          klass.new(page: '10').available_params[:page].should == 10
        end

        it 'accepts a proc' do
          klass.new(per_page: '10').available_params[:per_page].should == 10
        end
      end

      describe '#flat' do
        it 'joins values back' do
          subject.available_params.flat[:emails].should == 'one@email.com,two@email.com'
        end
      end
    end

    describe '#schema' do
      let(:subject) { klass.new(foo: 'bar', name: 'lala', per_page: 20, status: 'four') }

      it 'returns full param definitions with populated value' do
        regexp = /\w+@\w+\.\w+/

        subject.schema[:name].label.should == 'User name'
        subject.schema[:name].value.should == 'lala'

        subject.schema[:page].label.should == 'page number'
        subject.schema[:page].value.should == 1

        subject.schema[:per_page].label.should == 'items per page'
        subject.schema[:per_page].value.should == 20

        subject.schema[:status].label.should == 'status'
        subject.schema[:status].value.should == ''
        subject.schema[:status].options.should == ['one', 'two', 'three']
        subject.schema[:status].multiple.should be_true

        subject.schema[:piped_status].label.should == 'status with pipes'
        subject.schema[:piped_status].value.should == ''
        subject.schema[:piped_status].multiple.should be_true

        subject.schema[:country].label.should == 'country'
        subject.schema[:country].value.should == ''
        subject.schema[:country].options.should == ['UK', 'CL', 'JPN']

        subject.schema[:email].label.should == 'email'
        subject.schema[:email].value.should == ''
        subject.schema[:email].match.should == regexp

        subject.schema[:emails].label.should == 'emails'
        subject.schema[:emails].value.should == 'default@email.com'
        subject.schema[:emails].multiple.should be_true
        subject.schema[:emails].match.should == regexp

        subject.schema[:even_number].label.should == 'even number'
        subject.schema[:even_number].value.should == ''
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
      subject[:name].should == 'Ismael'
      subject[:page].should == 2
      subject[:per_page].should == 50
      subject.map{|k,v| k}.sort.should == [:name, :page, :per_page]
      subject.keys.sort.should == [:name, :page, :per_page]
      subject.values.map(&:to_s).sort.should == ['2', '50', 'Ismael']
      subject.fetch(:page, 0).should == 2
      subject.fetch(:foo, 0).should == 0
      subject.merge(foo: 22).should == {name: 'Ismael', page: 2, per_page: 50, foo: 22}
      subject.select{|k,v| k == :name}.should == {name: 'Ismael'}
    end

    it 'has #available_params' do
      subject.available_params[:name].should == 'Ismael'
    end

    it 'has #schema' do
      subject.schema[:name].label.should == 'User name'
      subject.schema[:name].value.should == 'Ismael'
    end
  end
end
