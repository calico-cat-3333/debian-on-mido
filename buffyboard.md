# BuffyBoard

BuffyBoard: 用于虚拟终端的触摸屏幕键盘。

安装依赖：

```
sudo apt install build-essential meson git cmake  pkg-config libinih-dev libinput-dev libxkbcommon-dev scdoc libdrm-dev systemd-dev
```

克隆存储库（由于 lvgl 库很大，这一步耗时超级长）：

```
git clone https://gitlab.postmarketos.org/postmarketOS/buffybox.git
cd buffybox
git submodule init
git submodule update
```

编译安装：

```
meson setup builddir/
meson compile -C builddir/
meson install -C builddir/ --tags=buffyboard
```

开机自启：

```
systemctl enable buffyboard.service
```

这个镜像默认语言为中文，TTY 无法显示，所以需要改回英语

```
sudo su
export LANG=C
dpkg-reconfigure locales
```

如需卸载：

```
ninja -C builddir/ uninstall
```