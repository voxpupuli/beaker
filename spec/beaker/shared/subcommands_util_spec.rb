require 'spec_helper'

module Beaker
  module Shared
    describe SubcommandsUtil do

      let(:cli) {
        double("cli")
      }

      describe 'reset_argv' do
        it "resets argv" do
          args = ["test1", "test2"]
          expect(ARGV).to receive(:clear).exactly(1).times
          subject.reset_argv(args)
          expect(ARGV[0]).to eq(args[0])
          expect(ARGV[1]).to eq(args[1])
        end
      end

      describe 'execute_beaker' do
        it "executes beaker with arguments" do
          allow(cli).to receive(:execute!).and_return(true)
          allow(Beaker::CLI).to receive(:new).and_return(cli)
          expect(subject).to receive(:reset_argv).exactly(1).times
          expect(cli).to receive(:execute!).exactly(1).times
          subject.execute_beaker(['args'])
        end
      end

    end
  end
end
