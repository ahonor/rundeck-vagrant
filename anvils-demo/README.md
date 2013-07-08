This is a single-machine vagrant configuration that installs
and configures a rundeck instance and an Apache HTTPD instance.

## Vagrant configuration.

The vagrant configuration defines the following virtual machines:

* **rundeck**: The user-facing "primary" rundeck.

The machine uses a centos base box and installs software via yum/rpm.

## Requirements

* Internet access to download packages from public repositories.
* [Vagrant 1.2.2](http://downloads.vagrantup.com)

## Startup

Start up the VMs like so:

    vagrant up rundeck

You can access the rundecks from your host machine using the following URLs:

* rundeck: http://192.168.50.2:4440
* httpd: http://192.168.50.2/anvils

## Logins

The rundeck instance is configured for three logins, each with specialized roles.

* admin/admin: The "admin" login has full privileges.
* ops/ops: The "ops" login is able to run jobs but not create or modify them.
* dev/dev: The "dev" login is able to run the "Status" job and look at all logs.

