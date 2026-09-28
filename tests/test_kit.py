"""Read-only checks for the distributable kit; no SSH or installation."""
import ast
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


class KitTests(unittest.TestCase):
    def test_required_payload(self):
        for name in ('waydroid-atv16-control', 'atv16-controller-hotplug',
                     'atv16-remote-start', 'atv16-remote-stop', 'atv16-mdns.py',
                     'bpfloader-wrapper.sh', '72-waydroid-atv16-remote.rules',
                     'waydroid-atv16-sudoers', 'waydroid.cfg',
                     'Android-TV-16-Steam.sh', 'Android-TV-16-Steam.desktop',
                     'launcher-logging.sh'):
            self.assertTrue((ROOT / 'runtime' / name).is_file(), name)

    def test_sources_are_lf_without_bom(self):
        for folder in ('runtime', 'scripts'):
            for path in (ROOT / folder).iterdir():
                if path.is_file():
                    data = path.read_bytes()
                    self.assertNotIn(b'\r\n', data, str(path))
                    self.assertFalse(data.startswith(b'\xef\xbb\xbf'), str(path))

    def test_remote_workarounds(self):
        rule = (ROOT / 'runtime/72-waydroid-atv16-remote.rules').read_text()
        for required in ('virtual-remote', '18d1', '0100', 'LIBINPUT_IGNORE_DEVICE', '0600'):
            self.assertIn(required, rule)
        control = (ROOT / 'runtime/waydroid-atv16-control').read_text()
        self.assertIn('chown 1000:1000 /dev/uinput', control)
        self.assertIn('chmod 660 /dev/uinput', control)
        hotplug = (ROOT / 'runtime/atv16-controller-hotplug').read_text()
        self.assertIn('TARGET_VENDOR=28de', hotplug)
        self.assertIn('"$vendor" = 18d1', hotplug)

    def test_exact_release_and_no_embedded_credentials(self):
        installer = (ROOT / 'scripts/install.sh').read_text()
        self.assertIn('20260403-GAPPS', installer)
        self.assertIn('20260403-MAINLINE', installer)
        self.assertEqual(installer.count('sha256sum -c -'), 2)
        root_installer = (ROOT / 'scripts/install-root.sh').read_text()
        self.assertIn('waydroid upgrade -o', root_installer)
        self.assertNotIn('rm -rf', root_installer)
        self.assertIn('A Waydroid environment is mounted', root_installer)
        for folder in ('runtime', 'scripts'):
            for path in (ROOT / folder).iterdir():
                if path.is_file():
                    text = path.read_text(encoding='utf-8')
                    self.assertNotIn('192.168.31.', text, str(path))
                    self.assertNotIn('DECK_SSH_PASSWORD', text, str(path))

    def test_mdns_packet_functions(self):
        # Compile only pure definitions; importing the live announcer would
        # bind UDP 5353, which a test must not do.
        tree = ast.parse((ROOT / 'runtime/atv16-mdns.py').read_text())
        nodes = [node for node in tree.body if isinstance(node, ast.FunctionDef)
                 and node.name in ('dns_name', 'record', 'reply', 'read_name')]
        import socket
        import struct
        namespace = dict(socket=socket, struct=struct, lan_ip='192.0.2.10',
                         service='_androidtvremote2._tcp.local',
                         instance='Steam Deck Android TV._androidtvremote2._tcp.local',
                         host='steamdeck-androidtv.local')
        exec(compile(ast.Module(body=nodes, type_ignores=[]), '<mdns functions>', 'exec'), namespace)
        packet = namespace['reply']()
        self.assertEqual(struct.unpack_from('!6H', packet)[:4], (0, 0x8400, 0, 4))
        self.assertIn(socket.inet_aton('192.0.2.10'), packet)
        encoded = namespace['dns_name']('abc.local')
        self.assertEqual(namespace['read_name'](encoded, 0), ('abc.local', len(encoded)))
        offset = 12
        for _ in range(4):
            _, offset = namespace['read_name'](packet, offset)
            kind, _, ttl, length = struct.unpack_from('!HHIH', packet, offset)
            offset += 10
            data = packet[offset:offset + length]
            if kind == 16:
                self.assertEqual(data[0], len(data) - 1)
            self.assertEqual(ttl, 120)
            offset += length
        self.assertEqual(offset, len(packet))

    def test_bash_syntax_when_available(self):
        if os.name == 'nt':
            self.skipTest('Run Linux-path Bash checks on the Deck, not the Windows WSL stub')
        bash = shutil.which('bash')
        if not bash:
            self.skipTest('bash unavailable; run this check on Linux/Deck')
        candidates = list(ROOT.glob('*.sh')) + list((ROOT / 'scripts').glob('*.sh'))
        candidates += [p for p in (ROOT / 'runtime').iterdir()
                       if p.read_bytes().startswith(b'#!/bin/bash') or p.suffix == '.sh']
        for path in candidates:
            result = subprocess.run([bash, '-n', str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, f'{path}: {result.stderr}')

    def test_launch_log_is_written_by_pipe_not_inherited_file(self):
        if os.name == 'nt' or not shutil.which('bash'):
            self.skipTest('Linux Bash required')
        with tempfile.TemporaryDirectory() as directory:
            log = pathlib.Path(directory) / 'steam-launch.log'
            script = '''source "$1"
setup_launch_logging "$2"
kind=$(stat -Lc %F /proc/$$/fd/1)
printf 'stdout-kind:%s\\n' "$kind"
printf 'launch-test\\n'
'''
            args = ['bash', '-c', script, 'logging-test',
                    str(ROOT / 'runtime/launcher-logging.sh'), str(log)]
            for _ in range(2):
                result = subprocess.run(args, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('stdout-kind:fifo', result.stdout)
            self.assertEqual(log.stat().st_uid, os.getuid())
            self.assertEqual(log.read_text().count('launch-test'), 2)

    def test_unwritable_legacy_launch_log_is_recovered(self):
        if os.name == 'nt' or not shutil.which('bash') or os.getuid() == 0:
            self.skipTest('Unprivileged Linux Bash required')
        with tempfile.TemporaryDirectory() as directory:
            log = pathlib.Path(directory) / 'steam-launch.log'
            log.write_text('old-log\n')
            log.chmod(0o444)
            script = 'source "$1"; setup_launch_logging "$2"; printf "new-log\\n"'
            result = subprocess.run(['bash', '-c', script, 'logging-test',
                                     str(ROOT / 'runtime/launcher-logging.sh'), str(log)],
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(log.read_text(), 'new-log\n')
            self.assertEqual(log.with_name('steam-launch.previous.log').read_text(), 'old-log\n')

    def test_release_has_no_private_material(self):
        archive = ROOT / 'dist/android-tv16-steamdeck.zip'
        if not archive.exists():
            self.skipTest('Build ZIP first')
        with zipfile.ZipFile(archive) as kit:
            names = kit.namelist()
            self.assertIn('README.md', names)
            self.assertIn('runtime/waydroid.cfg', names)
            for name in names:
                self.assertFalse(name.startswith(('archive/', 'local/')), name)
                self.assertNotIn('known_hosts', name)
                self.assertFalse(name.endswith(('.img', '.pyc')), name)


if __name__ == '__main__':
    unittest.main(verbosity=2)
