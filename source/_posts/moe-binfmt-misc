---
title: 使用binfmt_misc和QEMU编写跨架构容器
date: 2024-01-17 22:45:03
cover: /img/binfmt.jpg
top_img: /img/binfmt.jpg
tags:
- Linux
- C语言
- Container
---
# 此篇文章尚未完善，备份下明天再写。。。
经过“非常简单”的开发过程，咱终于把binfmt_misc支持加入了ruri新版本中：
```diff
 17 files changed, 562 insertions(+), 60 deletions(-)
```
可以看到修改并不多，嗯。
实际上很多修改并不涉及核心内容的（心虚）
好了我们还是来讲讲binfmt_misc的应用吧：
首先我们要挂载binfmt_misc接口:
```C
mount("binfmt_misc", "/proc/sys/fs/binfmt_misc", "binfmt_misc", 0, NULL);
```
然后是它的注册方式：
向`/proc/sys/fs/binfmt_misc/register`写入如下数据：
```
:name:type:offset:magic:mask:interpreter:flags
```
其中name是名称，magic和mask是ELF二进制的特征，interpreter对应qemu的路径。
写成C语言：
```C
static void setup_binfmt_misc(const char *cross_arch, const char *qemu_path)
{
        // Get elf magic header.
        struct MAGIC *magic = get_magic(cross_arch);
        char buf[1024] = { '\0' };
        // Format: ":name:type:offset:magic:mask:interpreter:flags".
        sprintf(buf, ":%s%s:M:0:%s:%s:%s:OC", "ruri-", cross_arch, magic->magic, magic->mask, qemu_path);
        // Just to make clang-tidy happy.
        free(magic);
        // This needs CONFIG_BINFMT_MISC enabled in your kernel.
        int register_fd = open("/proc/sys/fs/binfmt_misc/register", O_WRONLY | O_CLOEXEC);
        if (register_fd < 0) {
                error("\033[31mError: Failed to setup binfmt_misc, check your kernel config QwQ");
        }
        // Set binfmt_misc config.
        write(register_fd, buf, strlen(buf));
}
```
```C
/* ELF magic header and mask for binfmt_misc & QEMU. */
#define aarch64_magic        "\\x7f\\x45\\x4c\\x46\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\xb7\\x00"
#define alpha_magic          "\\x7f\\x45\\x4c\\x46\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x26\\x90"
#define arm_magic            "\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x28\\x00"
#define armeb_magic          "\\x7f\\x45\\x4c\\x46\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x28"
#define cris_magic           "\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x4c\\x00"
#define hexagon_magic        "\\x7fELF\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\xa4\\x00"
#define hppa_magic           "\\x7f\\x45\\x4c\\x46\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x0f"
#define i386_magic           "\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x03\\x00"
#define loongarch64_magic    "\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x02\\x01"
#define m68k_magic           "\\x7f\\x45\\x4c\\x46\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x04"
#define microblaze_magic     "\\x7f\\x45\\x4c\\x46\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\xba\\xab"
#define mips_magic           "\\x7fELF\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x08\\x00\\x00\\x00\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00"
#define mips64_magic         "\\x7f\\x45\\x4c\\x46\\x02\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x08"
#define mips64el_magic       "\\x7f\\x45\\x4c\\x46\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x08\\x00"
#define mipsel_magic         "\\x7fELF\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x08\\x00\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00"
#define mipsn32_magic        "\\x7fELF\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x08\\x00\\x00\\x00\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x20"
#define mipsn32el_magic      "\\x7fELF\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x08\\x00\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x20\\x00\\x00\\x00"
#define ppc_magic            "\\x7f\\x45\\x4c\\x46\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x14"
#define ppc64_magic          "\\x7f\\x45\\x4c\\x46\\x02\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x15"
#define ppc64le_magic        "\\x7f\\x45\\x4c\\x46\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x15\\x00"
#define riscv32_magic        "\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\xf3\\x00"
#define riscv64_magic        "\\x7f\\x45\\x4c\\x46\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\xf3\\x00"
#define s390x_magic          "\\x7f\\x45\\x4c\\x46\\x02\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x16"
#define sh4_magic            "\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x2a\\x00"
#define sh4eb_magic          "\\x7f\\x45\\x4c\\x46\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x2a"
#define sparc_magic          "\\x7f\\x45\\x4c\\x46\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x02"
#define sparc32plus_magic    "\\x7f\\x45\\x4c\\x46\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x12"
#define sparc64_magic        "\\x7f\\x45\\x4c\\x46\\x02\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x2b"
#define x86_64_magic         "\\x7f\\x45\\x4c\\x46\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x3e\\x00"
#define xtensa_magic         "\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x5e\\x00"
#define xtensaeb_magic       "\\x7f\\x45\\x4c\\x46\\x01\\x02\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x5e"
#define aarch64_mask         "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define alpha_mask           "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define arm_mask             "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define armeb_mask           "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define cris_mask            "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define hexagon_mask         "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define hppa_mask            "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define i386_mask            "\\xff\\xff\\xff\\xff\\xff\\xfe\\xfe\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define loongarch64_mask     "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define m68k_mask            "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define microblaze_mask      "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define mips_mask            "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x20"
#define mips64_mask          "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define mips64el_mask        "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define mipsel_mask          "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x20\\x00\\x00\\x00"
#define mipsn32_mask         "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x20"
#define mipsn32el_mask       "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x20\\x00\\x00\\x00"
#define ppc_mask             "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define ppc64_mask           "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define ppc64le_mask         "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\x00"
#define riscv32_mask         "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define riscv64_mask         "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define s390x_mask           "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define sh4_mask             "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define sh4eb_mask           "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define sparc_mask           "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define sparc32plus_mask     "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define sparc64_mask         "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
#define x86_64_mask          "\\xff\\xff\\xff\\xff\\xff\\xfe\\xfe\\xfc\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define xtensa_mask          "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff"
#define xtensaeb_mask        "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff"
// For get_magic().
#define magicof(x) (x##_magic)
#define maskof(x) (x##_mask)
struct MAGIC {
	char *magic;
	char *mask;
};
```
```C
// Get ELF magic number and mask for cross_arch specified.
struct MAGIC *get_magic(const char *cross_arch)
{
	struct MAGIC *ret = (struct MAGIC *)malloc(sizeof(struct MAGIC));
	if (strcmp(cross_arch, "aarch64") == 0) {
		ret->magic = magicof(aarch64);
		ret->mask = maskof(aarch64);
	} else if (strcmp(cross_arch, "alpha") == 0) {
		ret->magic = magicof(alpha);
		ret->mask = maskof(alpha);
	} else if (strcmp(cross_arch, "arm") == 0) {
		ret->magic = magicof(arm);
		ret->mask = maskof(arm);
	} else if (strcmp(cross_arch, "armeb") == 0) {
		ret->magic = magicof(armeb);
		ret->mask = maskof(armeb);
	} else if (strcmp(cross_arch, "cris") == 0) {
		ret->magic = magicof(cris);
		ret->mask = maskof(cris);
	} else if (strcmp(cross_arch, "hexagon") == 0) {
		ret->magic = magicof(hexagon);
		ret->mask = maskof(hexagon);
	} else if (strcmp(cross_arch, "hppa") == 0) {
		ret->magic = magicof(hppa);
		ret->mask = maskof(hppa);
	} else if (strcmp(cross_arch, "i386") == 0) {
		ret->magic = magicof(i386);
		ret->mask = maskof(i386);
	} else if (strcmp(cross_arch, "loongarch64") == 0) {
		ret->magic = magicof(loongarch64);
		ret->mask = maskof(loongarch64);
	} else if (strcmp(cross_arch, "m68k") == 0) {
		ret->magic = magicof(m68k);
		ret->mask = maskof(m68k);
	} else if (strcmp(cross_arch, "microblaze") == 0) {
		ret->magic = magicof(microblaze);
		ret->mask = maskof(microblaze);
	} else if (strcmp(cross_arch, "mips") == 0) {
		ret->magic = magicof(mips);
		ret->mask = maskof(mips);
	} else if (strcmp(cross_arch, "mips64") == 0) {
		ret->magic = magicof(mips64);
		ret->mask = maskof(mips64);
	} else if (strcmp(cross_arch, "mips64el") == 0) {
		ret->magic = magicof(mips64el);
		ret->mask = maskof(mips64el);
	} else if (strcmp(cross_arch, "mipsel") == 0) {
		ret->magic = magicof(mipsel);
		ret->mask = maskof(mipsel);
	} else if (strcmp(cross_arch, "mipsn32") == 0) {
		ret->magic = magicof(mipsn32);
		ret->mask = maskof(mipsn32);
	} else if (strcmp(cross_arch, "mipsn32el") == 0) {
		ret->magic = magicof(mipsn32el);
		ret->mask = maskof(mipsn32el);
	} else if (strcmp(cross_arch, "ppc") == 0) {
		ret->magic = magicof(ppc);
		ret->mask = maskof(ppc);
	} else if (strcmp(cross_arch, "ppc64") == 0) {
		ret->magic = magicof(ppc64);
		ret->mask = maskof(ppc64);
	} else if (strcmp(cross_arch, "ppc64le") == 0) {
		ret->magic = magicof(ppc64le);
		ret->mask = maskof(ppc64le);
	} else if (strcmp(cross_arch, "riscv32") == 0) {
		ret->magic = magicof(riscv32);
		ret->mask = maskof(riscv32);
	} else if (strcmp(cross_arch, "riscv64") == 0) {
		ret->magic = magicof(riscv64);
		ret->mask = maskof(riscv64);
	} else if (strcmp(cross_arch, "s390x") == 0) {
		ret->magic = magicof(s390x);
		ret->mask = maskof(s390x);
	} else if (strcmp(cross_arch, "sh4") == 0) {
		ret->magic = magicof(sh4);
		ret->mask = maskof(sh4);
	} else if (strcmp(cross_arch, "sh4eb") == 0) {
		ret->magic = magicof(sh4eb);
		ret->mask = maskof(sh4eb);
	} else if (strcmp(cross_arch, "sparc") == 0) {
		ret->magic = magicof(sparc);
		ret->mask = maskof(sparc);
	} else if (strcmp(cross_arch, "sparc32plus") == 0) {
		ret->magic = magicof(sparc32plus);
		ret->mask = maskof(sparc32plus);
	} else if (strcmp(cross_arch, "sparc64") == 0) {
		ret->magic = magicof(sparc64);
		ret->mask = maskof(sparc64);
	} else if (strcmp(cross_arch, "x86_64") == 0) {
		ret->magic = magicof(x86_64);
		ret->mask = maskof(x86_64);
	} else if (strcmp(cross_arch, "xtensa") == 0) {
		ret->magic = magicof(xtensa);
		ret->mask = maskof(xtensa);
	} else if (strcmp(cross_arch, "xtensaeb") == 0) {
		ret->magic = magicof(xtensaeb);
		ret->mask = maskof(xtensaeb);
	} else {
		error("\033[31mError: unknow architecture: %s\nSupported architectures: aarch64, alpha, arm, armeb, cris, hexagon, hppa, i386, loongarch64, m68k, microblaze, mips, mips64, mips64el, mipsel, mipsn32, mipsn32el, ppc, ppc64, ppc64le, riscv32, riscv64, s390x, sh4, sh4eb, sparc, sparc32plus, sparc64, x86_64, xtensa, xtensaeb\n", cross_arch);
	}
	return ret;
}
```
可以看到非常简单。
