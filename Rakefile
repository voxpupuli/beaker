
namespace :test do
  desc 'Run specs (with coverage on 1.9), alias :spec & :default'
  task :spec do
    Dir.chdir( File.expand_path(File.dirname(__FILE__)) )
    sh 'export COVERAGE=true; bundle exec rspec'
    Dir.chdir( Rake.application.original_dir )
  end
end

task :spec do
  Rake::Task['test:spec'].invoke
end

task :default => [ 'test:spec' ]

