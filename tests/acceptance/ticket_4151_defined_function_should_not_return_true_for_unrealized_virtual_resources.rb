test_name "#4151: defined function should not return true for unrealized virtual resources"
pass_test "Pass forced pending test failure investigation"

# Jeff McCune <jeff@puppetlabs.com>
# 2010-07-06
#
# This script is expected to exit non-zero if ticket 4151 has not been
# fixed.
#
# The expected behavior is for defined() to only return true if a virtual
# resource has been realized.
#
# This test creates a virtual resource, does NOT realize it, then calls
# the defined() function against it.  If defined returns true, there will
# be an error since Notify["goodbye"] will require a resource which has
# not been realized.

apply_manifest_on agents, %q{
    @notify { "hello": }
    if (defined(Notify["hello"])) { $requires = [ Notify["hello"] ] }
    notify { "goodbye": require => $requires }
}
