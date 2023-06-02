---
title: 浅谈android设备sysfs接口硬件调用之手电筒，马达，呼吸灯
date: 2023-04-19 13:59:40
tags:
  - Linux
  - Android
cover: /img/moe-sysfs.png
top_img: /img/moe-sysfs.png
---

迟来的更新喵～
这篇文章我们来介绍下几个sysfs接口的调用。需要注意的是，由于安卓内核碎片化过于严重，各个厂商之间的代码差异过大，因此直接和内核交互来调用驱动并不是一个通用思路。但是对于某些特定设备的驱动调用却是个简单可行的方法，比如nothing phone的灯带。
### 手电筒：
一般是个led类设备，小米10ultra的手电筒被注册到了/sys/class/leds/flashlight/下，当然也有部分设备叫led0或者其他，nothing的手电筒驱动猫猫还没找到，猫猫好笨喵呜～
目录中有两个文件对我们有用：brightness和max_brightness
max_brightness的内容是个固定值，定义了灯的最大亮度。
brightness的内容是个无符号整形数值，定义了灯的亮度，向其写入一个不大于max_brightness的合法数值，灯会亮，数越大灯越亮，写入0关闭手电筒。
什么你说怎么写？直接重定向覆盖进去就行了。
### 呼吸灯：
和手电筒差不多，一般在/sys/class/leds/white，当然也有彩色呼吸灯，控制文件和手电筒一样。
话说现在很少有带呼吸灯的手机了喵～
#### nothing phone 1的灯带：
算是个特大号呼吸灯？
它被注册到了/sys/class/leds/aw210xx_led下
*_br和video_leds_effect文件是控制灯的，其他文件还没研究也没太大必要研究。
首先有个文件max_brightness显然是定义亮度的最大值。
至于*_br可以写个脚本看看到底是干嘛的：
```sh
ls /sys/class/leds/aw210xx_led/|grep -E "led_br|leds_br"|grep -v leds_breath_set|while read i
do
printf "\a\033[36mcurrent: \033[32m$i\033[0m\n"
echo 400 > /sys/class/leds/aw210xx_led/$i
sleep 3s
echo 0 > /sys/class/leds/aw210xx_led/$i
done
```
然后是video_leds_effect
感觉这个貌似逻辑比较简单。
```sh
#开始闪烁指示灯
echo 1 > /sys/class/leds/aw210xx_led/video_leds_effect
#关闭
echo 0 > /sys/class/leds/aw210xx_led/video_leds_effect
```
（文章不够私货凑）
### 马达：
这东西的代码就更加碎片化了。
部分设备会写入/sys/class/timed_output/vibrator/enable
部分设备会写入/sys/class/leds/vibrator/duration后写入/sys/class/leds/vibrator/activate
其中duration设置震动长度，activate激活震动。
但很多使用线性马达的设备采用的并非统一节点,而是作为input设备，设备信息在/proc/bus/input/devices中，含有haptic字样的。
以下是对小米10ultra马达的研究：
查看/proc/bus/input/devices：
```text
I: Bus=0000 Vendor=0000 Product=0000 Version=0000
N: Name="aw8697_haptic"
P: Phys=
S: Sysfs=/devices/platform/soc/a8c000.i2c/i2c-2/2-005a/input/input3
U: Uniq=
H: Handlers=event3 
B: PROP=0
B: EV=200001
B: FF=120070000 0
```
进入目录/sys/devices/platform/soc/a8c000.i2c/i2c-2/2-005a/input/input3
进入device目录
```text
cas:/sys/devices/platform/soc/a8c000.i2c/i2c-2/2-005a/input/input3/device # ls
activate       auto_boost  cont          cont_td      driver     f0        f0_value  input           modalias  osc_cali  prctmode    ram_vbat_comp  seq        uevent        wakeup
activate_mode  bst_vol     cont_drv      cont_zc_thr  duration   f0_check  gain      loop            name      osc_save  ram         reg            subsystem  vbat_monitor
activate_test  cali        cont_num_brk  custom_wave  effect_id  f0_save   index     lra_resistance  of_node   power     ram_update  rtp            trig       vmax
cas:/sys/devices/platform/soc/a8c000.i2c/i2c-2/2-005a/input/input3/device # 
```
activate激活，duration设置时长，activate_mode设置震动模式，有0,1,3三种，0无法设置时长
```sh
echo 1 > activate_mode &&echo 10000 > duration&&echo 1 > activate 
```
想想都爽......想到哪去了啊喂（脸红）
nothing的驱动至今还没搞明白，就这样吧，下篇见喵（咕咕咕咕咕...........