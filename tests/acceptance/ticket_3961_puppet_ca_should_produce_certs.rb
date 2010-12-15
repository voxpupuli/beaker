test_name "#3961: puppet ca should produce certs spec"

scratch = "/tmp/puppet-ssl-#3961"
target  = "working3961.example.org"

args = ["conf", "var", "ssl"].map { |s| "--#{s}dir=#{scratch}" } .join " "

expect = ['notice: Signed certificate request for ca',
          'notice: Rebuilding inventory file',
          'notice: working3961.example.org has a waiting certificate request',
          'notice: Signed certificate request for working3961.example.org',
          'notice: Removing file Puppet::SSL::CertificateRequest working3961.example.org']


step "removing the SSL scratch directory..."
on agents, "rm -rf #{scratch}"
step "generate a certificate in #{scratch}"
puppet(agents, :cert, '--trace', '--generate', target, *args) do
  exit_code == 0 or fail_test("puppet cert returned a non-zero exit code")

  expect.each do |line|
    stdout.index(line) or fail_test("missing line in output: #{line}")
  end
end

step "verify the certificate for #{target} exists"
on agents, "test -f #{scratch}/certs/#{target}.pem"

step "verify the private key for #{target} exists"
on agents, "grep -q 'BEGIN RSA PRIVATE KEY' #{scratch}/private_keys/#{target}.pem"
