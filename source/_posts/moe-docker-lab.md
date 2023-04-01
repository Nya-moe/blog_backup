---
title: 为你的手机内核开启docker支持
date: 2022-12-04 23:42:50
tags:
  - Linux
  - Termux
  - Docker
  - container
cover: /img/docker-lab.jpg
top_img: /img/docker-lab.jpg
---
欢迎来到猫猫的Docker实验室喵！
在这里，你将会学习如何为自己的手机开启docker支持，期待你的成果喵～
文章会包含一些小技巧和docker基本异常处理，毕竟这只可爱的猫猫是不会向你隐瞒自己知道的东西的，真是一只傻的可爱的猫猫呢～
文章内所述手机为arm64架构，上古时期的32位架构请自行修改。
注：pixel系列设备如pixel3在测试时发现如果不用官方构建工具，生成vmlinux这一步会导致系统内存溢出，开多大swap都没用，只是崩溃/死机的时间问题，目前原因未知，故此教程不适用于pixel系列设备，pixel系列设备请换用repo工具。
好了让我们开始吧喵！
### 首要前提：
- 手机能够获取root权限
- 手机内核开源
- 拥有一定Linux基础

如果设备或个人不满足以上条件者请自行退出喵！本猫猫是没时间给你解释为什么的。
### 前期准备：
你可能需要准备如下内容：
- Linux系统环境(理论上手机电脑均可，电脑最佳)
- 熟练使用搜索工具
- git和make以及代码编辑工具的使用
- 基本了解cpu架构差异

这些内容猫猫是不会教你的，毕竟这不是文章重点喵唔……
当然最好有个脑子，可惜猫猫没有呜QAQ………
### 正式操作：
#### 0x0001 root手机，不必多说
#### 0x0002 获取手机代号和cpu代号
这一步请通过搜索工具进行。
比如猫猫现在用的小米10ultra代号cas，cpu代号SM8250。
#### 0x0003 查找内核源码
可以去官方仓库，当然咱建议用第三方的，因为官方内核很多时候还不如第三方好跑呢。
查找方式：官方仓库查找设备代号或github搜索关键字kernel + 设备代号或者反过来或者搜索cpu代号+手机厂商+kernel，各种组合和命名方式都试过了还找不到的话，多半是没有了，猫猫也没有办法呢。
#### 0x0004 编译工具选择
手机执行：
```sh
cat /proc/version
```
猫猫的手机会有如下输出：
```
Linux version 4.19.260-Moe-hacker-g0bb1c026ee65-dirty (root@localhost) (Ubuntu clang version 14.0.6-2, GNU ld (GNU Binutils for Ubuntu) 2.39) #3 SMP PREEMPT Sun Oct 2 10:48:46 CST 2022
```
当然猫猫已经完成内核编译了，仔细观察会发现内核由clang-14编译。
于是你确认了要用的编译器版本。
如果是由谷歌的安卓开发工具构建，请自行查找并下载。
小技巧：使用原系统内核使用的编译器版本可以降低出错概率。
编译环境可以去搜一搜dockerhub啥的，毕竟电脑肯定会有docker支持。
手机可以去找找llvm的release，注意用arm64架构的。
#### 0x0005 源码获取：
使用git clone项目仓库，如果是官方仓库需要加入-b选项克隆机型独立的分支。
#### 0x0006 依赖安装：
主要依赖有：clang/gcc构建工具,跨架构binutils工具(跨架构编译需要),make,python,libssl-dev,build-essential,bc,bison,flex,unzip,libssl-dev,ca-certificates,xz-utils,mkbootimg,cpio,device-tree-compiler，请自行安装，否则编译会出错。
#### 0x0007 尝试编译：
进入项目目录
```sh
ls arch/arm64/configs
```
康一康有没有你的机型代号相关的文件，一般是[机型代号]_defcofig，也有带stock或者perf的命名，选一个就行。
没有的话也不要着急，再看一下vendor目录：
```sh
ls arch/arm64/configs/vendor
```
然后，呐，现在要开始编译了哦喵！
```sh
export ARCH=arm64
export SUBARCH=arm64
make O=out CC=[clang/gcc-版本号] (vendor/)xxxxxx_defconfig ［可选参数］
```
可选参数详解：
```sh
#非电脑跨架构编译省略
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-
#本人基本没用到过，按需开启
AR=llvm-ar
OBJDUMP=llvm-objdump
STRIP=llvm-strip
NM=llvm-nm
OBJCOPY=llvm-objcopy
LD=ld.lld
```
以上可选参数可用于报错处理，酌情加入。
然后，其他参数不变，删掉(vendor/)xxxxxx_defconfig，改为-j8，开始构建内核。
#### 0x0008 基本异常处理：
找不到头文件：
安装相应库。
找不到命令：
安装相应软件。
-Werror,xxxxxxx：
找报错的文件相应Makefile,把含有-werror的都删了(每一层目录都有，建议从报错文件那一层往父目录找)，或者make选项改为CC="[clang/gcc]-版本号 -w"
未定义函数：
查找函数定义开启所依赖的配置项一并开启，可能在头文件或kconfig/makefile中。
#### 0x0009 玄学异常：
在编译pixel3内核时，C语言零基础的猫猫删了一行源码成功生成内核，开机功能一切正常。
在编译小米10Ultra内核时一行源码少了一个地址符&，手动添加后一切正常。
遇到这种不可预知的玄学异常建议动用搜索工具，或者学会放弃。
引用沨鸾在酷安的原文：会修的就修，修不了换源码，换编译器版本，手机电脑换着试，最后放弃就好了。
如果你跨过了首次编译这道坎，那么恭喜，你离成功不远了喵！
#### 0x000A 功能开启：
下载check-config.sh
```sh
wget https://github.com/moby/moby/raw/master/contrib/check-config.sh
```
网络不好请使用kgithub镜像站，目前可用。
然后：
```sh
sh check-config.sh out/.config|grep missing|sed -E 's/\-//g'|sed -E "s/ //g"|sed -r 's/://'|sed -E "s/missing/=y/"
```
善良的猫猫甚至帮大家写好了字符替换，猫猫自己都没这待遇呢。
于是你得到了内核未开启的的配置列表。
```
CONFIG_AUFS_FS=y
/dev/zfs=y
zfscommand=y
zpoolcommand=y
```
以上这几个输出不用管，删了就好，这几个的源码实现均未并入linux4.x主分支。
然后把缺失的config加入你的(vendor/)xxxxxx_defconfig中，并将里面带有is not set的字样全部删除，执行编译第一步，再次生成配置。
这一步你可以更改local version值为你的名字或者你喜欢的单词。
再次执行扫描命令，获取缺失项目。
使用make menuconfig命令，按下/键搜索缺失项目的依赖与冲突，依赖添加开启选项，冲突关闭。
注意：menuconfig配置默认不带CONFIG_头，需要手动添加。
然后，将配置中所有=m替换为=y，目的是将内核模块built-in。
请确认最终生成out/.config中不包含=m字样。
#### 0x000B 再次编译：
请自行repeat上文所述编译步骤。
生成文件在out/arch/arm64/boot/目录下，大部分命名为Image.xxx-dtb，但是注意，少数机型只能刷入Image.xx格式镜像。
#### 0x000C 验证config：
scripts目录下有个extract-ikconfig，用它把Image的配置扫出来输出到一个文件，check-config.sh除上文所讲述的无法开启的配置全绿即可。
#### 0x000D 刷入：
下载刷入工具：
```sh
git clone https://github.com/osm0sis/AnyKernel3
```
编辑anykernel.sh，修改如下内容：
device.name1=设备代号
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=如果是ab架构分区设备填1，否则填0
将Image.xxx-dtb复制到anykernel根目录下，打包anykernel根目录，twrp刷入。
注意，少数机型只能刷入Image.xx格式镜像。
于是你就到了最终环节：开机，验证。
教程完毕，相信你也可以在手机上运行自己的内核了喵！
### 基本报错处理：
如果报错如下：
```log
docker: Error response from daemon: OCI 
runtime create failed: container_linux.go:370: starting 
container process caused: process_linux.go:326: applying 
cgroup configuration for process caused: mountpoint for 
devices not found: unknown. 
``` 
那么您需要手动挂载cgroupfs(root权限执行):
```sh
mount -t tmpfs -o mode=755 tmpfs /sys/fs/cgroup
mkdir -p /sys/fs/cgroup/devices
mount -t cgroup -o devices cgroup /sys/fs/cgroup/devices
```
然后，重启docker即可。 
容器中没网可通过在容器中执行以下脚本解决root用户联网问题： 
[group_add.sh](https://github.com/Moe-hacker/termux-container/blob/main/package-zh/data/data/com.termux/files/usr/share/termux-container/group_add.sh)
猫猫自己没有遇到过的两个异常解决方式：
添加--iptables=false参数
设置DOCKER_RAMDISK=true
本文完。

<p align="center">本文著作权归Moe-hacker所有</p>
<p align="center">copyright (©) 2022 Moe-hacker</p>
