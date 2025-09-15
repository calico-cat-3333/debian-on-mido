# 移植 Debian Linux 到 mido

尝试移植 Debian Linux 到红米 Note 4X 高通版（mido）上。

这部手机具有 postmarketOS 支持，移植基于 pmos 内核，并参考了网上现有的教程。

这台机器有多种供应商，部分供应商的硬件并没有被完全驱动，因此这里不保证完全可用。硬件供应商驱动情况请参考 [https://wiki.postmarketos.org/wiki/Xiaomi_Redmi_Note_4_(xiaomi-mido)](https://wiki.postmarketos.org/wiki/Xiaomi_Redmi_Note_4_(xiaomi-mido)) 

根据 PostmarketOS Wiki 中的描述，搭载 Goodix 触摸屏的设备可能会遇到无法使用触摸的问题，要解决此问题需要使用修改 dts 并重新编译的 lk2nd. 这里提供该修改版本，但是由于我没有设备，所以无法进行测试。

如果你希望使用预构建的系统，可以在 [Releases](https://github.com/calico-cat-3333/debian-on-mido/releases) 里下载文件并直接跳到[刷入](https://github.com/calico-cat-3333/debian-on-mido/tree/main#%E5%88%B7%E5%85%A5)一节。

注意：从 20250915 版本开始提供的预构建的系统将采用新的 extlinux 启动方案而不是 androidboot 方案，因为 extlinux 方案中，内核、initramfs 等文件均放在读写的文件系统中，而不是打包成只读的 boot.img, 因此，更新内核、update-initramfs、编辑启动参数等操作将生效。但是刷写过程将产生区别。

## 编译内核

### 准备

主机安装所需软件包（可能不全）

```
sudo apt install binfmt-support qemu-user-static fakeroot mkbootimg bison flex gcc-aarch64-linux-gnu pkg-config libncurses-dev libssl-dev unzip git debootstrap android-sdk-libsparse-utils adb fastboot libssl-dev libdw-dev
```

克隆此储存库

```
git clone https://github.com/calico-cat-3333/debian-on-mido.git
cd debian-on-mido
```

克隆内核源码

```
git clone https://github.com/msm8953-mainline/linux.git --depth=1 -b 6.16.3/main
```

此处使用的 6.16.3/main 分支是本文撰写时最新的分支，如果需要请调整为其他分支。

编译内核，我的配置文件修改自 [https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/master/device/community/linux-postmarketos-qcom-msm8953/config-postmarketos-qcom-msm8953.aarch64?ref_type=heads](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/master/device/community/linux-postmarketos-qcom-msm8953/config-postmarketos-qcom-msm8953.aarch64?ref_type=heads) 主要就是改了一下本地名称，禁用了模块压缩（这个比较重要，开启之后开不了机），开启了 g_serial, 启用 zram 的 lz4 和 lzo 算法支持

修改后的文件位于 config 中。

### 执行编译

```
cd linux
source ../env.sh
cp ../config .config
make menuconfig
```

保存一次

```
make -j10
make DEB_BUILD_PROFILES=pkg.linux-upstream.nokernelheaders bindeb-pkg
cd ..
```

（这里由于 linux 6.12 内核更改，现在需要 libssl-dev:arm64 才能构建 kernel-headers 所以这里直接不构建 linux-headers 来规避这个问题，具体参考 [https://github.com/msm8953-mainline/linux/commit/e2c318225ac13083cdcb4780cdf5b90edaa8644d](https://github.com/msm8953-mainline/linux/commit/e2c318225ac13083cdcb4780cdf5b90edaa8644d)）

然后在上级文件夹中可以找到生成的 deb 文件

### 准备固件

此储存库中已经提供了准备完成的固件文件夹，因此下面的步骤无需进行，这里仅记录以供参考。

```
git clone https://github.com/Kiciuk/proprietary_firmware_mido.git
mkdir -p firmware/qcom/msm8953/xiaomi/mido/
cp -r proprietary_firmware_mido/apnhlos/* firmware/
cp -r proprietary_firmware_mido/firmware/wlan firmware/
cp -r proprietary_firmware_mido/modem/* firmware/
mv firmware/a506* firmware/qcom/msm8953/xiaomi/mido/
```

更多需要的高通固件将通过后续过程中安装 firmware-qcom-soc 软件包来补充。

// todo: 使用 [msm-firmware-loader](https://gitlab.postmarketos.org/postmarketOS/msm-firmware-loader) 直接从原机分区中获取并加载固件。

## 修改并编译 lk2nd

默认 lk2nd 在 extlinux 启动方式下仅支持小于 16 MB 的 initramfs 镜像，而安装桌面时引入的 plymouth 会极大的增大 initramfs 的体积，导致启动失败，所以需要修改并重新编译 lk2nd

同时，使用 Goodix 触摸屏的设备还需要修改 lk2nd 的 dts 否则无法触摸。

### 准备

安装环境

```
sudo apt install gcc-arm-none-eabi device-tree-compiler libfdt-dev
```

克隆 lk2nd 源代码

```
git clone https://github.com/msm8916-mainline/lk2nd.git
cd lk2nd
```

### 修改

编辑 lk2nd/boot/extlinux.c 第 481 行的 `#define MAX_RAMDISK_SIZE		(16 * 1024 * 1024)` 修改为 `#define MAX_RAMDISK_SIZE		(50 * 1024 * 1024)`

注意：这个值不可以随便增大，根据 lk2nd 开发者的说法，在 msm8953 平台上，为内核、dtb 和 initramfs 预留的内存总计最大为 90 MB. 而默认情况下，内核最大占 32 MB, dtb 2 MB, 即 initramfs 不能超过 56 MB.

同时，如果您的设备搭载 Goodix 触摸屏，还需要修改 lk2nd/device/dts/msm8953/msm8953-xiaomi-common.dts，将 `touchscreen-compatible = "edt,edt-ft5406";` 全部修改为 `touchscreen-compatible = "goodix,gt917d";` 以解决无法触摸的问题。

### 编译

```
make TOOLCHAIN_PREFIX=arm-none-eabi- lk2nd-msm8953
```

然后可以在 build-lk2nd-msm8953 文件夹中找到编译出的 lk2nd.img

## 制作系统

### 制作文件系统镜像

创建 rootfs.img 并挂载，然后使用 debootstrap 创建基本系统。

```
sudo su
dd if=/dev/zero of=rootfs.img bs=1G count=3
mkfs.ext4 rootfs.img
mkdir test
mount rootfs.img test

debootstrap --arch arm64 trixie ./test https://mirrors.tuna.tsinghua.edu.cn/debian/

# 或者使用 env.sh 中的函数

sudo su
source env.sh
make_rootfs_img
```

创建 bootfs.img 作为启动分区。

```
sudo su
dd if=/dev/zero of=bootfs.img bs=1G count=1
mkfs.ext2 bootfs.img

# 或者使用 env.sh 中的函数

sudo su
source env.sh
make_bootfs_img
```

挂载 rootfs

```
sudo su
mount --bind /proc ./test/proc
mount --bind /dev ./test/dev
mount --bind /dev/pts ./test/dev/pts
mount --bind /sys ./test/sys
mount bootfs.img ./test/boot

# 或者使用 env.sh 中的函数

sudo su
source env.sh
mount_rootfs
```

chroot 进去

```
chroot ./test
```

### 基本系统配置

后续步骤中部分命令需要在 chroot 环境中执行，部分需要在主机环境中执行，请注意代码块开头的描述。

在 chroot 中换源，参考[清华源](https://mirrors.tuna.tsinghua.edu.cn/help/debian/)的教程，注意添加 non-free-firmware 源

在 chroot 中设置 root 密码，设置主机名，设置 hostname, 安装必须软件包:

```
passwd root
echo 'xiaomi-mido' > /etc/hostname
echo '127.0.0.1 xiaomi-mido' >> /etc/hosts
apt update
apt install apt-transport-https ca-certificates micro locales locales-all man man-db bash-completion vim tmux network-manager openssh-server initramfs-tools systemd-timesyncd zstd python3 iptables rfkill usbutils sudo console-setup firmware-qcom-soc file alsa-ucm-conf -y
```

复制 firmware 到 chroot 中，在主机中执行：

```
sudo su
cp -r firmware/* ./test/lib/firmware/
```

将生成的内核 deb 文件复制到 chroot 中，在主机中执行：

```
sudo su
cp linux*deb ./test/tmp/
```

在 chroot 中安装内核包，使用 `dpkg -i` 命令，注意 deb 中有一个名字里有 dbg 的文件不需要安装。

编辑 chroot 中的 /etc/initramfs-tools/modules 加入以下内容

```
edt_ft5x06
goodix_ts
msm
panel_xiaomi_boe_ili9885
panel_xiaomi_ebbg_r63350
panel_xiaomi_nt35532
panel_xiaomi_otm1911
panel_xiaomi_tianma_nt35596
```

在 chroot 中创建 /etc/initramfs-tools/hooks/mido-fw 并授予可执行权限，内容为

```
#!/bin/sh
PREREQ=""
prereqs()
{
	echo "$PREREQ"
}
case $1 in
prereqs)
	prereqs
	exit 0
	;;
esac
. /usr/share/initramfs-tools/hook-functions
# Begin real processing below this line
add_firmware qcom/msm8953/xiaomi/mido/a506_zap.mdt
add_firmware qcom/msm8953/xiaomi/mido/a506_zap.elf
add_firmware qcom/msm8953/xiaomi/mido/a506_zap.b00
add_firmware qcom/msm8953/xiaomi/mido/a506_zap.b01
add_firmware qcom/msm8953/xiaomi/mido/a506_zap.b02
```

然后执行 `update-initramfs -u`

### 启动分区配置

配置启动分区，在 chroot 中创建文件 /boot/extlinux/extlinux.conf 内容为：

```
timeout 1
default Debian
menu title boot prev kernel

label Debian
	kernel /vmlinuz-6.16.3-calicocat-msm8953+
	fdtdir /
	initrd /initrd.img-6.16.3-calicocat-msm8953+
	append console=tty0 root=UUID=350b96c5-23d6-419f-a377-d2e446190c14 rw loglevel=3 splash
```

注意：其中的 kernel initrd 以及 root=UUID 均需要参考 chroot 中 /boot 分区中的文件名和 rootfs.img 的 UUID（可以从 `file rootfs.img` 中获取）不可照抄。并且 kernel 和 initrd 的文件名可能会在更新内核软件包后发生变更，请注意及时更新。

// todo: 使用自动化脚本自动更新 extlinux.conf 和 dtb 文件

复制 dtb 文件到 /boot, 在 chroot 中执行：

```
cp /usr/lib/linux-image-6.16.3-calicocat-msm8953+/qcom/*mido* /boot
```

此命令需要在内核更新后重复执行。

自动挂载 boot 分区，在 chroot 中在 /etc/fstab 后附加：

```
UUID=f29c8d16-64af-42a3-bdb6-8f2d3b68d374 /boot ext2 defaults 0 2
```

此处的 UUID 为 bootfs.img 的 UUID, 可以使用 `file bootfs.img` 获取。

### 额外优化

配置启动后自动扩展文件系统，在 chroot 中执行：

```
cat > /etc/systemd/system/resizefs.service << 'EOF'
[Unit]
Description=Expand root filesystem to fill partition
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'exec /usr/sbin/resize2fs $(findmnt -nvo SOURCE /)'
ExecStartPost=/usr/bin/systemctl disable resizefs.service
RemainAfterExit=true

[Install]
WantedBy=default.target
EOF
systemctl enable resizefs.service
```

开启 USB 串口控制，在 chroot 中执行：

```
cat > /etc/systemd/system/serial-getty@ttyGS0.service << EOF
[Unit]
Description=Serial Console Service on ttyGS0

[Service]
ExecStart=-/usr/sbin/agetty -L 115200 ttyGS0 xterm+256color
Type=idle
Restart=always
RestartSec=0

[Install]
WantedBy=multi-user.target
EOF
systemctl enable serial-getty@ttyGS0.service
#如果串口登录失效，可能是g_serial模块没有加载
echo g_serial >> /etc/modules
```

安装 alsa 配置文件，在主机中：

```
git clone https://github.com/msm8953-mainline/alsa-ucm-conf.git
cp -r alsa-ucm-conf/ucm2/* ./test/usr/share/alsa/ucm2/
```

### 结束制作

清理 chroot 环境，在 chroot 中

```
apt clean
rm -rf /tmp/*
exit
```

退出 chroot 并解除挂载，在主机中

```
sudo su
umount ./test/proc
umount ./test/dev/pts
umount ./test/dev
umount ./test/sys
umount ./test/boot
umount ./test

# 或者使用 env.sh 中的函数

sudo su
source env.sh
umount_rootfs
```

转换刷机包格式

```
img2simg rootfs.img rootfs-simg.img
img2simg bootfs.img bootfs-simg.img
```

这样就得到了刷机需要的 bootfs-simg.img 和 rootfs-simg.img

## 刷入

建议先刷入第三方 recovery 推荐 TWRP 或者 OrangFox

进入 recovery 三清

重启到 fastboot

```
fastboot erase boot
fastboot erase system
fastboot erase userdata
```

刷入 lk2nd

```
fastboot flash boot lk2nd.img
```

然后执行 `fastboot reboot` 重启，将进入 lk2nd 的 fastboot 界面（如果不是是从全新的 lk2nd 开始，需要注意在手机振动一下但是屏幕还没有显示 mi 图标的时候按住音量减键，然后也可以进入 lk2nd fastboot 界面），在此界面下，执行

```
fastboot flash system bootfs-simg.img
fastboot flash userdata rootfs-simg.img
```

然后 `fastboot reboot` 重启即可完成刷入。

## 启动系统之后

默认开启了 g_serial 可以通过 USB 串口操作，波特率 115200

### 蓝牙 重力感应

蓝牙需要安装 bluez, 能搜索到设备，未测试连接。

重力感应和亮度传感器需要安装 iio-sensor-proxy

```
apt install bluez iio-sensor-proxy
```

然后可以使用 `monitor-sensor` 命令测试。

### 配置语言时区 tty 字体

```
dpkg-reconfigure locales
dpkg-reconfigure tzdata
dpkg-reconfigure console-setup
```

建议选 VGA 或者 Terminus 可以选大号字体

### 创建新用户

```
adduser user
usermod -aG sudo user
usermod -aG audio user
usermod -aG video user
usermod -aG render user
usermod -aG input user
usermod -aG netdev user
usermod -aG plugdev user
usermod -aG bluetooth user
```

### 启用 zram

zram 允许将内存的一部分压缩作为 swap 使用。

```
sudo apt install zram-tools
```

编辑 /etc/default/zramswap 修改 `ALGO=lz4` 为 `ALGO=zstd`

### 安装桌面环境

这里提供了多个桌面环境可供选择：

[Phosh](phosh.md) 为手机优化，触屏友好。

[Xfce4](xfce4.md) 桌面平台操作逻辑，适合搭配键鼠。

[BuffyBoard](buffyboard.md) 严格上说不算桌面环境，只是在默认 TTY 上加了个虚拟键盘。

## 未测试/已知问题

SIM 卡相关功能未测试

默认加载 g_serial 貌似会导致 OTG 不可用，故如需使用 OTG 请从 /etc/modules 中注释 g_serial

OTG 不稳定

蓝牙能搜索，不知道能不能用。

不支持关机充电（插电自动开机）。

电池和充电状态是分开的（插上电源不会提示正在充电，但是实际上是在充电的，需要打开 powermanager 才会显示交流电源已连接）（时好时坏）

由于上两条：在电量极低的状态下，设备不能保持开机，停触发低电量自动关机，然后由于插电自动开机，会不停处于这个循环中，目前推荐的做法是在电量极低时，进入 recovery 进行充电。

~~有时会不显示电池。遇到这种情况时必须完全关机再开机，重启貌似无效果。充放电有时也不稳定。~~

挂起后无法充电（确切的说，挂起前如果正在充电，从挂起恢复后 upower 服务会出现异常，导致 xfce power manager 卡死，此时电池状态不更新，也不知道是不是在充电，关机/重启时会卡在结束 upower 进程上）（仅在连接充电器后再挂起才会出现这种情况，不充电时挂起不会，恢复也不影响充电）（有待进一步测试）

充电不是很快。（确认为保守的默认充电电流配置导致的，可以通过调整设备树解决）

红外发射未测试。

GPS 未测试。

## 参考/鸣谢

postmaketOS

Aomura\_Umeko (bilibili):

[https://gitee.com/meiziyang2023/hm2-ubuntu-ports/blob/master/%E7%BC%96%E8%AF%91%E6%95%99%E7%A8%8B.md](https://gitee.com/meiziyang2023/hm2-ubuntu-ports/blob/master/%E7%BC%96%E8%AF%91%E6%95%99%E7%A8%8B.md) 

[https://gitee.com/meiziyang2023/ubuntu-ports-xiaomi-625-phones](https://gitee.com/meiziyang2023/ubuntu-ports-xiaomi-625-phones) 

[https://github.com/umeiko/KlipperPhonesLinux](https://github.com/umeiko/KlipperPhonesLinux) 

holdmyhand（博客园）:

[https://www.cnblogs.com/holdmyhand/articles/18048158](https://www.cnblogs.com/holdmyhand/articles/18048158)