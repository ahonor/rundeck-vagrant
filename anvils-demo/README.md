This is a single-machine vagrant configuration that installs
and configures a rundeck instance and an Apache httpd instance.

The httpd instance is used as a simple file web-based
repository from which scripts and job options are shared to Rundeck. 

The examples shown here model a hypothetical application called
"Anvils", a simple web-based service using several functional roles
like web, app and database services.

The purpose of the examples is to show how several teams can
collaborate around how to restart the web tier, manage software
promotions, run status health checks and a nightly batch job.

## Vagrant configuration

The vagrant configuration defines the following virtual machines:

* **rundeck**: The user-facing "primary" rundeck.

The machine uses a centos base box and installs software via yum/rpm.

### Requirements

* Internet access to download packages from public repositories.
* [Vagrant 1.2.2](http://downloads.vagrantup.com)

### Startup

Start up the VM like so:

    vagrant up rundeck

You can access the rundecks from your host machine using the following URLs:

* rundeck: http://192.168.50.2:4440
* httpd: http://192.168.50.2/anvils

## User stories

Every demo needs a back story. The Anvils story begins with a problem about
the right way to restart the web tier. The problem is that under load, the
web servers don't always stop using the normal method documented for ops.
This requires the devs to get involved and run their own script to forcably stop
the web server processes.
Also, due to compliance reasons, the ops team should not give shell login access
to the devs to view logs and check the web servers process status.

The releng team needs a method to promote new versions of the Anvils software
to the artifact repositories used by ops. Because there are several upstream
repositories (eg, CI, stable and release) containing any number of releases
and associated package versions, the Job should contain smart menus to
let users drill down to the package versions they want to promote.

Finally, the devs need ops to run a nightly batch job to rebuild catalog data.
This Job should run at a regular time period using the procedure written by the devs.

## Logins and access control

The rundeck instance is configured for three logins (user/password),
each with specialized roles.

* admin/admin: The "admin" login has full privileges and create, edit, run jobs and ad-hoc commands.
* ops/ops: The "ops" login is able to run jobs but not create or modify them.
* dev/dev: The "dev" login is able to run the "Status" job and look at all logs.

After logging in as any of the users mentioned above, click on the user's profile page 
to see a list of that users group memberships.


The [anvils.aclpolicy](https://github.com/ahonor/rundeck-vagrant/blob/master/anvils-demo/anvils.aclpolicy)
file specifies what actions the "ops" and "dev" users can do. Both groups can 
view information about the nodes, jobs, and history. 



## Nodes

The anvils project has several nodes defined. Go to the "Run" page and press the button
"Show all nodes". You will see the following nodes:

* app_1
* app_2
* db_1
* www_1
* www_2

The nodes listing includes a column called "Tags" displaying the user defined
tags for each of the nodes. For example, all of the nodes are tagged "anvils"
but there are also functionally named tags like "www" and "app" and "db".
Clicking on any of the tag names filters the nodes for ones that are tagged with that name.
Clicking on the "anvils" tag will list all the anvils nodes again.

Pressing the the node name reveals the node's metadata. A node can have any number
of user defined attributes but some "standard" info is included like OS Family,Name,Architecture.
You will also see some metadata specific to Anvils is also shown like "anvils-customer" and "anvils-location". This node metadata is accessible to any command or rundeck job to make
them environment independent.

Since this is a single-machine Vagrant instance,
a little bit of cleverness is used to make the single node look like it is actually six.
Each node is is uniquely named and given its own Linux system account. The Rundeck server
SSH's to the different node's system account to perform any needed action by the rundeck Jobs.

While this example makes use of the bundled SSH support, Rundeck command dispatching is 
completely pluggable and open ended to your desired execution framework.



### Jobs

The rundeck instance will come up with the following demo jobs 
already loaded. 

- anvils/Promote - 'promote the packages'
- anvils/web/Restart - 'restart the web servers'
- anvils/Status - 'Check the status of anvils'
- anvils/nightly_catalog_rebuild - 'rebuild the catalog data'
- anvils/web/start - 'start the web servers'
- anvils/web/stop - 'stop the web servers'

#### Promote

A key part to the promote job is a user interface that lets users manage a hierarchical set of job choices.
The Promote job prompts the user for several choices about which package versions to publish
in the ops package repo. 
The `option` elements specified in job definition read choices from the 
"valuesUrl", which returns JSON data consumable by rundeck. This JSON can be static
files like in this example, but more typically is generated by an external service or tool.

The job contains a trivial script which simply prints out the choices
but also shows how to access command line arguments set by the job.

* [job source](https://github.com/ahonor/rundeck-vagrant/blob/master/anvils-demo/jobs/Promote.xml)

#### Restart

The Restart job includes a "method" option to support the two methods to stop the web servers, "normal" and "force".
Also, because the location of the application installation directory is expected to
vary, a "dir" option is also presented. 


* [job source](https://github.com/ahonor/rundeck-vagrant/blob/master/anvils-demo/jobs/Restart.xml)

#### Status

The Status job executes a procedure written by the devs to check the health of the web tier.
By default, rundeck jobs stop if a failure occurs. This Status job takes advantage of rundeck
step error handling to continue going to the next node if the status check fails.

* [job source](https://github.com/ahonor/rundeck-vagrant/blob/master/anvils-demo/jobs/Status.xml)

#### nightly_catalog_rebuild

The nightly_catalog_rebuild job is meant to run at 00:00:00 (midnight) every day.
The `schedule` element in the job definition specifies this in a crontab like format.
Also, the `notification` element is used to send emails upon success and failure to the 
"bizops@anvils.com" mail group.


* [job source](https://github.com/ahonor/rundeck-vagrant/blob/master/anvils-demo/jobs/nightly_catalog_rebuild.xml)
