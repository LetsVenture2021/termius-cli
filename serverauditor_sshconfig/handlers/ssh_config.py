# -*- coding: utf-8 -*-
"""Module with Sshconfig's args helper."""
from operator import attrgetter, not_
from functools import partial
from cached_property import cached_property
from ..core.models.terminal import SshConfig, SshIdentity, Snippet
from ..core.exceptions import InvalidArgumentException
from ..core.commands.mixins import ArgModelSerializerMixin
from .ssh_key import SshKeyGeneratorMixin


class SshIdentityArgs(SshKeyGeneratorMixin, ArgModelSerializerMixin, object):
    """Class for serializing ssh identity instance."""

    model_class = SshIdentity

    def __init__(self, command):
        """Contruct new ssh config argument helper."""
        self.command = command

    @cached_property
    def fields(self):
        """Return dictionary of args serializers to models field."""
        _fields = {
            i: attrgetter(i) for i in ('username', 'password')
        }
        _fields['ssh_key'] = self.get_ssh_key_field
        _fields['is_visible'] = partial(not_)
        return _fields

    def get_ssh_key_field(self, args):
        """Create ssh key instance from args."""
        return args.identity_file and self.generate_ssh_key_instance(
            args.identity_file
        )

    # pylint: disable=no-self-use
    def add_args(self, parser):
        """Add ssh identity args to argparser."""
        parser.add_argument(
            '-u', '--username', metavar='SSH_USERNAME',
            help='Username for authenticate to ssh server.'
        )
        parser.add_argument(
            '-P', '--password', metavar='SSH_PASSWORD',
            help='Password for authenticate to ssh server.'
        )
        parser.add_argument(
            '-i', '--identity-file', metavar='IDENTITY_FILE',
            help=('Selects a file from which the identity (private key) '
                  'for public key authentication is read.')
        )
        return parser


class SshConfigArgs(ArgModelSerializerMixin, object):
    """Class for ssh config argument adding and serializing."""

    model_class = SshConfig

    def __init__(self, command):
        """Contruct new ssh config argument helper."""
        self.command = command
        self.ssh_identity_args = SshIdentityArgs(self.command)

    @cached_property
    def fields(self):
        """Return dictionary of args serializers to models field."""
        _fields = {
            i: attrgetter(i) for i in ('port', )
        }
        _fields['startup_snippet'] = self.command.get_safely_instance_partial(
            Snippet, 'snippet'
        )
        return _fields

    # pylint: disable=no-self-use
    def add_agrs(self, parser):
        """Add to arg parser ssh config options."""
        parser.add_argument(
            '-p', '--port',
            type=int, metavar='PORT',
            help='Ssh port.'
        )
        parser.add_argument(
            '-S', '--strict-key-check', action='store_true',
            help='Provide to force check ssh server public key.'
        )
        parser.add_argument(
            '-s', '--snippet', metavar='SNIPPET_ID or SNIPPET_NAME',
            help='Snippet id or snippet name.'
        )
        parser.add_argument(
            '--ssh-identity',
            metavar='SSH_IDENTITY', help="Ssh identity's id or name."
        )
        parser.add_argument(
            '-k', '--keep-alive-packages',
            type=int, metavar='PACKAGES_COUNT',
            help='ServerAliveCountMax option from ssh_config.'
        )
        self.ssh_identity_args.add_args(parser)
        return parser

    def serialize_args(self, args, instance=None):
        """Change implementation to add relation serialization."""
        instance = super(SshConfigArgs, self).serialize_args(args, instance)
        instance.ssh_identity = self.serialize_ssh_identity(args, instance)
        return instance

    def serialize_ssh_identity(self, args, instance):
        """Update ssh_identity field and clean old one."""
        old = instance and instance.ssh_identity
        new = self.serialize_ssh_identity_field(args, old)
        if new and old and new.is_visible and not old.is_visible:
            self.clean_invisible_ssh_identity(old)
        return new

    def clean_invisible_ssh_identity(self, ssh_identity):
        """Stub cleaning ssh identity."""
        self.command.storage.delete(ssh_identity)

    def serialize_ssh_identity_field(self, args, instance):
        """Serialize ssh identity."""
        if (args.password or args.username) and args.ssh_identity:
            raise InvalidArgumentException()

        if args.ssh_identity:
            ssh_identity = self.command.get_relation(
                SshIdentity, args.ssh_identity
            )
            if not ssh_identity.is_visible:
                self.command.fail_not_exist(SshIdentity)
            return ssh_identity
        instance = instance and (not instance.is_visible and instance) or None
        return self.ssh_identity_args.serialize_args(args, instance)