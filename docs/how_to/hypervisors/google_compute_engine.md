This option provisions instances from pre-existing Google Compute Engine images.  Currently only supports debian-7 and centos-6 platforms (<a href = "https://developers.google.com/compute/docs/images#availableimages">Google Compute Engine available images</a>)

Pre-requisites:

  * A Google Compute Engine project.
  * An active service account to your Google Compute Engine project (<a href = "https://developers.google.com/drive/service-accounts">Service Accounts Documentation</a>), along with the following information:
    * The service account private key file (named xxx-privatekey.p12).
    * The service account email address (named xxx@developer.gserviceaccount.com).
    * The service account password.
  * A passwordless ssh keypair (<a href = "http://www.linuxproblem.org/art_9.html">SSH login without password</a>, <a href = "https://developers.google.com/compute/docs/console#sshkeys">Setting up Google Compute sshKeys metadata</a>).
    * Name the pair `google-compute`
    * Place the public key in your Google Compute Engine project metadata
      * `key`: `sshKeys`
      * `value` is the contents of your google_compute.pub with "google_compute:" prepended, eg:
<pre>
google_compute:ssh-rsaAAAABCCCCCCCCCCDDDDDeeeeeeeeFFFFFFFGGGGGGGGGGGGGGGGHHHHHHHHiiiiiiiiiiiJJJJJJJJKKKKKKKKKlllllllllllllllllllMNOppppppppppppppppppQRSTUV123456789101010101101010101011010101010110/ABCDEFGHIJKLMNOP+AB user@machine.local </pre>

### example GCE hosts file###

    HOSTS:
      debian-7-master:
        roles:
          - master
          - agent
          - database
        platform: debian-7-wheezy-xxx
        hypervisor: google
      centos-6-agent:
        roles:
          - agent
        platform: centos-6-xxx
        hypervisor: google
    CONFIG:
      nfs_server: none
      consoleport: 443
      gce_project: google-compute-project-name
      gce_keyfile: /path/to/*****-privatekey.p12
      gce_password: notasecret
      gce_email: *********@developer.gserviceaccount.com

Google Compute cloud instances and disks are deleted after test runs, but it is up to the owner of the Google Compute Engine project to ensure that any zombie instances/disks are properly removed should Beaker fail during cleanup.
