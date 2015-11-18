ENV['RACK_ENV'] = 'test'

require "#{File.dirname(__FILE__)}/../spec_helper"
require_relative '../../bookstore.rb'
require 'rspec'
require 'pry'
require 'rack/test'

describe 'main application' do
    include Rack::Test::Methods

    def app
        #Sinatra::Application
        @app = Bookstore
    end

    before do
      allow(CasHelpers).to receive(:need_authentication).and_return(:false)
    end

    describe 'instantiate app' do
        it 'Should redirect to CAS Login' do
            allow(CasHelpers).to receive(:need_authentication).and_return(:true)
            get '/'
            expect(last_response.location).to be == "https://websso.wwu.edu/cas/login?service=http%3A%2F%2Fexample.org%2F"
        end

    end
end
