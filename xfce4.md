# xfce4 桌面环境

xfce4 桌面环境，适合搭配键盘鼠标使用。

触屏不算友好，但也能用。

## 安装

```
apt install xorg xfce4 lightdm onboard fonts-wqy-zenhei xinput
```

编辑 /etc/lightdm/lightdm-gtk-greeter.conf 添加键盘配置和字体配置

```
[greeter]
font-name = Monospace 24
keyboard = onboard -l Phone -e
a11y-states = +keyboard;+font
position = 50%,center 35%,center
keyboard-position = 50%,center -0;100% 40%
```

编辑 /etc/lightdm/lightdm.conf 启用显示用户名，找到 `[Seat:*]` 一节中的 `greeter-hide-users` 一行，修改为

```
greeter-hide-users=false
```

安装附属程序

```
sudo apt install xfce4-terminal mousepad firefox-esr xfce4-power-manager ristretto network-manager-gnome fcitx5 fcitx5-chinese-addons pkexec blueman
```

## 进入桌面后的配置

### 基本配置

设置-外观-设置-窗口缩放

设置桌面和文件管理器单机激活项目（可选）

修复 Firefox 卡死/花屏问题

使用 firefox --same-mode 启动火狐，进入设置禁用硬件加速或进入 about:config 设置 webgl.disabled 为 true（目前看二选一就行，有待进一步测试）

开启 Firefox 触屏支持

~~在 about:config 中找到 dom.w3c_touch_events.enabled 项改为1（启用），默认为2（自动）。~~（现版本似乎已经不需要了）

修改文件 /etc/security/pam_env.conf，在文件最后添加

```
MOZ_USE_XINPUT2 DEFAULT=1
```

QT 应用缩放问题

QT 应用不跟随系统缩放控制，添加 QT\_FONT\_DPI=192 放大字体

```
echo QT_FONT_DPI=192 >> /etc/environment
```

### 旋转屏幕控制脚本

需要 xinput xrandr （会随着 xfce4 一起安装） 和 yad

```
sudo apt install xinput yad
```

注意如果你的设备使用 goodix 触屏，那么这个脚本需要修改才能使用。

```
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

```
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

```
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="00BC-614E", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="af32c008-2a39-7e5b-a5dc-201456d93103", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="9abd4998-a345-4827-b04f-2ffb204b383c", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="57f8f4bc-abf4-655f-bf67-946fc0f9f25b", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="14a5787d-37b0-5f5d-a40f-c06eba75d1ea", ENV{UDISKS_IGNORE}="1"
```

然后执行（或者重启）

```
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

## 已知问题

没有自动旋屏。

没有自动亮度。
