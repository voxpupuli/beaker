require "spec_helper"

# safely set values for ARGV in block, restoring original value on block leave
def with_ARGV(value, &block)
  if defined? ARGV
    defined_ARGV, old_ARGV = true, ARGV
    Object.send(:remove_const, :ARGV)
  else
    defined_ARGV, old_ARGV = false, nil
  end

  Object.send(:const_set, :ARGV, value)

  yield
ensure
  Object.send(:remove_const, :ARGV)
  Object.send(:const_set, :ARGV, old_ARGV) if defined_ARGV
end

describe "Beaker Options" do
  let (:parser) { Beaker::Options::Parser.new }

  it "defaults :runner to 'native'" do
    with_ARGV([]) do
      expect(parser.parse_args[:runner]).to be == "native"
    end
  end

  it "accepts :runner from command-line" do
    with_ARGV(["--runner", "minitest"]) do
      expect(parser.parse_args[:runner]).to be == "minitest"
    end
  end
end
