---
title: Re：从零开始的Linux容器——ruri开发笔记
date: 2023-07-31 10:14:26
cover: /img/container-lab.jpg
top_img: /img/container-lab.jpg
tags:
- Linux
- C语言
- Container
---
# 在写了，勿cue
## 0x00 前言：
ruri(原名moe-container)终于快写完了，之前一直咕咕咕着的开发笔记差不多也该写写了喵～      
说实话Lightweight, User-friendly Linux-container Implementation这个缩写是后来半夜里突然想起来的，之前只是想取个没被占用的名字，就选了琉璃这个日语名。   
头图是项目最早的版本，真是怀念呢喵，那时候猫猫连数组都不会用，现在ruri代码都突破2k行了。      
虽说这个项目大概率不是啥特别有用的轮子，不过猫猫还是很感谢这个项目的，毕竟写之前猫猫的C语言水平还停留在helloworld水平的说。通过这个项目猫猫逐渐学会了规范化自己的代码，注释也从母语改为了英语，可以说这是猫猫写的第一个规范化的项目 ~~（虽然星标数不如termux-container）~~    
好了好了，不说废话了，讲讲里面的技术详情吧喵～
## 0x01 关于C语言：
说实话虽然个人很喜欢C语言，但是真的不建议新手用C。      
C语言唯一的好处就是能直接查man手册，毕竟是*nix正统语言。      
使用C语言，您可能除了学习C之外，还需要掌握如下工具：
- clang-tidy静态检测工具
- clang-format格式化工具
- GDB调试工具
- ASAN内存检测工具 
- GNUMake用于配置项目构建过程      

~~（高速退学）~~
## 0x02 容器基本原理：
### chroot(2):
来自unistd.h，原型为
```C
int chroot(const char *path);
```
它的作用是改变程序自己认为的根目录为path，需要root权限（其实是CAP_SYS_CHROOT，后面会讲）。       
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
### unshare(2):
来自sched.h，需要先`#define _GNU_SOURCE`。      
原型为：
```C
int unshare(int flags);
```
它的作用是将进程以及其后的子进程的特定flag隔离。      
具体的flag自己看man去吧，ruri没有开启net和user命名空间，它里面unshare相关的代码为：      
### 使用unshare：
```C

pid_t init_unshare_container(bool no_warnings)
{
  pid_t unshare_pid = INIT_VALUE;
  // 创建命名空间
  if (unshare(CLONE_NEWNS) == -1 && !no_warnings)
  {
    printf("\033[33mWarning: seems that mount namespace is not supported on this device QwQ\033[0m\n");
  }
  if (unshare(CLONE_NEWUTS) == -1 && !no_warnings)
  {
    printf("\033[33mWarning: seems that uts namespace is not supported on this device QwQ\033[0m\n");
  }
  if (unshare(CLONE_NEWIPC) == -1 && !no_warnings)
  {
    printf("\033[33mWarning: seems that ipc namespace is not supported on this device QwQ\033[0m\n");
  }
  if (unshare(CLONE_NEWPID) == -1 && !no_warnings)
  {
    printf("\033[33mWarning: seems that pid namespace is not supported on this device QwQ\033[0m\n");
  }
  if (unshare(CLONE_NEWCGROUP) == -1 && !no_warnings)
  {
    printf("\033[33mWarning: seems that cgroup namespace is not supported on this device QwQ\033[0m\n");
  }
  if (unshare(CLONE_NEWTIME) == -1 && !no_warnings)
  {
    printf("\033[33mWarning: seems that time namespace is not supported on this device QwQ\033[0m\n");
  }
  if (unshare(CLONE_SYSVSEM) == -1 && !no_warnings)
  {
    printf("\033[33mWarning: seems that semaphore namespace is not supported on this device QwQ\033[0m\n");
  }
  if (unshare(CLONE_FILES) == -1 && !no_warnings)
  {
    printf("\033[33mWarning: seems that we could not unshare file descriptors with child process QwQ\033[0m\n");
  }
  if (unshare(CLONE_FS) == -1 && !no_warnings)
  {
    printf("\033[33mWarning: seems that we could not unshare filesystem information with child process QwQ\033[0m\n");
  }
  // 修复`can't fork: out of memory`问题
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