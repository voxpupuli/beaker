# Jeff McCune <jeff@puppetlabs.com>
# 2010-07-31
#
# AffectedVersion: 2.6.0, 2.6.1rc1
# FixedVersion:
#
# Make sure two parameterized classes are able to be declared.

test_name "#4423: cannot declare two parameterized classes"

class1='class rainbow($color) {
  notify { "color": message => "Color is [${color}]" }
}
class { "rainbow": color => "green" }'

class2='class planet($moons) {
  notify { "planet": message => "Moons are [${moons}]" }
}
class { "planet": moons => "1" }'

step "Declaring one parameterized class works just fine"
run_manifest agents, class1

step "Make sure we try both classes stand-alone"
run_manifest agents, class2

step "Putting both classes in the same manifest should work."
run_manifest agents, "#{class1}\n\n#{class2}"

step "Putting both classes in the same manifest should work."
run_manifest agents, <<MANIFEST3
class rainbow($color) {
  notify { "color": message => "Color is [${color}]" }
}
class { "rainbow": color => "green" }

class planet($moons) {
  notify { "planet": message => "Moons are [${moons}]" }
}
class { "planet": moons => "1" }

class rainbow::location($prism=false, $water=true) {
  notify { "${name}":
    message => "prism:[${prism}] water:[${water}]";
  }
}
class { "rainbow::location": prism => true, water => false; }

class rainbow::type($pretty=true, $ugly=false) {
  notify { "${name}":
    message => "pretty:[${pretty}] ugly:[${ugly}]";
  }
}
class { "rainbow::type": pretty => false, ugly => true; }
MANIFEST3
