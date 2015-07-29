require "spec_helper"

module Beaker
  module Options
    describe PEVersionScraper do
      it "can pull version from local LATEST file" do
        filename = 'LATEST'
        latest = File.open(filename, 'w')
        latest.write('3.7.1-rc0-8-g73f93cb')
        latest.close
        expect(PEVersionScraper.load_pe_version('.', filename)).to be === "3.7.1-rc0-8-g73f93cb"
        File.delete(filename)
      end

      it "can pull version from preview LATEST file" do
        filename = 'LATEST'
        latest = File.open(filename, 'w')
        latest.write('3.8.1')
        latest.close
        expect(PEVersionScraper.load_pe_version('.', filename)).to be === '3.8.1'
        File.delete(filename)
      end

      it "raises error when file doesn't exist" do
        expect{PEVersionScraper.load_pe_version("not a valid path", "not a valid filename")}.to raise_error(ArgumentError)
      end

    end
  end
end
