---
title: 浅谈Linux容器安全：chroot，capability与namespace技术
date: 2022-12-05 16:21:47
cover: /img/container-sec.jpg
top_img: /img/container-sec.jpg
tags:
  - Linux
  - container
  - Docker
---
作者只是个萌新，大佬轻喷。
文章最终确定以时间顺序浅谈Linux容器安全原理。
安全原理相关知识网上已经有很多了，咱通过几个具体攻击实例来讲讲它们的真实作用。
演示均在猫猫自己写的moe-container中进行，使用的是手机，因为实在懒得开电脑了喵………
有关容器技术的具体实现参照咱的另一篇文章：
[从零开始实现一个Linux容器](https://moe-hacker.github.io/2022/12/04/moe-container-lab/)
好了，话不多说让我们开始吧喵！
### chroot技术：
chroot，顾名思义，改变应用程序所参考的根目录，是最早的容器隔离技术，据说最早可追溯到1979年的UNIX chroot，确实是个老东西呢喵～
chroot可以对容器目录进行隔离，听起来还挺安全的………也只是听起来。
chroot容器一般由root权限创建，但创建后并不会将特权进行移除，也就是说，chroot容器内部一般拥有和外部相等的特权。
所以如果一个chroot容器被攻击，拿到了root权限会怎么样呢？
会寄的呢喵！
举两个简单的例子：
你的硬盘设备在容器中拥有和宿主机一样的映射，也就是说可通过挂载宿主机目录形式轻松逃逸。
chroot容器中可以随意杀死宿主机进程，或者制造一起kernel panic。
让我们创建一个chroot容器，简简单单来玩个kill吧喵～
```text
localhost:~# pidof com.miui.misound
21816
localhost:~# kill -9 21816
localhost:~# pidof com.miui.misound
localhost:~#
```
没有任何问题呢喵～
等下……misound是MIUI里干啥的进程……音质音效吧好像？
不管了重启下接着写吧………
### capability实现：
capability，意为能力，始于Linux2.1，它可以授予普通用户的进程一些特权，也可以使得root用户创建的进程自我降低权限。
让我们来创建一个已经被移除了大量capability的chroot容器，再次试一试刚才的kill操作吧喵！
```sh
ps -ae
```
```text
1812 root      0:09 /vendor/bin/msm_irqbalance -f /system/vendor/etc/msm_i
20079 root      0:00 -ash
20111 root      0:00 ps -ae
```
哎等下，刚才的进程怎么看不到了喵喵喵？
好吧是ptrace权限被删了，重新打开吧还是，咱好笨喵呜QwQ……
```text
localhost:~# pidof com.miui.misound
21816
localhost:~# kill -9 21816
ash: can't kill pid 21816: Operation not permitted
localhost:~#
```
root用户居然杀不死system用户的进程，这是何等的奇耻大辱喵！！！
其实是因为容器里没有CAP_KILL权限了。
但是如果我们杀root自己的进程：
```text
localhost:~# pidof ueventd
15009
localhost:~# kill -9 15009
localhost:~# pidof ueventd
13862
localhost:~#
```
system的进程杀不死，居然能杀死root用户的守护进程喵？
没错，CAP_KILL只能保护不归root用户创建的进程，阻止root用户进行降维打击，但对于同用户进程并不生效。
说了半天还是不安全嘛！
当然还是有办法的喵～
### namespace技术：
namespace，意为命名空间，始于Linux2.4，提供一种内核级别隔离系统资源的方法。
咱们通过namespace技术隔离下进程pid信息不就好了喵！
于是我们进入使用unshare隔离了进程信息的容器中：
```sh
ps -ae
```
```text
PID   USER     TIME  COMMAND
    1 root      0:00 -ash
    4 root      0:00 ps -ae
```
进程信息确实被隔离了，现在看起来安全多了，所以既然capability和chroot这么鸡肋，那咱们就只用unshare就好了不是吗喵？
当然是不行的呢！
unshare容器由特权用户创建，容器内部root用户依然具有特权，即使被隔离也可以轻松逃逸或者损坏宿主机。
我们来康康设备列表：
```text
localhost:~# ls /dev
console  mqune    null     pts      shm      stdin    tty      urandom
fd       net      ptmx     random   stderr   stdout   tty0     zero
localhost:~#
```
由于猫猫自己写的容器程序是从内部创建设备文件，所以磁盘设备未被映射，但是：
```sh
mdev -s
```
设备映射脚本甚至不用自己写。
```text
localhost:~# dd if=/dev/sde50 of=boot.img
262144+0 records in
262144+0 records out
localhost:~# dd if=boot.img of=/dev/sde50
262144+0 records in
262144+0 records out
localhost:~#
```
于是手机的boot分区被猫猫读取出来又写入了回去………真无聊喵～
这个过程说明什么呢？说明只用unshare并不安全。
攻击者可能无法直接逃出当前namespace，但是挂载宿主机目录逃逸和硬盘数据损坏依然可以进行。
不过面对一个被移除了特权又利用到namespace技术的容器，即使被攻击也很难逃出去了，因为设备写入，映射和挂载都需要有相应的capability才能实现，这便是docker等容器的实现原理了。
### 总结：
chroot，capability和namespace技术是Linux容器发展的成果，只有三项技术同时使用，才能达到真正的容器安全。

<p align="center">本文著作权归Moe-hacker所有</p>
<p align="center">copyright (©) 2022 Moe-hacker</p>
