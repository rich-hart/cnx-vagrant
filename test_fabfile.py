import unittest
#from fabric.api import env
from fabfile import *

env.host_string = 'virtual_machine'

class TestCNXVagrant(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        pass

    @classmethod
    def tearDownClass(cls):
        pass

    def test_empty(self):
        pass

    def test_create_vm(self):
        create_vm()
        expected_status = """
        Current machine states:

        default                   running (virtualbox)

        The VM is running. To stop this VM, you can run `vagrant halt` to
        shut it down forcefully, or you can run `vagrant suspend` to simply
        suspend the virtual machine. In either case, to restart it again,
        simply run `vagrant up`.
        """.format(**env)
        actual_status = local("vagrant status",capture=True)
        self.assertEqual(expected_status.split(),actual_status.split())
        # output = run("dpkg -s python-pip")
        # print(output)
         
#if __name__ == '__main__':
#    unittest.main()

