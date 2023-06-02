---
title: 沨鸾的Shell小技巧
date: 2022-12-04 02:56:57
tags:
  - Linux
  - Shell
  - Termux
top_img: /img/cover.jpg
cover: /img/cover.jpg
---
欢迎来到猫猫的Shell实验室喵！
跟着沨鸾学shell，学到最后只会喵喵喵。 
文章非入门教程，不要妄想本猫亲自教你基础知识，哼！ 
生草部分也会包含有一些花式操作。
本文不定期更新。 
## 正经部分：
### 语法规范：
变量要加{}括起来。
函数最好加个function关键字。
头部一定要有释伴(shebang)。
记得写注释，要不然也就上帝能看懂你写的什么了。
退出时要有返回状态。
能用[[]]就别用[]。
尽量用printf代替echo使用以提供更好的兼容性。
没用的输出记得丢弃。
\> /dev/null丢不掉就2>&1 > /dev/null。
不要定义太复杂的架构，比如函数互相调用。
当然猫猫基本没怎么遵守过。
### 三元表达式：
比如你想要这样一段的功能：
```sh
if [[ $x == 1 ]];then
  echo test
else
  echo fail
fi
```
你可以这么写：
```sh
([[ $x == 1 ]]&&echo test)||echo fail
```
测试一下：
```sh
x=0
([[ $x == 1 ]]&&echo test)||echo fail
x=1
([[ $x == 1 ]]&&echo test)||echo fail
```
当然，在写脚本时你会遇到很多个这样的判等，我们不妨直接封装：
```sh
is_value(){
  ([[ $1 == $2 ]]&&return 0)||return 1
}
(is_value 1 2&&echo test)||echo fail
(is_value 1 1&&echo test)||echo fail
```
水代码又少了一个理由。
等下语法规范呢？
遵守是不可能遵守的了。。。
### 三元表达式+：
比如你想要这一段的功能：
```sh
if [[ $x == 1 ]];then
  echo 1
elif [[ $x == 2 ]];then
  echo 2
else
  echo fail
fi
```
你可以写成这样：
```sh
([[ $x == 1 ]]&&echo 1)||([[ $x == 2 ]]&&echo 2)||echo fail
```
看你写的代码的人会感谢你的。
### 最高端的输出颜色自定义：
使用rgb代码定义输出颜色。
```
\033[1;38;2;R;G;Bm
```
比如moe-container里的这行：
```C
printf("\033[1;38;2;254;228;208mUsage:\n");
```
当然这是C语言。
等下这是shell技巧……对吧。 
### 输出居中：
首先你得知道要居中的输出有多长。
然后：
```sh
WIDTH=$(($(($(stty size|awk '{print $2}')))/2-居中字符长度的一半))
echo -e "\033[${WIDTH}C内容"
```
除了花哨点也没啥大用。
### 输出一行分割线：
```sh
WIDTH=$(stty size|awk '{print $2}')
echo $(yes "="|sed $WIDTH'q'|tr -d '\n')
```
当然可以玩的更花哨一点：
```sh
WIDTH=$(stty size|awk '{print $2}')
WIDTH=$((WIDTH/2-2))
echo "$(yes "="|sed $WIDTH'q'|tr -d '\n')xxxx$(yes "="|sed $WIDTH'q'|tr -d '\n')"
```
$WIDTH定义参照上一条。
或者像termux-container里这样：
```sh
WIDTH=$(stty size|awk '{print $2}')
WIDTH=$((WIDTH-13))
echo -e "\e[30;48;5;159mCONTAINER_RUN$(yes " "|sed $WIDTH'q'|tr -d '\n')\033[0m"
```
莫名科技感。
### sed正则匹配：
```
echo 123abc > test
sed -i "s/[0-9]*/数字替换/" test
cat test
```
正则表达式具体内容请自行利用搜索引擎。
想当年猫猫要是会用，termux-container里的屎山也能少点。
### 更改光标样式：
```sh
printf '\e[2 q'
printf '\e[6 q'
printf '\e[4 q'
```
仅在termux验证成功过。
### Ctrl+D信号捕获：
不是说好EOF不是信号的吗？
事实上read可以捕获。
read无论读到什么东西加回车都会将结果记录并正常退出。
但是，读到EOF却未换行会返回1。
可以read后用$?的值是否为0来作为条件进行捕获。
当然read逐字读取时不适用，但是我们还有方法专门针对逐字读取：
```sh
while :; do read -N 1 key&&if [[ ${key} == $(printf "\004") ]];then echo CTRL-D;fi; done
```
似乎挺没用的。
(termux-container将会利用这一特性)
### 网易云歌曲名称格式化：
网易云默认下载的音乐命名格式是这样的：
```
Akie秋绘 - なんでもないや 没什么大不了的（翻自 Radwimps）.mp3
ENE - パズル.mp3
Hanser - 勾指起誓.mp3
のぶなが - 深海少女.mp3
南杉 - 樱花樱花想见你.mp3
鹿乃 - 小夜子.mp3
鹿乃 - 心拍数#0822.mp3
鹿乃 - 桜のような恋でした.mp3
```
(浓度过纯)
咱们可以这样：
```sh
ls *.mp3|while read music
do
artist=${music%% -*}
name=${music##*-\ }
name=${name%%.mp3}
name=${name%%"（"*}
name=${name%%"("*}
mv "$music" "$name-[$artist].mp3"
done
```
于是文件名就成了这样：
```
なんでもないや 没什么大不了的-[Akie秋绘].mp3
パズル-[ENE].mp3
勾指起誓-[Hanser].mp3
深海少女-[のぶなが].mp3
樱花樱花想见你-[南杉].mp3
小夜子-[鹿乃].mp3
心拍数#0822-[鹿乃].mp3
桜のような恋でした-[鹿乃].mp3
```
个人感觉好看多了。
### 用Shell写代码：
(怕是人家shell自己写的代码都比你规范)
moe-container里有这样一段头文件：
```C
#define DROP_CAP_SYS_ADMIN 1
#define DROP_CAP_SYS_MODULE 1
#define DROP_CAP_SYS_RAWIO 1
#define DROP_CAP_SYS_PACCT 1
#define DROP_CAP_SYS_NICE 1
#define DROP_CAP_SYS_RESOURCE 1
#define DROP_CAP_SYS_TTY_CONFIG 1
………………
```
可以看到#define DROP_和后面的1都是重复的
于是我们可以单独写一个caplist文件来记录那些不同的部分：
```
CAP_SYS_ADMIN
CAP_SYS_MODULE
CAP_SYS_RAWIO
CAP_SYS_PACCT
CAP_SYS_NICE
CAP_SYS_RESOURCE
CAP_SYS_TTY_CONFIG
```
然后：
```sh
cat caplist|while read cap
do
echo "#define DROP_${cap} 1"
done
```
事实上这一段：
```C
    if(DROP_CAP_SYS_ADMIN == 1){
      cap_drop_bound(CAP_SYS_ADMIN);
    }
    if(DROP_CAP_SYS_MODULE == 1){
      cap_drop_bound(CAP_SYS_MODULE);
    }
    if(DROP_CAP_SYS_RAWIO == 1){
      cap_drop_bound(CAP_SYS_RAWIO);
    }
………………
```
是这么生成的：
```sh
cat caplist|while read cap
do
echo "    if(DROP_$cap==1){\n      cap_drop_bound($cap);\n    }"
done
```
非常规范，非常工整。
C语言实现了shell，shell可以生成简单重复的C语言代码，双向奔赴，非常美好。
### 萌新代码生成：
```sh
x(){
echo -e "number=input(\"请输入一个数字:\")"
echo -e "if number == 0:\n    print(\"0是一个偶数\")"
for i in {1..114514}
do
[[ $(($i%2)) == 0 ]]&&echo -e "elif number == $i:\n    print(\"$i是一个偶数\")"||echo -e "elif number == $i:\n    print(\"$i是一个奇数\")"
done
echo -e "else:\n    print(\"数太大了我还不会\")"
}
x > 1.py
```
逝python，但是运行会直接内存错误。
## 生草部分：
### 变量当函数/命令名执行：
```sh
test(){
  $1
}
test ls
```
不做类型检查你就可以为所欲为了是吧。
### 忽略Ctrl+C：
用户别想用Ctrl+C杀死你的进程(大草)。
```sh
trap "" SIGINT
```
### 用shell实现一个shell：
一个shell要有：
- 指令解析
- 不能被ctrl-c杀死
- ctrl-d后会退出
- 上下键显示命令历史记录
- 命令历史记录可编辑

没问题，都安排上。
(代码部分判断依赖于hexdump)
SHELL_CONSOLE()函数建议照抄，原本是以Apache2协议开源的，不过猫猫也不介意用MIT协议在这里重复开源一遍：
```sh
SHELL_CONSOLE(){
  HISTORY=0
  COMMAND=""
  while :
  do
    HISTORY_LINES=$(awk 'END{print NR}' $HOME/.shell_history)
    HISTORY_LINES=$(( ${HISTORY_LINES}-1))
    SIZE=$(stty size|awk '{printf $2}')
    stty erase '^?'
    printf "${COLOR}"
    printf "\033[?25l"
    printf "\r"
    printf "\033[1G$(yes " "|sed $SIZE'q'|tr -d '\n')"
    printf "\033[1GConsole > ${COMMAND}"
    printf "\033[?25h"
    read -s -N1 COMMAND0
    if [[ ${COMMAND0} == $(echo -e "\004") ]];then
      echo -e "\n\nExit.\033[0m"&&exit
    fi
    if [[ $(echo ${COMMAND0}|hexdump|head -n1|awk '{print $2}') == "000a" ]]&&[[ ${COMMAND0} != " " ]];then
      echo
      SHELL_CONSOLE_MAIN ${COMMAND}
      COMMAND=""
      continue
    fi
    if [[ $(echo ${COMMAND0}|hexdump|head -n1|awk '{print $2}') == "0a7f" ]];then
      COMMAND=${COMMAND%?}
      continue
    elif [[ $(echo ${COMMAND0}|hexdump|head -n1|awk '{print $2}') == "0a08" ]];then
      COMMAND=${COMMAND%?}
      continue
    elif [[ ${COMMAND0} == $(printf "\033") ]];then
      read -s -N 2 COMMAND1
      if [[ ${COMMAND1} == "[A" ]];then
        if (($HISTORY <= ${HISTORY_LINES}));then
          HISTORY=$(($HISTORY+1))
        fi
        COMMAND=$(cat $HOME/.shell_history|tail -${HISTORY}|head -n1)
        continue
      elif [[ ${COMMAND1} == "[B" ]];then
        if (($HISTORY >= 2));then
          HISTORY=$(($HISTORY-1))
        fi
        COMMAND=$(cat $HOME/.shell_history|tail -${HISTORY}|head -n1)
        continue
      else
        continue
      fi
    else
      COMMAND+=${COMMAND0}
      continue
    fi
  done
}
```
这段代码是优化过的，原来那段简直是黑历史喵！！！
作用是获取命令并传递给SHELL_CONSOLE_MAIN函数进行解析。
于是你只需要自己写一个SHELL_CONSOLE_MAIN函数，大概长这样(从termux-container v9复制过来的)：
```sh
SHELL_CONSOLE_MAIN(){
  if [[ $1 != "" ]];then
    echo $@ >> $HOME/.shell_history
  fi
  case $1 in
    "help") SHOW_HELPS;;
    "search") SEARCH_IMAGES $2 $3;;
    "login") RUN_CONTAINER $2;;
    "pull") PULL_ROOTFS $2 $3 $4;;
    "import") IMPORT_ROOTFS $2;;
    "export") EXPORT_CONTAINER $2;;
    "new") CONTAINER_NEW;;
    "ls") LIST;;
    "exit") echo -e "\nExit.\033[0m"&&exit;;
    "rm") REMOVE_CONTAINER $2;;
    "cp") CONTAINER_CP $2 $3;;
    "") return;;
    *) echo -e "\033[31mError: Unknow command \`$@\`,type \`help\` to show helps.\033[0m${COLOR}"
  esac
}
```
最后在这段shell的头部加上：
```sh
trap "echo&&SHELL_CONSOLE" SIGINT
RGB="254;228;208"
COLOR="\033[1;38;2;${RGB}m"
```
第一行可以确保shell不被杀死，每次收到ctrl-c信号都会终止当前命令并跳转到SHELL_CONSOLE。
二三行是shell输出颜色的定义，为rgb十进制值。
在尾部调用一下SHELL_CONSOLE函数，就完了。
### 仿windows安装界面用户许可：
没啥好说的，直接上代码就是了：
```sh
trap "printf '\033[?25h'&&exit" SIGINT
RGB="254;228;208"
COLOR="\033[1;38;2;${RGB}m"
WIDTH=$(stty size|awk '{print $2}')
HEIGHT=$(stty size|awk '{print $1}')
HEIGHT=$(($HEIGHT-4))
clear
echo -e "${COLOR}\033[?25l╔$(yes "═"|sed $(($WIDTH-2))'q'|tr -d '\n')╗"
printf "║ \033[1;31m○ \033[1;33m○ \033[1;32m○${COLOR}\033[${WIDTH}G║\n"
echo -e "\033[?25l║$(yes "═"|sed $(($WIDTH-2))'q'|tr -d '\n')║"
printf "║  TERMUX-CONTAINER\033[${WIDTH}G║\n"
i=2
while (( $i<=$HEIGHT ));do
i=$(($i+1))
printf "║\033[${WIDTH}G║\n"
done
printf "\033[$(($HEIGHT+4));1H╚$(yes "═"|sed $(($WIDTH-2))'q'|tr -d '\n')╝"
printf "\033[$(($HEIGHT));4H╚$(yes "═"|sed $(($WIDTH-8))'q'|tr -d '\n')╝"
WIDTH=$(($WIDTH-5))
WIDTH_=$(($WIDTH+2))
printf "\033[10;4H║\033[${WIDTH}G\033[1;48;2;114;114;114;38;2;0;0;0m/\\ \033[0m${COLOR}\033[${WIDTH_}G║\n"
printf "\033[11;4H║\033[${WIDTH}G\033[1;48;2;66;66;66m  \033[0m${COLOR}║\n"
WIDTH=$(($WIDTH+5))
i=11
HEIGHT=$(($HEIGHT-3))
WIDTH=$(($WIDTH-5))
while (( $i<=$HEIGHT ));do
i=$(($i+1))
printf "\033[${i};4H║\033[${WIDTH}G\033[1;48;2;114;114;114m  \033[0m${COLOR}║\n"
done
i=$(($i+1))
printf "\033[${i};4H║\033[${WIDTH}G\033[1;48;2;114;114;114;38;2;0;0;0m\\/\033[0m${COLOR}║\n"
printf "\033[9;4H╔$(yes "═"|sed $(($WIDTH-3))'q'|tr -d '\n')╗"
echo -e "\033[7;5H适用的声明和许可条款"
WIDTH=$(($WIDTH-26))
echo -e "\033[10;${WIDTH}H最后更新日期：2022年12月"
echo -e "\033[11;7Htermux-container许可条款:"
echo -e "\033[13;7H本程序以Apache2.0协议授权。"
echo -e "\033[14;7H参见：\033[4mhttp://www.apache.org/licenses/\033[0m${COLOR}"
echo -e "\033[15;7H您至少需要了解以下几点："
echo -e "\033[17;7H  ● 本程序\`无担保\`。"
echo -e "\033[18;7H  ● \`任何\`由本程序带来的\`任何形式的\`损失，作者概不负责。"
echo -e "\033[19;7H  ● 您应当在遵守当地法律规定的前提下使用本程序。"
echo -e "\033[20;7H  ● \`任何\`由本程序带来的\`任何形式的\`法律责任，作者概不负责。"
echo -e "\033[21;7H  ● 本程序作者保留其著作权，严禁在不遵循其许可的情况下二次分发。"
echo -e "\033[${HEIGHT};7H Copyright 2022 Moe-hacker"
HEIGHT=$(($HEIGHT+5))
echo -e "\033[${HEIGHT};7H \033[1;32m[✓]\033[0m${COLOR} 我已阅读并接受许可条款 ， 按回车键同意"
HEIGHT=$(($HEIGHT+2))
printf "\033[${HEIGHT};1H"
read
printf "\033[?25h\033[0m"
touch $PREFIX/share/termux-container/licenses.allowed
clear
```
运行效果自行测试。

<p align="center">本文著作权归Moe-hacker所有</p>
<p align="center">copyright (©) 2022 Moe-hacker</p>

