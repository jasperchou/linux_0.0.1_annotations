#
# Makefile for linux.
# If you don't have '-mstring-insns' in your gcc (and nobody but me has :-)
# remove them from the CFLAGS defines.
#
#8086汇编编译器和连接器. -0生成8086目标程序;-a生成与gas和gld部分兼容的代码
AS86	=as -0 -a
CC86	=cc -0
LD86	=ld -0

#GNU汇编编译器和连接器
AS	=gas
LD	=gld

#GNU连接器gld运行时用到的选项
#-s 输出文件中省略所有的符号信息
#-x 删除所有的局部符号
#-M 在标准输出设备(显示器)上打印连接映象(link map).
#连接映象:由连接程序产生的一种内存地址映象，其中列出了程序装入到内存中的位置信息，具体有如下信息：
#目标文件及符号信息映射到内存中的位置
#公共符号如何放置
#连接中包含的所有文件成员及其引用的符号
LDFLAGS	=-s -x -M

#gcc是GNU C程序编译器，对于UNIX类的脚本程序而言，
#在引用定义的标识符时，需在前面加上$符号并用括号括住标识符
CC	=gcc
#GCC的选项.
#-Wall 打印所有的警告信息
#-O 对代码进行优化
#-fstrength-reduce 优化循环语句
CFLAGS	=-Wall -O -fstrength-reduce -fomit-frame-pointer -fcombine-regs

#CPP是gcc的预处理程序
#-nostdinc -Iinclude 不要搜索标准的头文件目录中的文件，
#而是使用-I选项指定的目录或者是在当前的目录里搜索头文件
CPP	=gcc -E -nostdinc -Iinclude

# kernel目录,mm目录,fs目录所产生的目标代码文件。
# 为了方便引用，在这里将它们用ARCHIVES(归档文件)标识符表示
ARCHIVES=kernel/kernel.o mm/mm.o fs/fs.o
# 由lib/目录中生成的通用库文件
LIBS	=lib/lib.a

# make隐式后缀规则
# 指示make利用下面的命令将所有的.c文件编译生成.s汇编程序
# ':'表示下面是该规则的命令
# 规则：指使gcc采用前面CFLAGS所指定的选项以及仅使用include/目录中的头文件，
# 在适当的编译后不进行汇编就停止(-S)，从而产生与输入的各个C文件对应的汇编语言形式的代码文件。
# 默认情况下所产生的汇编程序文件是原C文件名去掉.c而加上.s后缀。
# -o表示其后是输出文件的形式。
# 其中$*.s(或$@)是自动目标变量,$<代表第一个先决条件，这里即是符合条件*.c的文件。
.c.s:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -S -o $*.s $<
# 将所有.s汇编程序文件编译成.o目标文件。下一条是实现该操作的具体命令
# 使用gas编译器将汇编程序编译成.o目标文件。-c表示只编译或汇编，但不进行连接操作
.s.o:
	$(AS) -c -o $*.o $<
# 使用gcc将c语言编译成目标文件但不连接
.c.o:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -c -o $*.o $<

# all表示创建Makefile所知的最顶层目标。这里即是image文件
all:	Image
# 第一行说明：目标文件(Image文件)是由分号后面的3个元素产生
# 下面两行是执行的命令
# 第一行表示使用tools目录下的build工具程序将boot,system文件组装成内核映象文件Image
# 第二行的sysn同步命令是迫使缓冲块数据立即写盘并更新超级块
Image: boot/boot tools/system tools/build
	tools/build boot/boot tools/system > Image
	sync

tools/build: tools/build.c
	$(CC) $(CFLAGS) \
	-o tools/build tools/build.c
	chmem +65000 tools/build

# 利用上面的.s.o规则生成head.o文件
boot/head.o: boot/head.s

# 最后的>System.map表示gld需要将连接映象重定向存放在System.map文件中
tools/system:	boot/head.o init/main.o \
		$(ARCHIVES) $(LIBS)
	$(LD) $(LDFLAGS) boot/head.o init/main.o \
	$(ARCHIVES) \
	$(LIBS) \
	-o tools/system > System.map
# 内核目标模块kernel.o
kernel/kernel.o:
	(cd kernel; make)
# 内核管理模块mm.o
mm/mm.o:
	(cd mm; make)
# 文件系统目标模块fs.o
fs/fs.o:
	(cd fs; make)
# 库函数lib.a
lib/lib.a:
	(cd lib; make)
# 在boot.s程序开口添加一行有关system文件长度信息
# 首先生成含有 "SYSSIZE = 文件实际长度"一行信息的tmp.s文件，然后将boot.s文件添加在其后。
# 取得system长度的方法是：
# 利用ls命令对system文件进行长列表显示
# 用grep命令取得列表上文件字节数字段信息，并定向保存在tmp.s临时文件中
# cut命令用于剪切字符串
# tr用于去除行尾的回车符
# (实际长度 + 15)/16用于获得'节'表示的长度信息，1节=16字节
# 用8086汇编和连接器对setup.s文件进行编译生成setup文件
# -s表示要取出目标文件中的符号信息
#
boot/boot:	boot/boot.s tools/system
	(echo -n "SYSSIZE = (";ls -l tools/system | grep system \
		| cut -c25-31 | tr '\012' ' '; echo "+ 15 ) / 16") > tmp.s
	cat boot/boot.s >> tmp.s
	$(AS86) -o boot/boot.o tmp.s
	rm -f tmp.s
	$(LD86) -s -o boot/boot boot/boot.o
# 当执行"make clean"时，就会执行以下命令，去除所有编译连接生成的文件
# "rm"是文件删除命令，选项-f含义是忽略不存在的文件，并且不显示删除信息
# (cd mm;make clean)表示进入mm/目录，执行该目录Makefile文件中的clean规则
#
clean:
	rm -f Image System.map tmp_make boot/boot core
	rm -f init/*.o boot/*.o tools/system tools/build
	(cd mm;make clean)
	(cd fs;make clean)
	(cd kernel;make clean)
	(cd lib;make clean)
# 该规则首先执行上面的clean规则，然后对linux/目录进行压缩，生成backup.Z压缩文件。
# "cd .."表示退到linux/的上一级(父)目录
# "tar cf - linux"表示对linux/目录执行tar归档程序，-cf表示需要创建新的归档文件
# "| compress -"表示将tar程序的执行通过管道操作('|')传递给压缩程序compress，并将压缩程序的输
#出存成backup.Z文件
# sysn同步命令迫使缓冲块数据立即写盘并更新超级块
backup: clean
	(cd .. ; tar cf - linux | compress16 - > backup.Z)
	sync

# 该规则用于各文件的依赖关系。创建这些依赖关系是为了给make用来确定是否需要重建一个目标对象
# 比如当某个文件头被改动过后，make就通过生成的依赖关系，重新编译与该头文件有关的所有*.c文件。
# 具体方法如下：
# 使用字符串编辑程序sed对Makefile文件(这里即是自己)进行处理，
# 输出为删除Makefile文件中"### Dependencies"行后面的所有行，并生成tmp_make临时文件
# 然后对init/目录下的每一个C文件(其实只有一个C文件main.c)执行gcc预处理操作
# -M标志告诉预处理程序输出描述每个目标文件相关性的规则，并且这些规则符合make语法
# 对于每一个源文件，预处理程序输出一个make规则，其结果形式是相应源程序文件的目标文件名加上其依赖关系--该源文件中包含的所有头文件列表
# "$$i"实际上是$($i)的意思，"$i"是前面shell变量的值
# 然后把预处理结果都加到临时文件tmp_make中，然后将该临时文件复制成新的makefile文件
dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in init/*.c;do echo -n "init/";$(CPP) -M $$i;done) >> tmp_make
	cp tmp_make Makefile
	(cd fs; make dep)
	(cd kernel; make dep)
	(cd mm; make dep)

### Dependencies:
init/main.o : init/main.c include/unistd.h include/sys/stat.h \
  include/sys/types.h include/sys/times.h include/sys/utsname.h \
  include/utime.h include/time.h include/linux/tty.h include/termios.h \
  include/linux/sched.h include/linux/head.h include/linux/fs.h \
  include/linux/mm.h include/asm/system.h include/asm/io.h include/stddef.h \
  include/stdarg.h include/fcntl.h 
