require "spec_helper"

module Beaker
  module Options
    describe PEVersionScraper do
      it "can pull version from local LATEST file" do
        expect(PEVersionScraper.load_pe_version(File.expand_path(File.dirname(__FILE__)), "data/LATEST")) === '3.0.0'
      end
      it "raises error when file doesn't exist" do
        expect{PEVersionScraper.load_pe_version("not a valid path", "not a valid filename")}.to raise_error(ArgumentError)
      end

    end
  end
end
