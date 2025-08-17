# 移植 Debian Linux 到 mido
尝试移植 Debian Linux 到红米 Note 4X 高通版（mido）上。

这部手机具有 postmarketOS 支持，移植基于 pmos 内核，并参考了网上现有的教程。

这台机器有多种供应商，部分供应商的硬件并没有被完全驱动，因此这里不保证完全可用。硬件供应商驱动情况请参考 [https://wiki.postmarketos.org/wiki/Xiaomi_Redmi_Note_4_(xiaomi-mido)](https://wiki.postmarketos.org/wiki/Xiaomi_Redmi_Note_4_(xiaomi-mido)) 

如果你希望使用我已经编译好的系统，可以在 [Releases](https://github.com/calico-cat-3333/debian-on-mido/releases) 里下载文件并直接跳到[刷入](https://github.com/calico-cat-3333/debian-on-mido/tree/main#%E5%88%B7%E5%85%A5)一节。

## 编译内核

### 准备

主机安装所需软件包（可能不全）

```text-x-sh
sudo apt install binfmt-support qemu-user-static fakeroot mkbootimg bison flex gcc-aarch64-linux-gnu pkg-config libncurses-dev libssl-dev unzip git debootstrap android-sdk-libsparse-utils adb fastboot libssl-dev libdw-dev
```

克隆此储存库

```text-x-sh
git clone https://github.com/calico-cat-3333/debian-on-mido.git
```

克隆内核源码

```text-x-sh
git clone https://github.com/msm8953-mainline/linux.git --depth=1 -b 6.15/main
```

此处使用的 6.15/main 分支是本文撰写时最新的分支，如果需要请调整为其他分支。

编译内核，我的配置文件修改自 [https://gitlab.com/postmarketOS/pmaports/-/blob/master/device/community/linux-postmarketos-qcom-msm8953/config-postmarketos-qcom-msm8953.aarch64](https://gitlab.com/postmarketOS/pmaports/-/blob/master/device/community/linux-postmarketos-qcom-msm8953/config-postmarketos-qcom-msm8953.aarch64) 主要就是改了一下本地名称，禁用了模块压缩（这个比较重要，开启之后开不了机），开启了 g_serial

修改后的文件位于 config 中。

### 执行编译

```text-x-sh
cd linux
source ../env.sh
cp ../config .config
make menuconfig
```

保存一次

```text-x-sh
make -j10
make DEB_BUILD_PROFILES=pkg.linux-upstream.nokernelheaders bindeb-pkg
```

（这里由于 linux 6.12 内核更改，现在需要 libssl-dev:arm64 才能构建 kernel-headers 所以这里直接不构建 linux-headers 来规避这个问题，具体参考 [https://github.com/msm8953-mainline/linux/commit/e2c318225ac13083cdcb4780cdf5b90edaa8644d](https://github.com/msm8953-mainline/linux/commit/e2c318225ac13083cdcb4780cdf5b90edaa8644d)）

然后在上级文件夹中可以找到生成的 deb 文件

### 准备固件

此储存库中已经提供了准备完成的固件文件夹，因此下面的步骤无需进行，这里仅记录以供参考。

克隆固件文件

```text-x-sh
git clone https://github.com/Kiciuk/proprietary_firmware_mido.git
```

将 apnhlos 和 modem 两个文件夹中的文件全部拷贝到 firmware 文件夹中，重复则跳过即可

下载 [linux-firmware: https://gitlab.com/kernel-firmware/linux-firmware](https://gitlab.com/kernel-firmware/linux-firmware) 并将 qcom 文件夹复制进去。

创建 qcom/msm8953/xiaomi/mido/ 文件夹

将 firmware 文件夹中 a506 开头的文件复制到 qcom/msm8953/xiaomi/mido/ 文件夹

## 制作系统

### 制作根文件系统

创建 rootfs.img 并挂载，然后使用 debootstrap 创建基本系统。

```text-x-sh
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

挂载 rootfs

```text-x-sh
sudo su
mount --bind /proc ./test/proc
mount --bind /dev ./test/dev
mount --bind /dev/pts ./test/dev/pts
mount --bind /sys ./test/sys

# 或者使用 env.sh 中的函数

sudo su
source env.sh
mount_rootfs
```

chroot 进去

```
chroot ./test
```

在 chroot 中换源、设置 hostname 安装必须软件包

```text-x-sh
passwd root
echo 'xiaomi-mido' > /etc/hostname
echo '127.0.0.1 xiaomi-mido' >> /etc/hosts
apt update
apt install apt-transport-https ca-certificates micro locales locales-all man man-db bash-completion vim tmux network-manager openssh-server initramfs-tools systemd-timesyncd zstd python3 iptables rfkill usbutils sudo console-setup -y
```

在主机中复制 firmware 到 chroot 

```text-x-sh
sudo su
cp -r firmware/* ./test/lib/firmware/
```

在主机中将生成的内核 deb 文件复制到 chroot 中

```text-x-sh
sudo su
cp linux*deb ./test/tmp/
```

在 chroot 中安装内核包，使用 `dpkg -i` 命令，注意 deb 中有一个名字里有 dbg 的文件不需要安装。

编辑 chroot 中 /etc/initramfs-tools/modules 加入以下内容

```text-x-sh
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

### 制作 boot.img

在主机中

```text-x-sh
mkdir tmpboot
cp ./linux/arch/arm64/boot/dts/qcom/*mido*.dtb tmpboot/dtb
cp ./linux/arch/arm64/boot/Image.gz tmpboot/
cp ./test/boot/initrd.img* tmpboot/initrd.img
cat tmpboot/Image.gz tmpboot/dtb > tmpboot/kernel-dtb

rootfs_uuid=`/sbin/blkid -p -o value -s UUID rootfs.img`

mkbootimg --base 0x80000000 \
        --kernel_offset 0x00008000 \
        --ramdisk_offset 0x01000000 \
        --tags_offset 0x00000100 \
        --pagesize 2048 \
        --second_offset 0x00f00000 \
        --ramdisk ./tmpboot/initrd.img \
        --cmdline "console=tty0 root=UUID=$rootfs_uuid rw loglevel=3 splash"\
        --kernel ./tmpboot/kernel-dtb -o ./tmpboot/boot.img

cp ./tmpboot/boot.img ./boot.img

# 或者使用 env.sh 中的函数

sudo su
source env.sh
make_boot_img
```

这里使用 `blkid` 获取 UUID 也可以通过 `file rootfs.img` 获取

~~各偏移量参考 [https://gitlab.com/postmarketOS/pmaports/-/blob/master/device/community/device-xiaomi-mido/deviceinfo](https://gitlab.com/postmarketOS/pmaports/-/blob/master/device/community/device-xiaomi-mido/deviceinfo) ~~

### 优化系统

在 chroot 中

自动扩展文件系统

```text-x-sh
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

开启串口登陆

```text-x-sh
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

### 结束制作

清理 chroot 环境，在 chroot 中

```text-x-sh
apt clean
rm -rf /tmp/*
exit
```

退出 chroot 并解除挂载，在主机中

```text-x-sh
sudo su
umount ./test/proc
umount ./test/dev/pts
umount ./test/dev
umount ./test/sys
umount ./test

# 或者使用 env.sh 中的函数

sudo su
source env.sh
umount_rootfs
```

转换刷机包格式

```text-x-sh
img2simg rootfs.img rootfs-simg.img
```

这样就得到了刷机需要的 boot.img 和 rootfs-simg.img

## 刷入

建议先刷入第三方 recovery 推荐 TWRP 或者 OrangFox

进入 recovery 三清

重启到 fastboot

```text-x-sh
fastboot erase system
fastboot erase userdata
```

我们还需要 lk2nd, 这个不需要自己编译，用 postmarketos 提供的就可以。

刷入 lk2nd

```text-x-sh
fastboot flash boot lk2nd-msm8953.img
```

然后执行 `fastboot reboot` 重启，此时注意在手机振动一下但是屏幕还没有显示 mi 图标的时候按住音量减键，将进入 lk2nd 的 fastboot 界面（如果是从全新的 lk2nd 开始，也可以不按，因为没有可用的启动，所以会自动进入 lk2nd 的 fastboot），在此界面下，执行

```text-x-sh
fastboot flash boot boot.img
fastboot flash userdata rootfs-simg.img
```

然后 `fastboot reboot` 重启即可完成刷入。

## 启动系统之后

默认开启了 g_serial 可以通过 USB 串口操作，波特率 115200

修改 /etc/ssh/sshd\_config 开启 ssh

### 安装 xfce4 桌面环境

```text-x-sh
apt install xorg xfce4 lightdm onboard fonts-wqy-zenhei xinput
```

编辑 /etc/lightdm/lightdm-gtk-greeter.conf 添加键盘配置和字体配置

```text-plain
[greeter]
font-name = Monospace 24
keyboard = onboard -l Phone -e
a11y-states = +keyboard;+font
position = 50%,center 35%,center
keyboard-position = 50%,center -0;100% 40%
```

编辑 /etc/lightdm/lightdm.conf 启用显示用户名，找到 `[Seat:*]` 一节中的 `greeter-hide-users` 一行，修改为

```text-plain
greeter-hide-users=false
```

### 声音 蓝牙 重力感应

声音需要在安装 alsa 和 pulseaudio 之后安装配置文件：

```text-x-sh
apt install git
git clone https://github.com/msm8953-mainline/alsa-ucm-conf.git
cp -r alsa-ucm-conf/ucm2/* /usr/share/alsa/ucm2/
```

蓝牙需要安装 blueman, 能搜索到设备，未测试连接。

重力感应和亮度传感器需要安装 iio-sensor-proxy

```text-x-sh
apt install blueman iio-sensor-proxy
```

然后可以使用 `monitor-sensor` 命令测试。

### 配置语言时区 tty 字体

```text-x-sh
dpkg-reconfigure locales
dpkg-reconfigure tzdata
dpkg-reconfigure console-setup
```

建议选 VGA 或者 Terminus 可以选大号字体

### 创建新用户

```text-x-sh
adduser user
usermod -aG sudo user
usermod -aG audio user
usermod -aG video user
usermod -aG input user
usermod -aG netdev user
usermod -aG plugdev user
usermod -aG bluetooth user
```

### 进入桌面之后

设置-外观-设置-窗口缩放

设置桌面和文件管理器单机激活项目（可选）

安装附属程序

```text-plain
sudo apt install xfce4-terminal mousepad firefox-esr xfce4-power-manager ristretto network-manager-gnome fcitx5 fcitx5-chinese-addons pkexec
```

修复 Firefox 卡死/花屏问题

使用 firefox --same-mode 启动火狐，进入设置禁用硬件加速或进入 about:config 设置 webgl.disabled 为 true（目前看二选一就行，有待进一步测试）

开启 Firefox 触屏支持

~~在 about:config 中找到 dom.w3c_touch_events.enabled 项改为1（启用），默认为2（自动）。~~（现版本似乎已经不需要了）

修改文件 /etc/security/pam_env.conf，在文件最后添加

```text-plain
MOZ_USE_XINPUT2 DEFAULT=1
```

QT 应用缩放问题

QT 应用不跟随系统缩放控制，添加 QT\_FONT\_DPI=192 放大字体

```text-plain
echo QT_FONT_DPI=192 >> /etc/environment
```

### 旋转屏幕控制脚本

需要 xinput xrandr （会随着 xfce4 一起安装） 和 yad

```text-x-sh
sudo apt install xinput yad
```

注意如果你的设备使用 goodix 触屏，那么这个脚本需要修改才能使用。

```text-x-sh
#!/bin/bash
rotate_normal() {
	xrandr --output DSI-1 --rotate normal
	xinput --set-prop 'pointer:generic ft5x06 (3b)' 'Coordinate Transformation Matrix' 1 0 0 0 1 0 0 0 1
}

rotate_left() {
	xrandr --output DSI-1 --rotate left
	xinput --set-prop 'pointer:generic ft5x06 (3b)' 'Coordinate Transformation Matrix' 0 -1 1 1 0 0 0 0 1
}

rotate_right() {
	xrandr --output DSI-1 --rotate right
	xinput --set-prop 'pointer:generic ft5x06 (3b)' 'Coordinate Transformation Matrix' 0 1 0 -1 0 1 0 0 1
}

rotate_upsidedonw() {
	xrandr --output DSI-1 --rotate inverted
	xinput --set-prop 'pointer:generic ft5x06 (3b)' 'Coordinate Transformation Matrix' -1 0 1 0 -1 1 0 0 1
}

export -f rotate_normal
export -f rotate_left
export -f rotate_right
export -f rotate_upsidedonw

yad --title="旋转屏幕" --text="旋转屏幕"  --button "完成":0 \
--width=150 --center --window-icon=phone \
--form --columns=1 \
--field='顶部向上:fbtn' 'bash -c rotate_normal' \
--field='右侧向上:fbtn' 'bash -c rotate_left' \
--field='左侧向上:fbtn' 'bash -c rotate_right' \
--field='底部向上:fbtn' 'bash -c rotate_upsidedonw'
```

desktop 文件（如果需要）

```text-plain
[Desktop Entry]
Version=1.0
Type=Application
Name=Rotate
Name[zh_CN]=旋转屏幕
Icon=phone
Exec=rotate.sh
Categories=Settings;
Terminal=false
```

### 隐藏无需挂载的磁盘分区

参考 [https://wiki.archlinux.org/title/Udisks](https://wiki.archlinux.org/title/Udisks) 

默认 xfce4 会显示很多没挂载的分区，这些分区不需要使用，所以隐藏他们。

使用 `lsblk -o KNAME,LABEL,UUID,SIZE,MOUNTPOINT,FSTYPE` 命令列出磁盘信息，其中只有几个有 UUID，有 UUID 的几个分区除了挂载到根目录上的那个都需要隐藏，UUID 大概是每台机器都不一样，所以下面的文件需要根据输出结果再修改。

编辑 /etc/udev/rules.d/99-hide-partitions.rules

```text-plain
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="00BC-614E", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="af32c008-2a39-7e5b-a5dc-201456d93103", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="9abd4998-a345-4827-b04f-2ffb204b383c", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="57f8f4bc-abf4-655f-bf67-946fc0f9f25b", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="14a5787d-37b0-5f5d-a40f-c06eba75d1ea", ENV{UDISKS_IGNORE}="1"
```

然后执行（或者重启）

```text-x-sh
udevadm control --reload-rules
udevadm trigger
```

应该就可以看到那几个多出来的分区从桌面和文件管理器里消失了。

### 电源按钮行为

在 xfce power manager 中可以控制默认电源按钮行为，但这只在 xfce 里有效，在 lightdm 里无效。

在 lightdm 界面下，电源按钮行为受到 systemd-logind 的控制，所以需要编辑 `/etc/systemd/logind.conf` 修改其中的 `HandlePowerKey=` 一项。

### 杂七杂八

还有一些别的界面或者行为配置，比较杂碎有些想不起来了

面板：

显示行数设置为 2

工作区切换器双行

应用程序菜单按钮改字（减小宽度）

电量管理插件显示百分比标签

状态栏插件开启菜单是主要动作

通知插件-无通知时隐藏

光标大小

fcitx5 经典用户界面 字体大小全部调整到 20 以上

开启 onborad 自启

## 未测试/已知问题

SIM 卡相关功能未测试

默认加载 g_serial 貌似会导致 OTG 不可用，故如需使用 OTG 请从 /etc/modules 中注释 g_serial

OTG 不稳定

有时卡死在关机动画上，需要长按电源按钮重启。

xfce 下没有自动旋屏。

有时会卡死，需要长按电源按钮重启。

蓝牙能搜索，不知道能不能用。

网络连接疑似不稳定。（不确定，需要进一步测试，有可能是我的热点机开的 wifi6 模式导致的）

亮度传感器和重力传感器可用，但是还没想好怎么实现自动旋屏和自动亮度调整。

电池和充电状态是分开的（插上电源不会提示正在充电，但是实际上是在充电的，需要打开 powermanager 才会显示交流电源已连接）

~~有时会不显示电池。遇到这种情况时必须完全关机再开机，重启貌似无效果。充放电有时也不稳定。~~

~~挂起后无法充电（确切的说，从挂起恢复后 upower 服务会出现异常，导致 xfce power manager 卡死，此时电池状态不更新，也不知道是不是在充电，关机/重启时会卡在结束 upower 进程上，并可能导致上述不显示电池的问题）（仅在连接充电器后再挂起才会出现这种情况，不充电时挂起不会，恢复也不影响充电）~~

不支持关机充电（插电自动开机）。

充电不是很快。

红外发射未测试。

GPS 未测试。

偶发图形错误。

偶发触屏故障。

## 参考/鸣谢

postmaketOS

Aomura\_Umeko (bilibili):

[https://gitee.com/meiziyang2023/hm2-ubuntu-ports/blob/master/%E7%BC%96%E8%AF%91%E6%95%99%E7%A8%8B.md](https://gitee.com/meiziyang2023/hm2-ubuntu-ports/blob/master/%E7%BC%96%E8%AF%91%E6%95%99%E7%A8%8B.md) 

[https://gitee.com/meiziyang2023/ubuntu-ports-xiaomi-625-phones](https://gitee.com/meiziyang2023/ubuntu-ports-xiaomi-625-phones) 

[https://github.com/umeiko/KlipperPhonesLinux](https://github.com/umeiko/KlipperPhonesLinux) 

holdmyhand（博客园）:

[https://www.cnblogs.com/holdmyhand/articles/18048158](https://www.cnblogs.com/holdmyhand/articles/18048158)