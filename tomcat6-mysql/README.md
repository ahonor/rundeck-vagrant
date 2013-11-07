This is a multi-machine vagrant configuration that 
provisions a rundeck instance and mysql database.

## Vagrant configuration.

The vagrant configuration defines the following virtual machines:

* **mysql**: The mysql VM
* **rundeck**: The rundeck VM


## Requirements

* Internet access to download packages from public repositories.
* [Vagrant](http://downloads.vagrantup.com)

## Startup

Start up the VMs in the following order.

    vagrant up mysql
    vagrant up rundeck


You can access rundecks via:

* http://192.168.50.4:4440


Login to rundeck using user/pass: admin/admin

