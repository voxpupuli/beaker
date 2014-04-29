require "bundler"
Bundler.setup

require 'rake'
require 'beaker/tasks/rake_task'

desc 'Run Beaker PE Tests'
namespace :beaker do
  namespace :test do
    desc "Run Beaker PE Tests"
    Beaker::Tasks::RakeTask.new(:pe) do |t, args|
      t.type = "pe"
    end

    desc "Run Beaker Git Tests"
    Beaker::Tasks::RakeTask.new(:git) do |t, args|
      t.type = "git"
    end
  end
end
