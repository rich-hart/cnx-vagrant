cnx-vagrant
===========

Use vagrant to set up a virtual box development VM with:

 - `webview <https://github.com/Connexions/webview>`_
 - `cnx-archive <https://github.com/Connexions/cnx-archive>`_
 - `cnx-authoring <https://github.com/Connexions/cnx-authoring>`_
 - `cnx-publishing <https://github.com/Connexions/cnx-publishing>`_
 - `accounts <https://github.com/openstax/accounts>`_

INSTALL
-------

1. Download vagrant from https://www.vagrantup.com/downloads.html

2. Clone this repository: ``git clone https://github.com/karenc/cnx-vagrant.git``

3. ``cd cnx-vagrant``

4. Create the vm: ``vagrant up`` (takes quite a long time)

5. Go to http://10.11.12.13:8000/ for the cnx site.

UPDATE THE VM
-------------

Once you have the VM running, you might need to update the code once in a
while.  You can run the following to update the code and restart all the
services in the VM::

    vagrant ssh
    # TODO

USAGE
-----

Either you can use the development VM directly or you might just use some of
the services.  For example, if you are a frontend developer, you may have
webview installed locally and use archive, authoring, publishing and accounts
from the VM so you don't have to set them up.

Webview is running at http://10.11.12.13:8000/

Archive is running at http://10.11.12.13:6543/

Authoring is running at http://10.11.12.13:8080/

Publishing is running at http://10.11.12.13:6544/

Accounts is running at https://10.11.12.13:3000/.  There is already an admin
user added with username ``admin`` and password ``password``.
