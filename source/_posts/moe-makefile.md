---
title: 为小型C语言项目编写Makefile
date: 2023-12-29 16:28:08
cover: /img/makefile.png
top_img: /img/makefile.png
tags:
  - Linux
  - C语言
---
众所周知，C语言项目需要构建，而GNU make可谓是GNU/Linux下的正统构建管理工具了。不过由于咱之前写的Makefile太烂，所以这篇文章一直到最近有空重写ruri的Makefile后才出来。
本篇文章可能需要一定GCC/Clang基础，建议配合[在Linux下优雅的调试C语言](https://blog.crack.moe/2023/06/01/moe-c-lab/)与[Clang/GCC安全编译与代码优化选项（合集）](https://blog.crack.moe/2023/12/29/moe-harden/)食用。
本篇文章仅适用于GNU/Linux或Termux环境。
# 源码结构：
这里咱用的还是比较经典的结构，src放置源代码，src/include放置头文件，out用于放置生成的中间文件。最后将BIN_TARGET复制到源码根目录下。
clang-format文件需自备。
```
.
├── .clang-format
├── LICENSE
├── Makefile
├── hello
├── out
│   ├── hello.o
│   └── hello
├── README.md
└── src
    ├── include
    │   └── hello.h
    └── hello.c
```
# 实现的功能：
- 代码优化与加固
- 静态编译支持
- 代码静态检测
- 代码格式化
- GDB与ASAN调试工具支持
- 针对Termux（bionic）的特殊修复
# 命令详解：
```
  make all            #编译程序
  make install        #将程序安装到$PREFIX
  make static         #静态编译
  make static-bionic  #在Termux下静态编译
  make clean          #清理
  make dev            #构建GDB调试版本
  make asan           #构建内置ASAN的GDB调试版本
  make check          #运行静态检测
  make format         #格式化代码
```
# 代码：
C语言规范默认设置为GNU99，可视情况修改。
```Makefile
.NOTPARALLEL:
# Premature optimization is the root of evil.
CCCOLOR     = \033[1;38;2;254;228;208m
LDCOLOR     = \033[1;38;2;254;228;208m
STRIPCOLOR  = \033[1;38;2;254;228;208m
BINCOLOR    = \033[34;1m
ENDCOLOR    = \033[0m
CC_LOG = @printf '    $(CCCOLOR)CC$(ENDCOLOR) $(BINCOLOR)%b$(ENDCOLOR)\n'
LD_LOG = @printf '    $(LDCOLOR)LD$(ENDCOLOR) $(BINCOLOR)%b$(ENDCOLOR)\n'
STRIP_LOG = @printf ' $(STRIPCOLOR)STRIP$(ENDCOLOR) $(BINCOLOR)%b$(ENDCOLOR)\n'
CLEAN_LOG = @printf ' $(CCCOLOR)CLEAN$(ENDCOLOR) $(BINCOLOR)%b$(ENDCOLOR)\n'
# Compiler.
CC = clang
# Strip.
STRIP = strip
# Link-Time Optimization.
LTO = -flto
# Position-Independent Executables.
PIE = -fPIE
# No-eXecute.
NX = -z noexecstack
# Relocation Read-Only.
RELRO = -z now
# Stack Canary.
CANARY = -fstack-protector-all
# Stack Clash Protection.
CLASH_PROTECT = -fstack-clash-protection
# Shadow Stack.
SHADOW_STACK = -mshstk
# Fortified Source.
FORTIFY = -D_FORTIFY_SOURCE=3 -Wno-unused-result
# Other "one-key" optimization.
OPTIMIZE = -O2
# GNU Symbolic Debugger.
DEBUGGER = -ggdb
# Disable other optimizations.
NO_OPTIMIZE = -O0 -fno-omit-frame-pointer
# Disable Relocation Read-Only.
NO_RELRO = -z norelro
# Disable No-eXecute.
NO_NX = -z execstack
# Position Independent Executables.
NO_PIE = -no-pie
# Disable Stack Canary.
NO_CANARY = -fno-stack-protector
# Warning Options.
WALL = -Wall -Wextra -pedantic -Wconversion -Wno-newline-eof
# For production.
OPTIMIZE_CFLAGS = $(LTO) $(PIE) $(CANARY) $(CLASH_PROTECT) $(SHADOW_STACK) $(AUTO_VAR_INIT) $(FORTIFY) $(OPTIMIZE) $(STANDARD)
# Static link.
STATIC_CFLAGS = $(OPTIMIZE_CFLAGS) -static
# For Testing.
DEV_CFLAGS = $(DEBUGGER) $(NO_OPTIMIZE) $(NO_CANARY) $(WALL) $(STANDARD)
# AddressSanitizer.
ASAN_CFLAGS = $(DEV_CFLAGS) -fsanitize=address,leak -fsanitize-recover=address,all
SRC = src/*.c
HEADER = src/include/*.h
BIN_TARGET = hello
STANDARD = -std=gnu99 -Wno-gnu-zero-variadic-macro-arguments
# For `make fromat`.
FORMATER = clang-format -i
# For `make check`.
CHECKER = clang-tidy --use-color
# Unused checks are disabled.
CHECKER_FLAGS = --checks=*,-clang-analyzer-security.insecureAPI.strcpy,-altera-unroll-loops,-cert-err33-c,-concurrency-mt-unsafe,-clang-analyzer-security.insecureAPI.DeprecatedOrUnsafeBufferHandling,-readability-function-cognitive-complexity,-cppcoreguidelines-avoid-magic-numbers,-readability-magic-numbers,-bugprone-easily-swappable-parameters,-cert-err34-c
# For LD.
LD_FLAGS = $(NX) $(RELRO) -Wl,--build-id=sha1
DEV_LD_FLAGS = $(NO_RELRO) $(NO_NX) $(NO_PIE) -Wl,--build-id=sha1
# Fix issues in termux (with bionic).
BIONIC_FIX = -ffunction-sections -fdata-sections
BIONIC_CFLAGS = $(OPTIMIZE_CFLAGS) $(BIONIC_FIX)
BIONIC_LD_FLAGS = $(LD_FLAGS) -Wl,--gc-sections -Wl,--build-id=sha1
# Target.
objects = hello.o
O = out
.ONESHELL:
all :CFLAGS=$(OPTIMIZE_CFLAGS)
all :build_dir $(objects)
	@cd $(O)
	@$(CC) $(CFLAGS) -o $(BIN_TARGET) $(objects) $(LD_FLAGS)
	$(LD_LOG) $(BIN_TARGET)
	@$(STRIP) $(BIN_TARGET)
	$(STRIP_LOG) $(BIN_TARGET)
	@cp $(BIN_TARGET) ../
dev :CFLAGS=$(DEV_CFLAGS)
dev :build_dir $(objects)
	@cd $(O)
	$(LD_LOG) $(BIN_TARGET)
	@$(CC) $(CFLAGS) -o $(BIN_TARGET) $(objects) $(DEV_LD_FLAGS)
	@cp $(BIN_TARGET) ../
asan :CFLAGS=$(ASAN_CFLAGS)
asan :build_dir $(objects)
	@cd $(O)
	$(LD_LOG) $(BIN_TARGET)
	@$(CC) $(CFLAGS) -o $(BIN_TARGET) $(objects) $(DEV_LD_FLAGS)
	@cp $(BIN_TARGET) ../
static :CFLAGS=$(STATIC_CFLAGS)
static :build_dir $(objects)
	@cd $(O)
	$(LD_LOG) $(BIN_TARGET)
	@$(CC) $(CFLAGS) -o $(BIN_TARGET) $(objects) $(LD_FLAGS)
	$(STRIP_LOG) $(BIN_TARGET)
	@$(STRIP) $(BIN_TARGET)
	@cp $(BIN_TARGET) ../
static-bionic :CFLAGS=$(BIONIC_CFLAGS)
static-bionic :build_dir $(objects)
	@cd $(O)
	$(LD_LOG) $(BIN_TARGET)
	@$(CC) $(CFLAGS) -o $(BIN_TARGET) $(objects) $(BIONIC_LD_FLAGS)
	$(STRIP_LOG) $(BIN_TARGET)
	@$(STRIP) $(BIN_TARGET)
	@cp $(BIN_TARGET) ../
build_dir:
	@mkdir -p $(O)
$(objects) :%.o:src/%.c $(build_dir)
	@cd $(O)
	@$(CC) $(CFLAGS) -c ../$< -o $@
	$(CC_LOG) $@
install :all
	install -m 777 $(BIN_TARGET) ${PREFIX}/bin/$(BIN_TARGET)
check :
	@printf "\033[1;38;2;254;228;208mCheck list:\n"
	@sleep 1.5s
	@$(CHECKER) $(CHECKER_FLAGS) --list-checks $(SRC) -- $(DEV_CFLAGS)
	@printf ' \033[1;38;2;254;228;208mCHECK\033[0m \033[34;1m%b\033[0m\n' $(SRC)
	@$(CHECKER) $(CHECKER_FLAGS) $(SRC) -- $(DEV_CFLAGS)
	@printf ' \033[1;38;2;254;228;208mDONE.\n'
format :
	$(FORMATER) $(SRC) $(HEADER)
clean :
	$(CLEAN_LOG) $(O)
	@rm -f $(BIN_TARGET)||true
	@rm -rf $(O)||true
help :
	@printf "\033[1;38;2;254;228;208mUsage:\n"
	@echo "  make all            compile"
	@echo "  make install        install program to \$$PREFIX"
	@echo "  make static         static compile,with musl or glibc"
	@echo "  make static-bionic  static compile,with bionic"
	@echo "  make clean          clean"
	@echo "Only for developers:"
	@echo "  make dev            compile without optimizations, enable gdb debug information and extra logs."
	@echo "  make asan           enable ASAN"
	@echo "  make check          run clang-tidy"
	@echo "  make format         format code"
	@echo "*Premature optimization is the root of all evil."
```
# 后记：
又水了一篇文章喵～