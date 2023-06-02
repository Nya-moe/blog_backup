---
title: 在Linux下优雅的调试C语言
date: 2023-06-01 16:21:47
cover: /img/c-lab.jpg
top_img: /img/c-lab.jpg
tags:
  - Linux
  - C语言
---
最近在开发ruri时遇到不少问题，猫猫也是第一次写C，早知道头顶这么发凉就去用某邪教了呜喵～      
好了好了，C语言还是有许多优点的，只是可能入门成本高些罢了，如果善用测试工具的话还是没有那么糟糕的，话不多说我们开始今天的正文。
## 首要前提：
代码没bug的就不要调试了，编程第一法则不就是能跑的代码不要动嘛喵～
过早的优化是万恶之源，测试时不要开-O3，且尽量使用`-O0 -fno-stack-protector -fno-omit-frame-pointer`来测试。
那如果有bug呢？
首先得能过编译器，编译器都报error的代码再高端的调试工具也无能为力。
然后检查编译器的警告，加上参数`-Wall -Wextra`编译然后查看警告，若是编译器警告都无法修复的话。。。这bug咱别修了吧喵～
如果编译器不报警呢？
于是就是今天的主题了--如何面对编译时无法找出的bug。
## 消极面对：
部分内存问题可以通过编译器参数被隐藏，编译时加上`-O3 -z noexecstack -z now -fstack-protector-all -fPIE `说不定就能跑了喵～
好了本文完，下期再见喵～
桥豆麻袋，自己的项目中的代码肯定不能挖坑埋雷啊喵～
## 积极面对：
中国有句古话叫做，食食物者为俊杰，眼下的各种工具，我想一定能找到阁下的bug。
### 使用clang-tidy检查代码
clang-tidy是llvm项目的一部分，用于代码静态检测。
事实上由于clang-tidy过于优秀，大部分简单的bug在这里就会被检测出来，根本用不到运行，当然，它无法检查代码的功能是否可以正确实现。
基本用法：
```sh
clang-tidy xxx.c -- 编译参数
```
注意编译参数前的`--`，后面接clang/gcc编译时的参数。
但是，很多规则不是有用的，比如对strlen.h中函数内存安全的报警就非常多余，甚至clang-tidy会建议使用BSD中的函数替代，对此猫猫建议还是不要建议了。
因此我们需要关闭部分检测项目。
使用`--checks=-检测项`来关闭检测项。
ruri中默认关闭的检测项：
```
--checks=-clang-analyzer-security.insecureAPI.strcpy,-clang-analyzer-security.insecureAPI.DeprecatedOrUnsafeBufferHandling 
```
这样大部分内存泄漏等问题都可以被找出了。
如果需要更多检测：
```
--checks=*
```
比如ruri中的strictcheck：
```
--checks=*,-clang-analyzer-security.insecureAPI.strcpy,-altera-unroll-loops,-cert-err33-c,-concurrency-mt-unsafe,-clang-analyzer-security.insecureAPI.DeprecatedOrUnsafeBufferHandling,-readability-function-cognitive-complexity,-cppcoreguidelines-avoid-magic-numbers,-readability-magic-numbers,-misc-no-recursion,-bugprone-easily-swappable-parameters,-readability-identifier-length,-cert-err34-c,-bugprone-assignment-in-if-condition
```
目前ruri已经过了这些检测，但愿读者的内存永远不要泄漏喵～
### 使用ASAN查看内存问题：
ASAN全称Address Sanitizer，是google发明的一种内存地址错误检查器，用于在运行时检测代码内存问题。
如何使用：
编译时加入参数`-O0 -fsanitize=address -fno-stack-protector -fno-omit-frame-pointer`
如果运气好的话，设置环境变量`LSAN_OPTIONS="verbosity=1:log_threads=1" ASAN_OPTIONS="verbosity=1"`，你将看到一片fa的冥场面。
```log
SUMMARY: AddressSanitizer: heap-buffer-overflow asan_interceptors.cpp.o in printf_common(void*, char const*, __va_list_tag*)
Shadow bytes around the buggy address:
  0x0c427fff81d0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x0c427fff81e0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x0c427fff81f0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x0c427fff8200: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x0c427fff8210: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
=>0x0c427fff8220:[fa]fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
  0x0c427fff8230: fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
  0x0c427fff8240: fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
  0x0c427fff8250: fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
  0x0c427fff8260: fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
  0x0c427fff8270: fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
```
貌似还.......挺好看......
一般来讲出问题的行会在后面汇报。
不过ASAN面对fork()后的程序貌似有点抽风，猫猫写的代码好不容易跑起来了，结果退出时卡在`sched_yield()`这个系统调用，但是猫猫的程序出口都在main()，子进程最终会执行exec()，所以怀疑是ASAN的问题，猫猫暂时也没能解决呜呜呜～
在有些教程中ASAN偶尔会配合addr2line使用，猫猫实测貌似也定位不到相关行，或许是猫猫太笨了喵～
### 使用GDB调试工具
GDB全称The GNU Project Debugger，是GNU项目的一部分。
在编译时加如参数`-ggdb`，不要开任何优化，然后就可以使用gdb来调试程序了。
注意，代码里少写两个goto有助于调试，白皮书说C语言提供了可以随意滥用的goto语句，瞧瞧这说的，像话吗喵！！！
基本命令：
```sh
gdb ./可执行文件
```
或者对于运行中的程序：
```sh
gdb attach <pid>
```
然后你获得了一个这样的终端：
```
For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from ./ruri...
(gdb) 
```
基本命令：
开始运行程序：
```
r 程序的命令行参数
```
设置断点：
```
b 行号
```
继续执行：
```
c
```
追踪子进程：
```
set follow-fork-mode child
```
查看当前行号：
```
where
```
查看上面的行：
```
up
```
打印变量：
```
p 变量名/表达式
```
这个功能真的震惊到猫猫了，因为C语言表达式都能用。
比如：
```
(gdb) p container_info->container_dir
$1 = 0x7c2ff7ca8500 "/home/moe-hacker/t"
(gdb)
```
监控变量：
```
watch 变量名
```
两个特殊的breakpoint：
```
在入口处：
b main
在出口处：
b exit
```
### 使用strace工具：
strace全称Linux Syscall Tracer，听名字就知道，用于追踪进程的系统调用。众所周知，进程总要有系统调用，追踪这部分内容有时可以帮助我们发现问题。
基本用法：
```
对于已有进程：
strace -p 进程id
用strace来创建：
strace ./可执行文件
```
所以猫猫的程序在ASAN下卡在`sched_yield() = 0`是为什么啊喵！！！
## 总结：
C语言虽然很容易写出bug，但是善用工具，养成良好的代码风格还是可以避免大部分问题的。还有就是，得会点英语。
群里曾经有一位萌新问道：
"如果我想入门编程语言，学哪种比较好？"
大佬答："英语"
本文完，我们下期再见喵～
EOF