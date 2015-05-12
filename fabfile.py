import json
import os
import time

from fabric.api import *
import fabric.contrib.files
from ilogue import fexpect

env.DEPLOY_DIR = '/opt'
env.cwd = env.DEPLOY_DIR
env.use_ssh_config = True
env.ssh_config_path = '../.ssh_config'
env.LOCAL_WD = '/Users/openstax/workspace/cnx-vagrant'
env.hosts = 'virtual_machine'
env.ipaddr = 'dev-vm.cnx.org'
env.WORKSPACE = '/Users/openstax/workspace'
env.vm_name = 'cnx_vm' 
env.USER = 'rich'
sh={'HOME':env.DEPLOY_DIR,
    'DEPLOY_DIR':env.DEPLOY_DIR,
    'ipaddr':'dev-vm.cnx.org'}

def test():
    local("pwd")
    from test_fabfile import *
    #from test_fabfile import TestStringMethods 
    import ipdb; ipdb.set_trace()


def create_vm():
    local("vagrant up")
    local("vagrant ssh-config --host virtual_machine > {WORKSPACE}/.ssh_config".format(**env))

def package_vm():
    local("vagrant halt")
    local("vagrant package --base {vm_name} --vagrantfile cnx-dev-vm-Vagrantfile".format(**env))
    local("vagrant box add {USER}/cnx-dev-vm package.box".format(**env))
