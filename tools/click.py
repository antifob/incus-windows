#!/usr/bin/env python3
#
# This file is part of incus-windows.
#
# Copyright 2022-2026, Philippe Grégoire <git@pgregoire.xyz>
#

import os
import pty
import select
import signal
import subprocess
import sys
import time


# internal tool, ensure that we have an argument
VM = sys.argv[1]


def rd(fd):
    p = select.poll()
    p.register(fd, select.POLLIN)
    _ = p.poll()
    return os.read(fd, 1024)


def waitbooting(fd):
    buf = b''
    while True:
        # UEFI or CSM
        if b'PciRoot' in buf or b'Booting from DVD/CD' in buf:
            break
        buf += rd(fd)


pid, fd = pty.fork()
if 0 == pid:
    os.execlp('incus', 'incus', 'start', '--console', VM)
else:
    waitbooting(fd)
    print('[+] Spamming Enter for 10 seconds')
    for _ in range(10):
        os.write(fd, b'\r\n')
        time.sleep(1)

    print('[+] Releasing console')
    os.kill(pid, signal.SIGTERM)
    try:
        os.waitpid(pid, 0)
    except ChildProcessError as e:
        print('[+]', str(e))

print('[+] Letting the installer do its thing...')
print('[+] Waiting for the VM to be stopped for 10 seconds')
print("[+] You may connect to the VM's VGA using the following command")
print('incus console --type=vga {}'.format(VM))
n = 0
while n < 10:
    o = subprocess.check_output(['incus', 'ls', '-fcsv', '-cns', VM], env={'LANG': 'C'})
    for ln in o.split(b'\n'):
        if not ln.startswith(f'{VM},'.encode()):
            continue
        if ln.endswith(b',STOPPED'):
            n += 1
        else:
            n = 0
    time.sleep(1)

print('[+] VM stopped')
