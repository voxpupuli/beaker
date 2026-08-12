require 'spec_helper'

module Beaker
  describe Result do
    subject(:result) { described_class.new(host, cmd) }

    let(:host) { 'my_host' }
    let(:cmd)  { 'ls -la' }

    # Command output reaches a Result the way net-ssh hands it over: as chunks
    # of binary data, appended as they arrive.
    def binary(string)
      string.dup.force_encoding('ASCII-8BIT')
    end

    describe '#initialize' do
      it 'starts with empty streams and no exit code' do
        expect(result.stdout).to eq('')
        expect(result.stderr).to eq('')
        expect(result.output).to eq('')
        expect(result.exit_code).to be_nil
      end
    end

    describe '#convert' do
      let(:valid_utf8) { "modules\n├── jimmy-appleseed (v1.1.0)\n└── jimmy-crakorn (v0.4.0)\n" }

      it 'preserves valid utf-8' do
        expect(result.convert(valid_utf8.dup)).to eq(valid_utf8)
      end

      it 'strips invalid utf-8 byte sequences' do
        expect(result.convert(binary("ok\xFFbad"))).to eq('okbad')
      end

      it 'strips a truncated multi-byte sequence' do
        expect(result.convert(binary("ok\xE3\x81"))).to eq('ok')
      end

      it 'returns utf-8 whatever encoding it was handed' do
        expect(result.convert(binary('plain')).encoding).to eq(Encoding::UTF_8)
      end

      it 'modifies the argument encoding in place' do
        string = binary('plain')
        result.convert(string)
        expect(string.encoding).to eq(Encoding::UTF_8)
      end

      it 'returns a new string rather than scrubbing the one it was given' do
        string = binary("ok\xFFbad")
        expect(result.convert(string)).not_to equal(string)
        expect(string.bytes).to include(0xFF)
      end

      context 'when handed String subclass' do
        let(:string_subclass) { Class.new(String) }

        it 'accepts String subclass' do
          expect(result.convert(string_subclass.new('plain'))).to eq('plain')
        end

        it 'leaves invalid encodings in place, as it always has' do
          subclass = string_subclass.new(binary("ok\xFFbad"))
          expect(result.convert(subclass).bytes).to include(0xFF)
        end

        it 'converts anything else that can describe itself' do
          expect(result.convert(5)).to eq('5')
        end

        it 'raises FrozenError on nil' do
          expect { result.convert(nil) }.to raise_error(FrozenError, /modify frozen String: ""/)
        end
      end
    end

    describe '#normalize_line_endings' do
      it 'converts crlf to lf' do
        expect(result.normalize_line_endings("a\r\nb")).to eq("a\nb")
      end

      it 'converts a lone cr to lf' do
        expect(result.normalize_line_endings("a\rb")).to eq("a\nb")
      end

      it 'leaves lf alone' do
        expect(result.normalize_line_endings("a\nb")).to eq("a\nb")
      end
    end

    describe '#finalize!' do
      before do
        result.stdout << binary("out\xFF\r\n")
        result.stderr << binary("err\xFF\r\n")
        result.output << binary("out\xFF\r\nerr\xFF\r\n")
        result.finalize!
      end

      it 'scrubs and normalizes every stream' do
        expect(result.stdout).to eq("out\n")
        expect(result.stderr).to eq("err\n")
        expect(result.output).to eq("out\nerr\n")
      end

      it 'keeps the unscrubbed bytes in the raw_ attributes' do
        expect(result.raw_stdout.bytes).to include(0xFF)
        expect(result.raw_stderr.bytes).to include(0xFF)
        expect(result.raw_output.bytes).to include(0xFF)
      end

      it 'leaves the raw_ line endings alone' do
        expect(result.raw_stdout).to include("\r\n")
      end
    end

    describe '#formatted_output' do
      before do
        result.output << (1..15).map { |i| "line #{i}" }.join("\n")
      end

      it 'returns the last ten lines by default, tab indented' do
        expect(result.formatted_output).to eq((6..15).map { |i| "\tline #{i}" }.join("\n"))
      end

      it 'honours a limit' do
        expect(result.formatted_output(2)).to eq("\tline 14\n\tline 15")
      end
    end

    describe '#exit_code_in?' do
      it 'is true when the exit code is in the range' do
        result.exit_code = 2
        expect(result.exit_code_in?([0, 2])).to be true
      end

      it 'is false when it is not' do
        result.exit_code = 1
        expect(result.exit_code_in?([0, 2])).to be false
      end
    end

    describe '#success?' do
      it 'is true only for an exit code of zero' do
        result.exit_code = 0
        expect(result).to be_success
      end

      it 'is false for a non-zero exit code' do
        result.exit_code = 1
        expect(result).not_to be_success
      end

      it 'is false when no exit code was collected' do
        expect(result).not_to be_success
      end
    end

    describe '#log' do
      let(:logger) { instance_double(Beaker::Logger) }

      it 'reports a non-zero exit code' do
        result.exit_code = 1
        expect(logger).to receive(:debug).with('Exited: 1')
        result.log(logger)
      end

      it 'says nothing for a successful command' do
        result.exit_code = 0
        expect(logger).not_to receive(:debug)
        result.log(logger)
      end

      it 'says nothing when no exit code was collected' do
        expect(logger).not_to receive(:debug)
        result.log(logger)
      end
    end
  end

  describe NullResult do
    subject(:result) { described_class.new('my_host', 'ls -la') }

    it 'succeeds without having run anything' do
      expect(result.exit_code).to eq(0)
      expect(result).to be_success
    end
  end
end
