module BeakerRSpec::Helpers
  include Beaker::DSL

  def hosts
    self.class.hosts
  end
end
