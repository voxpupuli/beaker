By default Beaker connects to hosts using public key authentication, but that may not be correct method for your particular testing set up.  To have beaker connect to a host using a username/password combination edit your hosts configuration file.  You will need to create a new ssh hash to be used for logging into your SUT that includes (at least) entries for _user_, _password_, and _auth_method_.  You may also include any additional supported [Net::SSH Options](http://net-ssh.github.io/ssh/v1/chapter-2.html#s3).

## Example 1: Use 'password' authentication
```
HOSTS:
  pe-centos6:
    roles:
      - master
      - agent
      - dashboard
      - database
      - myrole
    platform: el-6-i386
    snapshot : clean-w-keys
    hypervisor : fusion
    ssh:
      password : anode
      user: anode
      auth_methods:
        - password
```

The log will then read as:

_snip_
```
pe-centos6 20:19:16$ echo hello!
Attempting ssh connection to pe-centos6, user: anode, opts: {:config=>false, :paranoid=>false, :timeout=>300, :auth_methods=>["password"], :port=>22, :forward_agent=>true, :keys=>["/Users/anode/.ssh/id_rsa"], :user_known_hosts_file=>"/Users/anode/.ssh/known_hosts", :password=>"anode", :user=>"anode"}
```
_/snip_

## Example 2: Use a list of authentication methods
If you want to try a sequence of authentication techniques that fall through on failure simply include them (in their desired order) in your list of _auth_methods_.  If one of your methods is user/password be warned, after a failure Net::SSH will attempt keyboard-interactive password entry - if you do not want this behavior add _number_of_password_prompts: 0_.
```
HOSTS:
  pe-centos6:
    roles:
      - master
      - agent
      - dashboard
      - database
      - myrole
    platform: el-6-i386
    snapshot : clean-w-keys
    hypervisor : fusion
CONFIG:
  ssh:
    auth_methods:
      - password
      - publickey
    number_of_password_prompts: 0
    password : wootwoot
```
