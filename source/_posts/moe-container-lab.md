---
title: 从零开始实现一个Linux容器
date: 2022-12-04 15:05:18
tags:
  - Linux
  - C
  - container
cover: /img/container-lab.jpg
top_img: /img/container-lab.jpg
---
欢迎来到猫猫的C语言实验室喵！
## 序言：
文中所述源码是以MIT协议开源的，本文转载请注明原创作者为Moe-hacker，除此之外无其他要求。
作者其实想将本文改名为《Re:从零开始的container生活》，不过考虑到搜索引擎可见性就算了吧。
文章非基础教程，当然写这个容器实现前咱也是零基础的，所以可以放心观看喵～
有关容器安全原理的具体作用请看咱的另一篇文章：
[浅谈Linux容器安全：chroot，capability与namespace技术](https://moe-hacker.github.io/2022/12/05/moe-container-sec/)
文章所有代码均为C语言实现。
所有代码均为root权限执行。
内容遵守最简代码原则，尽量以最少的代码展示C语言接口的调用。
选修部分代码未给出main()函数，请手动添加测试。
程序完善，异常处理与架构设计在选修章节。
本文容器目录为/data/alpine，作为最小测试系统。
文章分必修和选修两个部分，选修部分技术要求可能较高，里面用到的函数未给出详细解说，请自行查看相关文档学习。
成品展示：[Moe-hacker/moe-container](https://github.com/Moe-hacker/moe-container)
## 头文件：
为了方便(其实是懒)，本文所有C语言代码将共享以下头文件：
```C
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <sched.h>
#include <dirent.h>
#include <errno.h>
#include <linux/stat.h>
#include <linux/sched.h>
#include <linux/limits.h>
#include <sys/prctl.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/capability.h>
```
## 必修部分：
### chroot实现:
chroot，顾名思义，更改根目录，容器技术的最基本实现。
演示代码：
```C
#define container_dir "/data/alpine"
int main(){
  chroot(container_dir);
  char *login[]={"/bin/su","-",NULL};
  execv(login[0],login);
  return 0;
}
```
在termux中需要在tsu下删除LD_PRELOAD变量执行。
你已经完成创建了一个基本容器了，很简单吧，让我们继续喵！
### namespace隔离：
namespace技术，linux中的内核隔离技术，可使得进程资源互相隔离。
此处略有些复杂。
运行此段代码请确认内核带有PID namespace支持，否则不会生效。
演示代码为pid namespace的简单利用，实现进程信息隔离。
演示代码：
```C
int main(){
  unshare(CLONE_NEWPID);
  int pid=fork();
  if (pid == 0){
    mount("proc","/proc","proc",MS_NOSUID|MS_NOEXEC|MS_NODEV,NULL);
    system("/bin/ps -ae");
  }
  waitpid(pid,NULL,0);
  return 0;
}
```
运行结果：
```
PID TTY          TIME CMD
    1 pts/0    00:00:00 a.out
    2 pts/0    00:00:00 ps
```
可以看到进程信息被隔离。
注释：
unshare真正实现隔离后能够不受限制运行命令必须经历一次fork()才能实现，否则容器内部将无法fork出新进程运行命令。
fork()函数返回值：父进程返回子进程pid，子进程返回0。
waitpid()可以避免产生僵尸进程并解决容器中无法获取console的问题。
/proc由于在namespace创建之前已被挂载，内部进程信息依然可见，故内部需要重新挂载。
#### 一些可用flags(unshare选项)：
```
CLONE_NEWNS
CLONE_NEWUTS
CLONE_NEWIPC
CLONE_NEWPID
CLONE_NEWCGROUP
CLONE_NEWTIME
CLONE_SYSVSEM
CLONE_FILES
CLONE_FS
```
具体功能请自行查看相关文档，不做过多解释。
#### moe-container未实现功能：
CLONE_NEWNET：会导致容器内网络不可用，需手动创建网桥，但用处不大。
CLONE_NEWUSER：需要usermap映射，但是有capability在，用处貌似也不大？
相信你已经学会如何将进程自身隔离了，那我们继续吧喵～
### capability管理：
capability，linux内核授予进程的特权，使得进程拥有相应权限。
演示代码为CAP_SYS_ADMIN权限的移除。
代码依赖于libcap库，需要添加-lcap参数编译。
演示代码：
```C
int main(){
  cap_drop_bound(CAP_SYS_ADMIN);
  system("mount / /");
  return 0;
}
```
执行结果：
```
mount: '/'->'/': Operation not permitted
```
可以看到虽然以root权限运行，程序内部依然没有挂载权限。
原因就是父进程通过cap_drop_bound()函数主动放弃了挂载相应的特权。
以上是基于事实验证的结论，让我们也来康一康理论验证：
```C
int main(){
  printf("drop前的进程权限：\n");
  system("cat /proc/self/status|grep Cap");
  printf("\n");
  cap_drop_bound(CAP_SYS_ADMIN);
  cap_drop_bound(CAP_SYS_MODULE);
  cap_drop_bound(CAP_SYS_RAWIO);
  cap_drop_bound(CAP_SYS_PACCT);
  cap_drop_bound(CAP_SYS_NICE);
  cap_drop_bound(CAP_SYS_RESOURCE);
  cap_drop_bound(CAP_SYS_TTY_CONFIG);
  cap_drop_bound(CAP_AUDIT_CONTROL);
  cap_drop_bound(CAP_MAC_OVERRIDE);
  cap_drop_bound(CAP_MAC_ADMIN);
  cap_drop_bound(CAP_NET_ADMIN);
  cap_drop_bound(CAP_SYSLOG);
  cap_drop_bound(CAP_DAC_READ_SEARCH);
  cap_drop_bound(CAP_LINUX_IMMUTABLE);
  cap_drop_bound(CAP_NET_BROADCAST);
  cap_drop_bound(CAP_IPC_LOCK);
  cap_drop_bound(CAP_IPC_OWNER);
  cap_drop_bound(CAP_SYS_PTRACE);
  cap_drop_bound(CAP_SYS_BOOT);
  cap_drop_bound(CAP_LEASE);
  cap_drop_bound(CAP_WAKE_ALARM);
  cap_drop_bound(CAP_BLOCK_SUSPEND);
  cap_drop_bound(CAP_SYS_CHROOT);
  cap_drop_bound(CAP_SETPCAP);
  cap_drop_bound(CAP_MKNOD);
  cap_drop_bound(CAP_AUDIT_WRITE);
  cap_drop_bound(CAP_CHOWN);
  cap_drop_bound(CAP_NET_RAW);
  cap_drop_bound(CAP_DAC_OVERRIDE);
  cap_drop_bound(CAP_FOWNER);
  cap_drop_bound(CAP_FSETID);
  cap_drop_bound(CAP_KILL);
  cap_drop_bound(CAP_SETGID);
  cap_drop_bound(CAP_NET_BIND_SERVICE);
  cap_drop_bound(CAP_SETFCAP);
  cap_drop_bound(CAP_SETUID);
  cap_drop_bound(CAP_SYS_TIME);
  cap_drop_bound(CAP_AUDIT_READ);
  cap_drop_bound(CAP_PERFMON);
  cap_drop_bound(CAP_BPF);
  cap_drop_bound(CAP_CHECKPOINT_RESTORE);
  printf("drop后的进程权限：\n");
  system("cat /proc/self/status|grep Cap");
}
```
执行结果：
```text
drop前的进程权限：
CapInh: 0000000000000000
CapPrm: 000001ffffffffff
CapEff: 000001ffffffffff
CapBnd: 000001ffffffffff
CapAmb: 0000000000000000

drop后的进程权限：
CapInh: 0000000000000000
CapPrm: 0000000000000000
CapEff: 0000000000000000
CapBnd: 0000000000000000
CapAmb: 0000000000000000
```
直接干翻了所有权限喵～
具体哪些权限需要移除，那些权限保留可以参照docker的实现。
好哎！容器基本原理你已经学会了，是时候为你的容器程序添砖加瓦了。
## 选修部分：
必修课已经学习完毕了，是时候学习一些新的东西了喵！
### 异常捕获：
大多函数都会定义有异常返回，作为是否执行成功的标志，你需要定义出现异常后所要执行的内容而不是出了bug不知道哪里有问题。
C语言默认没有bool类型，异常返回值一般为int型。
#### 重点函数unshare()和exec()的异常捕获：
若出现异常，这两个函数均会返回-1。
unshare异常大概率是由于内核不支持，输出警告即可。
如下面这段所示：
```C
if(unshare(CLONE_NEWNS) == -1){
  printf("\033[33mWarning: seems that mount namespace is not supported on this device\033[0m\n");
}
```
exec()函数大概率由于容器内su程序并不存在报错，为异常。
如下面这段所示：
```C
if (execv(login[0],login) == -1){
  fprintf(stderr,"\033[31mFailed to execute `/bin/su`\n");
  fprintf(stderr,"execv() returned: %d\n",errno);
  fprintf(stderr,"error reason: %s\033[0m\n",strerror(errno));
  exit(1);
}
```
### 环境检查：
#### termux兼容：
termux中默认存在LD_PRELOAD变量，会导致exec()函数由于依赖库不同无法执行容器内命令。
解决方法：
```C
char *ld_preload=getenv("LD_PRELOAD");
if(ld_preload != NULL){
  fprintf(stderr,"\033[31mError: please unset $LD_PRELOAD before running this program or use su -c `COMMAND` to run.\033[0m\n");
  exit(1);
}
```
#### 权限检查：
容器需要以特权创建，否则会运行失败。
解决方法：
```C
if (getuid() != 0){
  fprintf(stderr,"\033[31mError: this program should be run with root privileges !\033[0m\n");
  exit(1);
}
```
#### 容器目录存在检查：
容器目录不存在会导致chroot()函数失败，检查方法：
```C
DIR *direxist;
if((direxist=opendir(container_dir)) == NULL){
  fprintf(stderr,"\033[31mError: container directory does not exist !\033[0m\n");
  exit(1);
}else{
  closedir(direxist);
}
```
### 参数获取：
这段嵌套偏绕，方法有点笨，但是好用。
main()函数加入int argc,char **argv两个参数。
然后：
```C
char *container_dir=NULL;
for (int arg=1;arg<argc;arg++){
  switch(argv[arg][0]){
    case '-' :
      switch(argv[arg][1]){
        case 'v':
          printf("发现参数-v了喵！\n");
          exit(0);
        default:
          fprintf(stderr,"%s%s%s\033[0m\n","\033[31mError: unknow option `",argv[arg],"`");
    }
    case '/':
    case '.':
      printf("%s%s\n","容器目录为",argv[arg]);
      container_dir=argv[arg];
      break;
    default:
      fprintf(stderr,"%s%s%s\033[0m\n","\033[31mError: unknow option `",argv[arg],"`");
      exit(1);
  }
}
if (!container_dir){
  fprintf(stderr,"\033[31mError: container directory is not set !\033[0m\n");
  exit(1);
}
```
注意break就行了。
这段代码功能有：
- 获取参数 -v
- 获取合法容器路径并记录到指针container_dir
- 若参数异常自动退出

于是你学会了参数获取，让我们继续。
### 容器目录自动挂载：
容器内部需要挂载系统运行时所需目录，否则无法正常运行。
proc目录挂载前记得先umount两次。
sys直接挂载。
dev挂载为tmpfs，里面的设备可以根据docker普通容器设备列表进行映射和权限更改。
实现示例：
```C
mkdir("/dev",S_IRUSR|S_IWUSR|S_IROTH|S_IWOTH|S_IRGRP|S_IWGRP);
mount("tmpfs","/dev","tmpfs",MS_NOSUID,"size=65536k,mode=755");
mkdir("/dev/pts",S_IRUSR|S_IWUSR|S_IROTH|S_IWOTH|S_IRGRP|S_IWGRP);
mount("devpts","/dev/pts","devpts",0,"gid=4,mode=620");
int dev;
dev=makedev(1,3);
mknod("/dev/null",S_IFCHR,dev);
chmod("/dev/null",S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH);
symlink("/proc/self/fd","/dev/fd");
```
具体实现请自行查看moe-container代码及里面的英文注释，懒得翻译回来了。
于是你学会了所有文件系统挂载所需要的知识。
### 其他函数定义：
你可能需要show_helps()和show_version_info()函数来完善你的程序。
当然猫猫还定义了一个show_greetings()函数作为彩蛋。
### 于是，你也完成了你自己的完整容器实现。
## 附加知识：
### 进程名修改：
```C
prctl(PR_SET_NAME,"moe_container",NULL,NULL,NULL);
```
这样无论编译出的文件名称是什么，进程名都会被程序自身重命名为moe_container。
### 宏定义：
移除capability和调用unshare那段，可以在宏中为具体选项定义一个开关，1为开0为关，这样就可以编辑头文件来获得更丰富的自定义了。
### clang编译相关：
#### 优化参数：
-O3用于开启最高优化支持。
#### 安全相关：
-z noexecstack -z now -fstack-protector-all -fPIE -pie
具体能不能用到猫猫也不知道，但是加上也没害处。
#### 静态编译：
静态编译可以让程序自己包含自己的依赖库，从而不需要外部依赖，以提供更好的系统兼容性。
-static选项用于开启静态编译，你需要提前安装静态依赖库。
termux中需要-ffunction-sections -fdata-sections -Wl,--gc-sections参数来解决编译出的程序无法运行的问题。
### Makefile编写：
贴出猫猫的Makefile，相信你基本能看懂：
```makefile
all :
        cc -lcap -O3 -z noexecstack -z now -fstack-protector-all -fPIE -pie container.c -o container
        strip container
no :
        cc -lcap container.c -o container
static :
        cc -static -ffunction-sections -fdata-sections -Wl,--gc-sections -lcap -O3 -z noexecstack -z now -fstack-protector-all -fPIE container.c -o container
        strip container
staticfail :
        cc -static -ffunction-sections -fdata-sections -Wl,--gc-sections -lcap -O3 -z noexecstack -z now -fstack-protector-all -fPIE container.c -o container ./libcap.a
        strip container
install :all
        install -m 777 container ${PREFIX}/bin/container
clean :
        rm container||true
        rm libcap.a||true
help :
        @printf "\033[1;38;2;254;228;208mUsage:\n"
        @echo "  make all        :compile"
        @echo "  make install    :make all and install container to \$$PREFIX"
        @echo "  make static     :static compile"
        @echo "  make staticfail :static compile,fix errors"
        @echo "  make no         :compile without optimizations"
        @echo "  make clean      :clean"
        @echo "Dependent libraries:"
        @echo "  libc-client-static,libcap-static"
        @printf "If you got errors like \`undefined symbol: cap_drop_bound\` or \`undefined reference to \`cap_set_flag' when using static compile,please copy your \`libcap.a\` into current directory and use \`make staticfail\` instead\n\033[0m"

```
### 一个chroot命令的简单实现：
在群里吹水时写的，没啥大用但舍不得删了，就放在这里吧：
头文件依然遵循共享原则(懒死猫猫算了)
```C
int main(int argc,char **argv){
  if (getuid() != 0){
    fprintf(stderr,"\033[31mError: this program should be run with root privileges !\033[0m\n");
    exit(1);
  }
  if (argc <= 1){
    fprintf(stderr,"\033[31mError: too few arguments !\033[0m\n");
    exit(1);
  }
  char *ld_preload=getenv("LD_PRELOAD");
  if(ld_preload != NULL){
    fprintf(stderr,"\033[31mError: please unset $LD_PRELOAD before running this program or use su -c `COMMAND` to run.\033[0m\n");
    exit(1);
  }
  char *container_dir=argv[1];
  char *login[1024]={0};
  if (argc==2){
    login[0]="/bin/su";
    login[1]="-";
    login[2]=NULL;
  }else{
    int login_arg=0;
    for (int arg=2;arg<argc;arg++){
      login_arg=arg-2;
      login[login_arg]=argv[arg];
    }
    login_arg+=1;
    login[login_arg]=NULL;
  }
  DIR *direxist;
  if((direxist=opendir(container_dir)) == NULL){
    fprintf(stderr,"\033[31mError: container directory does not exist !\033[0m\n");
    exit(1);
  }else{
    closedir(direxist);
  }
  chroot(container_dir);
  if (execv(login[0],login) == -1){
    fprintf(stderr,"\033[31mFailed to execute `/bin/su`\n");
    fprintf(stderr,"execv() returned: %d\n",errno);
    fprintf(stderr,"error reason: %s\033[0m\n",strerror(errno));
    exit(1);
  }
}

```
本不想声明著作权的，但又担心有人偷猫猫辛苦写出来的东西。

<p align="center">本文著作权归Moe-hacker所有</p>
<p align="center">copyright (©) 2022 Moe-hacker</p>
