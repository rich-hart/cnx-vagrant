cnx-vagrant
===========

Use vagrant to set up a virtual box development virtual machine (VM) with:

 - `webview <https://github.com/Connexions/webview>`_
 - `cnx-archive <https://github.com/Connexions/cnx-archive>`_
 - `cnx-authoring <https://github.com/Connexions/cnx-authoring>`_
 - `cnx-publishing <https://github.com/Connexions/cnx-publishing>`_
 - `accounts <https://github.com/openstax/accounts>`_

INSTALL
-------

A tested version of the VM is available on atlas.hashicorp.com, you can see the
release notes at https://atlas.hashicorp.com/karenc/boxes/cnx-dev-vm.

To download the cnx development VM from atlas.hashicorp.com:

1. Download vagrant from https://www.vagrantup.com/downloads.html

2. ``vagrant init karenc/cnx-dev-vm``

3. ``vagrant up``

4. Edit your ``/etc/hosts`` file to include this line::

    10.11.12.13        dev-vm.cnx.org

5. Go to http://dev-vm.cnx.org:8000/ for the cnx site.

UPDATE THE VM
-------------

Once you have the VM running, you might need to update the code once in a
while.  You can run the following to update the code and restart all the
services in the VM::

    vagrant ssh
    # TODO
    sudo /etc/init.d/cnx-dev-vm restart

CHECK VM STATUS
---------------

You can use ``vagrant status`` to check the status of the VM.  You'll see
something similar to this::

    Current machine states:

    default                   running (virtualbox)

    The VM is running. To stop this VM, you can run `vagrant halt` to
    shut it down forcefully, or you can run `vagrant suspend` to simply
    suspend the virtual machine. In either case, to restart it again,
    simply run `vagrant up`.

DELETE THE VM
-------------

If you don't want the VM anymore, you can do ``vagrant destroy`` in the
directory with the Vagrantfile and it should remove the VM.

USAGE
-----

Either you can use the development VM directly or you might just use some of
the services.  For example, if you are a frontend developer, you may have
webview installed locally and use archive, authoring, publishing and accounts
from the VM so you don't have to set them up.

Webview is running at http://dev-vm.cnx.org:8000/

Archive is running at http://dev-vm.cnx.org:6543/

Authoring is running at http://dev-vm.cnx.org:8080/

Publishing is running at http://dev-vm.cnx.org:6544/

Accounts is running at https://dev-vm.cnx.org:3000/.  There is already an admin
user added with username ``admin`` and password ``password``.

CREATE A VM FROM VAGRANTFILE
----------------------------

If you don't want to use the version on atlas.hashicorp.com, you can create the
VM yourself:

1. Download vagrant from https://www.vagrantup.com/downloads.html

2. Clone this repository: ``git clone https://github.com/karenc/cnx-vagrant.git``

3. ``cd cnx-vagrant``

4. Create the vm: ``vagrant up`` (takes quite a long time)

5. Edit your ``/etc/hosts`` file to include this line::

    10.11.12.13        dev-vm.cnx.org

6. Go to http://dev-vm.cnx.org:8000/ for the cnx site.

PACKAGE THE VM
--------------

Once you have created the VM, look for the VirtualBox machine name.  (On my
machine, it's in ``~/VirtualBox VMs``)

1. Shutdown the vm: ``vagrant halt``
2. ``vagrant package --base <virtual-box-vm-name> --vagrantfile cnx-dev-vm-Vagrantfile``
3. ``vagrant box add karenc/cnx-dev-vm package.box``
4. ``vagrant box list`` should show ``karenc/cnx-dev-vm``
5. In another directory, try downloading the VM: ``vagrant init karenc/cnx-dev-vm``
6. ``vagrant up``
7. Go to http://dev-vm.cnx.org:8000/ for the cnx site.
8. Follow this guide to upload the box to atlas.hashicorp.com:
   https://vagrantcloud.com/docs/providers (look for ``UPLOAD A .BOX FOR PROVIDER``)
9. Delete the local box: ``vagrant box remove karenc/cnx-dev-vm``
