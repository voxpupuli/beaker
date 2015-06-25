require 'spec_helper'

module Beaker
  module Shared
    describe Semvar do

      describe 'version_is_less' do

        it 'reports 2015.3.0-rc0-8-gf80879a is less than 2016' do
          expect( subject.version_is_less( '2015.3.0-rc0-8-gf80879a', '2016' ) ).to be === true
        end

        it 'reports 2015.3.0-rc0-8-gf80879a is not less than 2015.3.0' do
          expect( subject.version_is_less( '2015.3.0-rc0-8-gf80879a', '2015.3.0' ) ).to be === false
        end

        it 'reports 2015.3.0-rc0-8-gf80879a is not less than 3.0.0' do
          expect( subject.version_is_less( '2015.3.0-rc0-8-gf80879a', '3.0.0' ) ).to be === false
        end

        it 'reports 3.0.0-160-gac44cfb is not less than 3.0.0' do
          expect( subject.version_is_less( '3.0.0-160-gac44cfb', '3.0.0' ) ).to be === false
        end

        it 'reports 3.0.0-160-gac44cfb is not less than 2.8.2' do
          expect( subject.version_is_less( '3.0.0-160-gac44cfb', '2.8.2' ) ).to be === false
        end

        it 'reports 3.0.0 is less than 3.0.0-160-gac44cfb' do
          expect( subject.version_is_less( '3.0.0', '3.0.0-160-gac44cfb' ) ).to be === true
        end

        it 'reports 2.8.2 is less than 3.0.0-160-gac44cfb' do
          expect( subject.version_is_less( '2.8.2', '3.0.0-160-gac44cfb' ) ).to be === true
        end

        it 'reports 2.8 is less than 3.0.0-160-gac44cfb' do
          expect( subject.version_is_less( '2.8', '3.0.0-160-gac44cfb' ) ).to be === true
        end

        it 'reports 2.8 is less than 2.9' do
          expect( subject.version_is_less( '2.8', '2.9' ) ).to be === true
        end
      end
    end

  end
end
