require 'spec_helper'


module MixedWith
  module DSL
    class Roles
      include PuppetAcceptance::DSL::Roles
    end
  end
end

describe MixedWith::DSL::Roles do
  it('should blow up') { subject }
end
