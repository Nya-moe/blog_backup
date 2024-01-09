---
title: Nothing Phone(2)的灯带驱动研究笔记
date: 2024-01-10 00:37:43
tags:
  - Linux
cover: /img/pong-glyph.jpg
top_img: /img/pong-glyph.jpg
---
好久不见喵～（怎么又是这个开场白。。。）
最近整了部Nothing Phone(2)，bl秒解的设定是真的舒服，所以买来第一时间就透了一遍（指root了）。
然后半夜睡不着，就打算研究一下这个灯带是怎么调用的。
然后就开始了一段孤独的旅程充满烦恼～
# 内核源码：
很不幸，除了知道了灯带型号是aw20036之外没啥收获，原因无他，单纯看不懂代码，注释都不怎么写这不欺负萌新吗。。。
仓库里相关代码文件甚至具有可执行权限，看来开发者也是和咱一样只知道无脑777的杂鱼呢。
在leds目录下有个TODO文件，然后看到一段离谱的留言：
```
* Command line utility to manipulate the LEDs?

/sys interface is not really suitable to use by hand, should we have
an utility to perform LED control?
```
好家伙，你还有脸说呢！！！
你倒是说说具体怎么用啊！！！
# 正式尝试：
## 找到接口位置：
好吧内核源码看不懂，咱来到user-space。
首先find|grep找到sysfs接口在`/sys/bus/i2c/drivers/aw20036_led/0-003a/leds/led_strips/`
（我不管我就要find配grep！！！）
我们进去：
```
.../leds/led_strips # cd /sys/bus/i2c/drivers/aw20036_led/0-003a/leds/led_strips/
.../leds/led_strips # ls
all_brightness        imax
all_white_brightness  max_brightness
always_on             operating_mode
brightness            power
dev_color             reg
device                single_brightness
effect                subsystem
factory_test          trigger
frame_brightness      uevent
hwen                  vip_notification
hwid
```
好吧这不是我熟悉的灯带驱动。
跟一代一点也不一样，或许不是同一个人写的。
## 尝试调用：
最后找到的方法不是一般人能想出来的，所以略过。
比较有意思的是`factory_test`这个文件，看名字用于工厂测试？不记得这灯品控差啊。不过和`all_brightness`作用几乎没太大差距。
## 查找原生调用方式：
`ps -A`大法没任何发现，遂使用`logcat`大法。
```
.../leds/led_strips # logcat|grep aw20036
（省略）
01-10 01:06:38.195  1481  1481 I aw20036_operating_mode_store: 1
01-10 01:06:38.198  1481  1481 I         : aw20036_ioctl LED_STRIPS_ALWAYS_ON
01-10 01:06:38.198  1481  1481 I aw20036_ioctl aw20036->always_on: 1
01-10 01:06:38.198  1481  1481 I aw20036_all_white_brightness_store: 160
01-10 01:06:39.014  1481  1481 I         : aw20036_ioctl LED_STRIPS_ALWAYS_ON
01-10 01:06:39.014  1481  1481 I aw20036_ioctl aw20036->always_on: 0
01-10 01:06:39.014  1481  1481 I aw20036_all_white_brightness_store: 0
01-10 01:06:39.517  1519  1519 I aw20036_operating_mode_store: 2
```
开关了下Glyph torch发现新增上述日志，看来灯带是pid 1481管的。
至于这个1481是什么呢？
```
.../leds/led_strips # cat /proc/1481/cmdline
/vendor/bin/hw/vendor.qti.hardware.lights.service
```
看来是和高通py的。。。
《和高通联合调教的灯带》。。。
好了直接上strace，去Glyph composer里随便点一下，反正让灯闪一下就是了，得到如下日志：
```c
.../leds/led_strips # strace -s 114514 -v -p 1481
strace: Process 1481 attached
ioctl(3, BINDER_WRITE_READ, 0x7fcb957048) = 0
getuid()                                = 1000
writev(4, [{iov_base="\0\311\5Q~\235e\341\356\321\r", iov_len=11}, {iov_base="\3", iov_len=1}, {iov_base="LightsExt\0", iov_len=10}, {iov_base="setLightFrame enter id:110 state:0x1 brightness:160 colorSize:33\n\0", iov_len=66}], 4) = 88
openat(AT_FDCWD, "/sys/devices/platform/soc/994000.i2c/i2c-0/0-003a/leds/led_strips/frame_brightness", O_WRONLY) = 15
openat(AT_FDCWD, "/sys/devices/platform/soc/994000.i2c/i2c-0/0-003a/leds/led_strips/operating_mode", O_RDONLY) = 16
read(16, "2", 1)                        = 1
close(16)                               = 0
getuid()                                = 1000
writev(4, [{iov_base="\0\311\5Q~\235eT\377\355\r", iov_len=11}, {iov_base="\3", iov_len=1}, {iov_base="LightsExt\0", iov_len=10}, {iov_base="setLightFrame mode:2\n\0", iov_len=22}], 4) = 44
openat(AT_FDCWD, "/sys/devices/platform/soc/994000.i2c/i2c-0/0-003a/leds/led_strips/operating_mode", O_WRONLY) = 16
write(16, "1\n", 2)                     = 2
close(16)                               = 0
write(15, "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ", 66) = 66
close(15)                               = 0
ioctl(3, BINDER_WRITE_READ, 0x7fcb957048) = 0
getuid()                                = 1000
writev(4, [{iov_base="\0\311\5Q~\235e \253\335\16", iov_len=11}, {iov_base="\3", iov_len=1}, {iov_base="LightsExt\0", iov_len=10}, {iov_base="setLightFrame enter id:110 state:0x1 brightness:160 colorSize:33\n\0", iov_len=66}], 4) = 88
openat(AT_FDCWD, "/sys/devices/platform/soc/994000.i2c/i2c-0/0-003a/leds/led_strips/frame_brightness", O_WRONLY) = 15
openat(AT_FDCWD, "/sys/devices/platform/soc/994000.i2c/i2c-0/0-003a/leds/led_strips/operating_mode", O_RDONLY) = 16
read(16, "1", 1)                        = 1
close(16)                               = 0
getuid()                                = 1000
writev(4, [{iov_base="\0\311\5Q~\235e\23\6\357\16", iov_len=11}, {iov_base="\3", iov_len=1}, {iov_base="LightsExt\0", iov_len=10}, {iov_base="setLightFrame mode:1\n\0", iov_len=22}], 4) = 44
write(15, "0 148 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ", 68) = 68
close(15)                               = 0
```
strace默认会折叠代码为省略号，所以需要手动设置最大长度（众所周知114514是一个经典大幻数）。
这样一来灯的调用方式一目了然了：
```sh
echo 1 > /sys/devices/platform/soc/994000.i2c/i2c-0/0-003a/leds/led_strips/operating_mode
printf "0 148 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 " > /sys/devices/platform/soc/994000.i2c/i2c-0/0-003a/leds/led_strips/frame_brightness
```
果然，摄像头左下角的灯亮了。
## 大胆假设：
点灯时先把`operating_mode`设置成1
这一串编码一样的东西代表了每个灯的亮度，更改每一位的数值可修改相应灯的亮度。
最大亮度依旧是`max_brightness`（255）
# 总结：
Nothing的驱动还是这么令人疑惑，接口说变就变，上一代的`single_led_br`控制接口说没就这么没了。。。
先睡了。