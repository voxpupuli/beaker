require 'spec_helper'

class ClassMixedWithDSLStructure
  include Beaker::DSL::TestTagging
  include Beaker::DSL::Helpers::TestHelpers
end

describe ClassMixedWithDSLStructure do
  include Beaker::DSL::Assertions

  let(:logger) { double }
  let(:metadata) { @metadata ||= {} }

  before do
    allow( subject ).to receive(:metadata).and_return(metadata)
  end

  describe '#tag' do
    let( :test_tag_and     ) { @test_tag_and     || [] }
    let( :test_tag_or      ) { @test_tag_or      || [] }
    let( :test_tag_exclude ) { @test_tag_exclude || [] }
    let( :options          ) {
      opts                    = Beaker::Options::OptionsHash.new
      opts[:test_tag_and]     = test_tag_and
      opts[:test_tag_or]      = test_tag_or
      opts[:test_tag_exclude] = test_tag_exclude
      opts
    }

    before do
      allow( subject ).to receive( :platform_specific_tag_confines )
    end

    it 'sets tags on the TestCase\'s metadata object' do
      subject.instance_variable_set(:@options, options)
      tags = ['pants', 'jayjay', 'moguely']
      subject.tag(*tags)
      expect( metadata[:case][:tags] ).to be === tags
    end

    it 'lowercases the tags' do
      subject.instance_variable_set(:@options, options)
      tags_upper = ['pANTs', 'jAYJAy', 'moGUYly']
      tags_lower = tags_upper.map(&:downcase)
      subject.tag(*tags_upper)
      expect( metadata[:case][:tags] ).to be === tags_lower
    end

    it 'skips the test if any of the requested tags isn\'t included in this test' do
      test_tags     = ['pants', 'jayjay', 'moguely']
      @test_tag_and = test_tags.compact.push('needed_tag_not_in_test')
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).to receive( :skip_test )
      subject.tag(*test_tags)
    end

    it 'runs the test if all requested tags are included in this test' do
      @test_tag_and = ['pants_on_head', 'jayjay_jayjay', 'mo']
      test_tags     = @test_tag_and.compact.push('extra_asdf')
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).not_to receive( :skip_test )
      subject.tag(*test_tags)
    end

    it 'skips the test if any of the excluded tags are included in this test' do
      test_tags         = ['ports', 'jay_john_mary', 'mog_the_dog']
      @test_tag_exclude = [test_tags[0]]
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).to receive( :skip_test )
      subject.tag(*test_tags)
    end

    it 'skips the test if an and-included & excluded tag are in this test' do
      test_tags         = ['ports', 'jay_john_mary', 'mog_the_dog']
      @test_tag_and     = [test_tags[1]]
      @test_tag_exclude = [test_tags[0]]
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).to receive( :skip_test )
      subject.tag(*test_tags)
    end

    it 'runs the test if none of the excluded tags are included in this test' do
      @test_tag_exclude = ['pants_on_head', 'jayjay_jayjay', 'mo']
      test_tags         = ['pants_at_head', 'jayj00_jayjay', 'motly_crew']
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).not_to receive( :skip_test )
      subject.tag(*test_tags)
    end

    it 'skips the test if none of the OR tags are included in this test' do
      test_tags = ['portmanteau', 'foolios']
      @test_tag_or = ['fish', 'crayons', 'parkas']
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).to receive( :skip_test )
      subject.tag(*test_tags)
    end

    it 'runs the test if only one of the OR tags are included in this test' do
      test_tags = ['portmanteau', 'foolios']
      @test_tag_or = ['foolios', 'crayons', 'parkas']
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).not_to receive( :skip_test )
      subject.tag(*test_tags)
    end

    it 'skips the test if an or-included & excluded tag are included in this test' do
      test_tags         = ['ports', 'jay_john_mary', 'mog_the_dog']
      @test_tag_or      = [test_tags[1]]
      @test_tag_exclude = [test_tags[0]]
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).to receive( :skip_test )
      subject.tag(*test_tags)
    end
  end
end

describe Beaker::DSL::TestTagging::PlatformTagConfiner do
  let( :confines_array ) { @confines_array || [] }
  let( :confiner ) {
    described_class.new( confines_array )
  }

  describe '#initialize' do
    it 'transforms one entry' do
      platform_regex = /^ubuntu$/
      tag_reason_hash = {
        'tag1' => 'reason1',
        'tag2' => 'reason2'
      }
      @confines_array = [ {
                            :platform => platform_regex,
                            :tag_reason_hash => tag_reason_hash
                          }
      ]

      internal_hash = confiner.instance_variable_get( :@tag_confine_details_hash )
      expect( internal_hash.keys() ).to include( 'tag1' )
      expect( internal_hash.keys() ).to include( 'tag2' )
      expect( internal_hash.keys().length() ).to be === 2

      tag_reason_hash.each do |tag, reason|
        tag_array = internal_hash[tag]
        expect( tag_array.length() ).to be === 1
        tag_hash = tag_array[0]
        expect( tag_hash[:platform_regex] ).to eql( platform_regex )
        expect( tag_hash[:log_message] ).to match( /#{reason}/ )
        expect( tag_hash[:type] ).to be === :except
      end
    end

    it 'deals with the same tag being used on multiple platforms correctly' do
      @confines_array = [
        {
          :platform => /^el-/,
          :tag_reason_hash => {
            'tag1' => 'reason el 1',
            'tag2' => 'reason2'
          }
        }, {
          :platform => /^cisco-/,
          :tag_reason_hash => {
            'tag1' => 'reason cisco 1',
            'tag3' => 'reason3'
          }
        }
      ]

      internal_hash = confiner.instance_variable_get( :@tag_confine_details_hash )
      expect( internal_hash.keys() ).to include( 'tag1' )
      expect( internal_hash.keys() ).to include( 'tag2' )
      expect( internal_hash.keys() ).to include( 'tag3' )
      expect( internal_hash.keys().length() ).to be === 3

      shared_tag_array = internal_hash['tag1']
      expect( shared_tag_array.length() ).to be === 2

      platform_el_found = false
      platform_cisco_found = false
      shared_tag_array.each do |confine_details|
        case confine_details[:log_message]
        when /\ el\ 1/
          platform_el_found = true
          platform_to_match = /^el-/
          reason_to_match = /reason\ el\ 1/
        when /\ cisco\ 1/
          platform_cisco_found = true
          platform_to_match = /^cisco-/
          reason_to_match = /reason\ cisco\ 1/
        else
          log_msg = "unexpected log message for confine_details: "
          log_msg << confine_details[:log_message]
          fail( log_msg )
        end

        expect( confine_details[:platform_regex] ).to eql( platform_to_match )
        expect( confine_details[:log_message] ).to match( reason_to_match )
      end
      expect( platform_el_found ).to be === true
      expect( platform_cisco_found ).to be === true
    end
  end

  describe '#confine_details' do
    it 'returns an empty array if no tags match' do
      fake_confine_details_hash = { 'tag1' => [ {:type => 1}, {:type => 2} ]}
      confiner.instance_variable_set(
        :@tag_confine_details_hash, fake_confine_details_hash
      )
      expect( confiner.confine_details( [ 'tag2', 'tag3' ] ) ).to be === []
    end

    context 'descriminates on tag name' do
      fake_confine_details_hash = {
        'tag0' => [ 10, 20, 30, 40 ],
        'tag1' => [ 41, 51, 61, 71 ],
        'tag2' => [ 22, 32, 42, 52 ],
        'tag3' => [ 63, 73, 83, 93 ],
        'tag4' => [ 34, 44, 54, 64 ],
      }

      key_combos_to_test = fake_confine_details_hash.keys.map { |key| [key] }
      key_combos_to_test << [ 'tag0', 'tag2' ]
      key_combos_to_test << [ 'tag1', 'tag4' ]
      key_combos_to_test << [ 'tag2', 'tag3', 'tag4' ]
      key_combos_to_test << fake_confine_details_hash.keys()

      before do
        confiner.instance_variable_set(
          :@tag_confine_details_hash, fake_confine_details_hash
        )
      end

      key_combos_to_test.each do |key_combo_to_have|
        it "selects key(s) #{key_combo_to_have} from #{fake_confine_details_hash.keys}" do
          haves = []
          key_combo_to_have.each do |key_to_have|
            haves += fake_confine_details_hash[key_to_have]
          end
          keys_not_to_have = fake_confine_details_hash.keys.reject { |key_trial|
            key_combo_to_have.include?( key_trial )
          }
          have_nots = []
          keys_not_to_have.each do |key_not_to_have|
            have_nots += fake_confine_details_hash[key_not_to_have]
          end

          details = confiner.confine_details( key_combo_to_have )
          have_nots.each do |confine_details|
            expect( details ).not_to include( confine_details )
          end
          haves.each do |confine_details|
            expect( details ).to     include( confine_details )
          end
        end
      end
    end
  end
end