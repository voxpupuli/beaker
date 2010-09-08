mkdir -p /var/yum
deps_path="$( dirname $0 )/deps"
cp -Rf $deps_path/repo /var/yum/
cp $deps_path/local-puppet-spec.repo /etc/yum.repos.d/
yum -d 0 -e 0 makecache
