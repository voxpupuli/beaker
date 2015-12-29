require 'spec_helper'

module Beaker
  module Options

    describe Validator do
      let(:validator) { Validator.new }

      describe '#check_yaml_file' do
        let(:bad_yaml_path) { File.join(File.expand_path(File.dirname(__FILE__)), 'data', 'badyaml.cfg') }
        let(:yaml_path) { File.join(File.expand_path(File.dirname(__FILE__)), 'data', 'hosts.cfg') }

        before :each do
          FakeFS.deactivate!
        end

        it 'raises error on improperly formatted yaml file' do
          expect { validator.check_yaml_file(bad_yaml_path) }.to raise_error(ArgumentError)
        end

        it 'raises an error when a yaml file is missing' do
          expect { validator.check_yaml_file('not a path') }.to raise_error(ArgumentError)
        end

        it 'does not throw errors on valid yaml files' do
          expect { validator.check_yaml_file(yaml_path) }.not_to raise_error
        end
      end

      describe '#resolve_symlinks' do
        let(:options_path) { File.join(File.expand_path(File.dirname(__FILE__)), 'data', 'opts.txt') }
        let(:options) { Beaker::Options::OptionsHash.new }

        before :each do
          FakeFS.deactivate!
        end

        it 'calls File.realpath if hosts_file is set' do
          options[:hosts_file] = options_path
          validator.resolve_symlinks(options)
          expect(options[:hosts_file]).to eq(options_path)
        end

        it 'does not raise an error if nil' do
          options[:hosts_file] = nil
          validator.resolve_symlinks(options)
          expect(options[:hosts_file]).to be_nil
        end

      end

      describe '#validator_error' do
        it 'raises error with message' do
          expect { validator.validator_error('test error') }.to raise_error(ArgumentError, 'test error')
        end
      end

      describe '#default_set?' do
        it 'is false when empty' do
          expect(validator.default_set?([])).to be_falsey
        end

        it 'throws error when more than 1' do
          expect { validator.default_set?([1, 2]) }.to raise_error(ArgumentError)
        end

        ['test', 1, 3.4, true, Object.new].each do |val|
          it "is true when contents are #{val.class}" do
            expect(validator.default_set?([val])).to be_truthy
          end
        end
      end

      describe '#valid_fail_mode?' do
        %w(stop fast slow).each do |val|
          it "does not throw error when set to #{val}" do
            expect { validator.valid_fail_mode?(val) }.not_to raise_error
          end

          it "raises error when set to #{val.upcase}" do
            expect { validator.valid_fail_mode?(val.upcase) }.to raise_error
          end

          it "raises error when set to #{val.capitalize}" do
            expect { validator.valid_fail_mode?(val.capitalize) }.to raise_error
          end
        end

        ['test', 1, true, Object.new].each do |val|
          it 'raises error with invalid mode' do
            expect { validator.valid_fail_mode?(val) }.to raise_error
          end
        end
      end

      describe '#valid_preserve_hosts?' do
        %w(always onfail onpass never).each do |val|
          it "does not raise error when set to #{val}" do
            expect { validator.valid_preserve_hosts?(val) }.not_to raise_error
          end

          it "raises error when set to #{val.upcase}" do
            expect { validator.valid_preserve_hosts?(val.upcase) }.to raise_error
          end

          it "raises error when set to #{val.capitalize}" do
            expect { validator.valid_preserve_hosts?(val.capitalize) }.to raise_error
          end
        end

        ['test', 1, true, Object.new].each do |val|
          it 'raises error with invalid setting' do
            expect { validator.valid_preserve_hosts?(val) }.to raise_error
          end
        end
      end

      describe '#validate_tags' do
        it 'does error if tags overlap' do
          tag_includes = %w(can tommies should_error potatoes plant)
          tag_excludes = %w(joey long_running pants should_error)

          expect { validator.validate_tags(tag_includes, tag_excludes) }.to raise_error(ArgumentError)
        end

        it 'does not raise an error if tags do not overlap' do
          tag_includes = %w(horse dog cat)
          tag_excludes = %w(car truck train)

          expect { validator.validate_tags(tag_includes, tag_excludes) }.not_to raise_error
        end

      end

    end

  end
end
