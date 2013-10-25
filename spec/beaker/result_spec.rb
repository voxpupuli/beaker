require 'spec_helper'

describe Beaker::Result do
  subject do
    Beaker::Result.new('host','ls')
  end

  describe '#formatted_output'
  describe '#convert'

  describe "return output values" do
    it 'have no final line ending' do
      subject.stdout = "RedHat\n"
      subject.stderr = "Some error!\n"
      subject.finalize!

      expect(subject.stdout).to eq("RedHat")
      expect(subject.stderr).to eq("Some error!")
    end
    it 'maintain intermediate line endings' do
      subject.stdout = "operatingsystem => CentOS\nosfamily => RedHat\n"
      subject.stderr = "Danger!\nDanger Will Robinson!\n"
      subject.finalize!

      expect(subject.stdout).to eq("operatingsystem => CentOS\nosfamily => RedHat")
      expect(subject.stderr).to eq("Danger!\nDanger Will Robinson!")
    end
    it 'convert \r and CRLF to newline' do
      subject.stdout = "operatingsystem => CentOS\r\nosfamily => RedHat\n"
      subject.stderr = "Danger!\rDanger Will Robinson!\n"
      subject.finalize!

      expect(subject.stdout).to eq("operatingsystem => CentOS\nosfamily => RedHat")
      expect(subject.stderr).to eq("Danger!\nDanger Will Robinson!")
    end
  end
end
