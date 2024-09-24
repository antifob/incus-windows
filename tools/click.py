#!/usr/bin/env python3

import os
import pty
import select
import sys
import time


VM = sys.argv[1]


def rd(fd):
    p = select.poll()
    p.register(fd, select.POLLIN)
    _ = p.poll()
    return os.read(fd, 1024)


rdbuf = b''
def rduntil(fd, s):
    global rdbuf
    while 1:
        if s in rdbuf:
            r = rdbuf[:rdbuf.index(s)+len(s)]
            return r
        rdbuf += rd(fd)


pid, fd = pty.fork()
if 0 == pid:
    os.execlp('incus', 'incus', 'start', '--console', sys.argv[1])
else:
    rduntil(fd, b'PciRoot')
    print('[+] Spamming Enter for 10 seconds')
    for _ in range(10):
        os.write(fd, b'\r\n')
        time.sleep(1)


print('[+] Letting the installer do its thing...')
print('[+] Waiting for the VM to be stopped for 10 seconds')
print("[+] You may connect to the VM's VGA using the following command")
print('incus console --type=vga {}'.format(sys.argv[1]))
n = 0
while n < 10:
    s = os.popen('incus ls --format=csv -cs {}'.format(sys.argv[1])).read().strip()
    if 'STOPPED' == s:
        n += 1
    else:
        n = 0
    time.sleep(1)

print('[+] VM stopped')
