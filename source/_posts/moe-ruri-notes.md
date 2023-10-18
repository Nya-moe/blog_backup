---
title: Re：从零开始的容器安全——ruri开发笔记
date: 2023-07-31 10:14:26
cover: /img/container-lab.jpg
top_img: /img/container-lab.jpg
tags:
- Linux
- C语言
- Container
---
# 前言：
ruri刚发了rc1，之前一直咕咕咕着的开发笔记差不多也该写写了喵～        
笔记主要讲容器及安全原理，附带一点C语言。      
头图是项目最早的版本，真是怀念呢喵，那时候咱连数组都不会用，现在ruri代码都突破3k行了。      
文章尚在完善中，不过基本内容已经写完了。      
## 关于使用C语言：
说实话虽然个人很喜欢C语言，但是并不太建议新手用C，go/rust相比起来学习成本以及易用性相较于C均有很大提升。      
C语言唯一的好处就是能直接查man手册，毕竟是Linux正统语言。      
使用C语言，您可能除了学习C之外，还需要掌握如下工具：
- clang-tidy静态检测工具
- clang-format格式化工具
- GDB调试工具
- ASAN内存检测工具 
- GNUMake用于配置项目构建过程   
   
至于学习C语言的心得嘛，        
```
陷入无法察觉的overflow
沦落于oom-killer之下的死尸
就连无法看懂的魔数
也错以为是莫名能跑的奇迹
被泄漏的内存所填满
内核惶恐
逐渐失去的可维护性
终于咕咕而终
「bug还在↗↘↗↘↗↘↗➔➔↘↘」       
```
~~（高速退学）~~
# 容器基本原理：
## Linux挂载点/设备文件：
众嗦粥汁，Linux下的/proc，/sys与/dev均在开机时由init或其子服务创建，部分系统同时会将/tmp挂载为tmpfs，它们都需要被手动挂载到容器才可保证容器中程序正常运行。     
其中，/proc为procfs，/sys为sysfs，/dev为tmpfs。      
你还需要在容器中创建/dev下的设备节点文件。部分文章(怕是全部)在创建chroot/unshare容器时都会直接映射宿主机的/dev目录，这是十分危险的，正确的做法是参照docker容器默认创建的设备文件列表去手动创建这些节点。      
当然了，docker也会将/sys下部分目录挂载为只读，详情可以去看ruri源码或者运行个docker容器看看它的挂载点。      
## 容器注意事项：   
Android的/data默认为nosuid挂载，/sdcard甚至是noexec，所以在安卓/data下创建容器时请将/data重挂载为suid，不要在/sdcard创建容器。      
Archlinux的根目录需要在挂载点上，也就是说需要将容器目录自身bind-mount到自身，否则pacman无法运行。      
/proc/mounts到/etc/mtab的链接可能需要手动创建。     
大部分rootfs的resolv.conf为空需手动创建，安卓系统内容器联网需手动设置，授予需要联网的网络用户组(aid_inet,aid_net_raw)权限。      
## chroot(2):
chroot可是个老家伙了，从1979年Seventh Edition Unix的开发时便产生了这项技术。
### 函数调用：
chroot(2)函数来自`unistd.h`，原型为
```C
int chroot(const char *path);
```
它的作用是改变程序自己认为的根目录为path，需要root权限(其实是CAP_SYS_CHROOT，后面会讲)。       
chroot(2)类似chroot(8)命令，但是它在变更完根目录后什么都不会做。      
~~貌似我们不是C语言入门教学~~      
不装了，直接上代码吧。      
### 一个完整的chroot程序：
```C
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/dir.h>
#include <unistd.h>
int main(int argc, char **argv)
{
  // getuid()返回当前用户uid，类似`id -u`
  if (getuid() != 0)
  {
    // 使用fprintf()输出到stderr更加规范
    fprintf(stderr, "\033[31mError: this program should be run with root privileges !\033[0m\n");
    exit(1);
  }
  if (argc <= 1)
  {
    fprintf(stderr, "\033[31mError: too few arguments !\033[0m\n");
    exit(1);
  }
  // LD_PRELOAD所指定的库如果不存在的话exec()会失败，因此不能设置LD_PRELOAD
  char *ld_preload = getenv("LD_PRELOAD");
  if (ld_preload != NULL)
  {
    fprintf(stderr, "\033[31mError: please unset $LD_PRELOAD before running this program or use su -c `COMMAND` to run.\033[0m\n");
    exit(1);
  }
  char *container_dir = argv[1];
  char *command[1024] = {0};
  // 未指定执行的命令的话默认为`/bin/su -`
  if (argc == 2)
  {
    command[0] = "/bin/su";
    command[1] = "-";
    command[2] = NULL;
  }
  else
  {
    int i = 0;
    for (int j = 2; j < argc; j++)
    {
      command[i] = argv[j];
      i++;
    }
    command[i + 1] = NULL;
  }
  DIR *direxist;
  // opendir()用于判断容器目录是否存在
  if ((direxist = opendir(container_dir)) == NULL)
  {
    fprintf(stderr, "\033[31mError: container directory does not exist !\033[0m\n");
    exit(1);
  }
  else
  {
    closedir(direxist);
  }
  // 切换根目录
  chroot(container_dir);
  // chdir()类似cd命令
  chdir("/");
  // execv()用于执行命令，strerror(errno)用于捕获异常
  if (execv(command[0], command) == -1)
  {
    fprintf(stderr, "\033[31mFailed to execute %s\n", command[0]);
    fprintf(stderr, "execv() returned: %d\n", errno);
    fprintf(stderr, "error reason: %s\033[0m\n", strerror(errno));
    exit(1);
  }
}
```
用法为：
```sh
cc 文件名.c
./a.out NEWROOT [COMMAND [ARG]...]
```
十分的简单，甚至九分的简单。      
### 安全性：
chroot实现了根目录隔离，但是chroot()后的进程会继承父进程特权，而且不幸的是chroot()必须以root(CAP_SYS_CHROOT)特权执行。chroot()后容器仍可访问外部资源，包括但不限于在容器内执行以下操作：      
- kill外部进程
- 创建设备节点并挂载磁盘设备
- 当场逃逸出容器

因此不要将chroot容器用于生产，老老实实地pull个docker image吧还是。
## unshare(2):
Linux内核自2.4版本引入第一个namespace，即mount ns，当初估计作者没打算再加其他隔离就命名为CLONE_NEWNS了，此宏定义一直被沿用至今。      
### Linux父子进程：
众所周知(读者：喵喵喵？我怎么不知道？)，Linux下运行的所有进程都是init的子进程，子进程由父进程经fork(2)或clone(2)创建，继承父进程的文件描述符与UID/GID/权限(特权)等。      
子进程死亡了若父进程没有对其wait(2)或waitpid(2)，则成为僵尸进程。       
父进程先走一步的话，子进程被init直接接管，毕竟硬给其他进程安个子进程的话人家也不认。     
在pid ns中被执行的第一个进程在该ns中被认为与init等效(具有pid 1)，当其死亡时pid ns被内核销毁，其子进程被一同销毁。      
### 函数调用：
unshare(2)函数来自`sched.h`，需要先`#define _GNU_SOURCE`。      
原型为：
```C
int unshare(int flags);
```
它的作用是将进程以及其后的子进程的特定flag隔离。      
Flags:      
```
CLONE_NEWNS (since Linux 2.4)
CLONE_NEWUTS (since Linux 2.6.19)
CLONE_NEWIPC (since Linux 2.6.19)
CLONE_NEWNET (since Linux 2.6.24)
CLONE_SYSVSEM (since Linux 2.6.26)
CLONE_NEWUSER (since Linux 3.8)
CLONE_NEWPID (since Linux 3.8)
CLONE_NEWCGROUP (since Linux 4.6)
CLONE_NEWTIME (since Linux 5.6)
```
### 使用unshare(2)：
ruri没有开启net和user命名空间，它里面unshare相关的代码为：      
```C
pid_t init_unshare_container(bool no_warnings)
{
  pid_t unshare_pid = INIT_VALUE;
  // 创建命名空间
  unshare(CLONE_NEWNS);
  unshare(CLONE_NEWUTS);
  unshare(CLONE_NEWIPC);
  unshare(CLONE_NEWPID);
  unshare(CLONE_NEWCGROUP);
  unshare(CLONE_NEWTIME);
  unshare(CLONE_SYSVSEM);
  unshare(CLONE_FILES);
  unshare(CLONE_FS);
  // 修复`can't fork: out of memory`问题
  // fork()后进程彻底被隔离
  unshare_pid = fork();
  // 修复`can't access tty`
  if (unshare_pid > 0)
  {
    usleep(200000);
    waitpid(unshare_pid, NULL, 0);
  }
  else if (unshare_pid < 0)
  {
    error("Fork error QwQ?");
  }
  return unshare_pid;
}
```
### 安全性：
即使在ns全开的设备中，unshare()后容器中的进程中的root权限依然等于宿主系统中的root权限，因此最简单的攻击方式便是直接修改磁盘中的文件，当然也有其它逃逸方式可进行攻击，于是来到我们的下一节，容器安全。
# 容器安全：
## 进程属性查看：
```
cat /proc/$$/status
```
CapEff表示当前进程capabilities，使用`capsh --decode=xxxxx`来解码。      
NoNewPrivs，Seccomp和Seccomp_filters后面会讲。      
## capabilities(7)与libcap(3):
从2.2版本开始，Linux内核将进程root特权分割为可独立控制的部分，称之为capability，capability是线程属性(per-thread attribute)，可从父进程继承。      
通常所说的root权限其实是拥有相关capability，如chroot(2)其实需要的是CAP_SYS_CHROOT。      
目前内核中定义的capability：
```
CAP_CHOWN 变更文件所有权
CAP_DAC_OVERRIDE 忽略文件的DAC访问限制
CAP_DAC_READ_SEARCH 忽略文件读及目录搜索的DAC访问限制
CAP_FOWNER 忽略文件属主ID必须和进程用户ID相匹配的限制
CAP_FSETID 允许设置文件的setuid位
CAP_IPC_LOCK 允许锁定共享内存片段
CAP_IPC_OWNER 忽略IPC所有权检查
CAP_KILL 向非当前用户进程发送信号（杀死）
CAP_LEASE 允许修改文件锁的FL_LEASE标志
CAP_LINUX_IMMUTABLE 允许修改文件的IMMUTABLE和APPEND属性标志
CAP_NET_ADMIN 允许执行网络管理任务
CAP_NET_BIND_SERVICE 允许绑定到小于1024的端口
CAP_NET_BROADCAST 允许网络广播和多播访问
CAP_NET_RAW 使用原始套接字
CAP_SETGID 设置gid
CAP_SETPCAP 设置其他进程capability
CAP_SETUID 设置uid
CAP_SYS_ADMIN 允许执行系统管理任务，如加载或卸载文件系统、设置磁盘配额等
CAP_SYS_BOOT 重启设备
CAP_SYS_CHROOT 调用chroot
CAP_SYS_MODULE 加载/删除内核模块
CAP_SYS_NICE 允许提升优先级及设置其他进程的优先级
CAP_SYS_PACCT 允许执行进程的BSD式审计
CAP_SYS_PTRACE 允许对任意进程进行ptrace
CAP_SYS_RAWIO 访问原始块设备
CAP_SYS_RESOURCE 忽略资源限制
CAP_SYS_TIME 设置系统时间
CAP_SYS_TTY_CONFIG 设置tty设备
CAP_MKNOD (since Linux 2.4) 创建设备节点
CAP_AUDIT_CONTROL (since Linux 2.6.11) 启用和禁用内核审计；改变审计过滤规则；检索审计状态和过滤规则
CAP_AUDIT_WRITE (since Linux 2.6.11) 将记录写入内核审计日志
CAP_SETFCAP (since Linux 2.6.24) 允许为文件设置任意的capabilities
CAP_MAC_ADMIN (since Linux 2.6.25) 允许MAC配置或状态更改
CAP_MAC_OVERRIDE (since Linux 2.6.25) 覆盖MAC设置
CAP_SYSLOG (since Linux 2.6.37) 允许使用syslog()系统调用
CAP_WAKE_ALARM (since Linux 3.0) 允许触发一些能唤醒系统的东西
CAP_BLOCK_SUSPEND (since Linux 3.5) 使用可以阻止系统挂起的特性
CAP_AUDIT_READ (since Linux 3.16) 允许通过 multicast netlink 套接字读取审计日志
CAP_BPF (since Linux 5.8) 使用bpf()
CAP_PERFMON (since Linux 5.8) 使用perf_event_open()
CAP_CHECKPOINT_RESTORE (since Linux 5.9) 调用checkpoint/restore
```
具体哪些capability需要移除那些保留可直接参照docker。      
### 函数调用：
我们只用到`sys/capability.h`中的cap_drop_bound(3)函数即可。      
```C
int cap_drop_bound(cap_value_t cap);
```
cap值是上面讲到的宏。
## seccomp(2)与libseccomp
Secommp (SECure COMPuting，安全计算模式)，自Linux 2.6.12被引入，用于对进程的系统调用进行限制，个人理解为：      
在启用了Seccomp的设备上：      
进程可执行的系统调用 ==（基本系统调用+进程capability所授予的特权调用）∩ seccomp允许的系统调用           
Seccomp有strict mode和filter mode两种开启模式。
Strict mode:严格模式，怕是已经被弃用了，只是由于历史原因留着，对咱没啥用处。
Filter mode:BPF过滤器模式，对白名单外的系统调用进行过滤。
### 函数调用：
用到`seccomp.h`中的函数来开启bpf模式，完整操作过程为：
```C
// 初始化规则
scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_KILL);
// 添加白名单
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(系统调用), 0);
// ......
// ......
// 关闭默认NO_NEW_PRIV位
seccomp_attr_set(ctx, SCMP_FLTATR_CTL_NNP, 0);
// 载入规则
seccomp_load(ctx);
```
## NO_NEW_PRIV位：
也是进程属性，它就像一个奴籍(作者自己都觉得奇怪的比喻，但是不觉得很合理吗？)，一旦被设置，进程自身及其子进程均无法主动取消此标志。此属性的作用是限制进程的特权集始终小于等于其父进程，也就是说在设置后进程特权只能减少不能增加。此标志设置后可执行文件suid位以及capability属性均无法生效，就连切换用户为普通用户后执行sudo命令也会失效。      
它的设置十分简单，直接使用`sys/prctl.h`中的prctl(2)函数：      
```
prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0);
```
## Secure bit:
内核对进程有额外的secure bit属性，可以去man里面了解下，目前作者只加入了SECBIT_NO_CAP_AMBIENT_RAISE：
```C
prctl(PR_SET_SECUREBITS, SECBIT_NO_CAP_AMBIENT_RAISE);
```
# 后记：
文采太差，没有后记，散会。。。

<p align="center">優しさも笑顔も夢の語り方も、</p>
<p align="center">知らなくて全部、</p>
<p align="center">君を真似たよ</p>