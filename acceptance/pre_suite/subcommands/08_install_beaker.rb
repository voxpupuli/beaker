test_name 'Install beaker and checkout branch if necessary' do

  step 'Download the beaker git repo' do
   on default, 'git clone https://github.com/puppetlabs/beaker.git /opt/beaker/'
  end

  step 'Detect if checking out branch for testing and checkout' do
    if ENV['BEAKER_PULL_ID']
      logger.notify "Pull Request detected, checking out PR branch"
      on(default, 'cd /opt/beaker/;git -c core.askpass=true fetch --tags --progress https://github.com/puppetlabs/beaker.git +refs/pull/*:refs/remotes/origin/pr/*')
      on(default, "cd /opt/beaker/;git merge origin/pr/#{ENV['BEAKER_PULL_ID']}/head --no-edit")
    else
      logger.notify 'No PR branch detected, building from master'
    end
  end

  step 'Build the gem and install it on the local system' do
    build_output = on(default, 'cd /opt/beaker/;gem build beaker.gemspec').stdout
    version = build_output.match(/^  File: (.+)$/)[1]
    on(default, "cd /opt/beaker/;gem install #{version} --no-document; gem install beaker-vmpooler")
  end
end
