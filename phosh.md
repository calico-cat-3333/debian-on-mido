# Phosh

基于 GNOME, 为触摸屏专门优化的桌面环境。

优点：

触屏友好且美观。

有自动旋屏，有自动亮度。

缺陷：

中文输入法配合有问题。

性能要求高。

## 安装 Phosh：

```
sudo apt install phosh phosh-full phosh-phone
```

安装其他附加软件：

```
sudo apt install firefox-esr gnome-tweaks dconf-editor portfolio-filemanager alsa-utils gnome-text-editor
```

## 进入桌面后的配置

修正默认浏览器（Epiphany）白屏（可选，因为它不算好用，经常卡死）

```
gsettings set org.gnome.Epiphany.web:/ hardware-acceleration-policy 'never'
```

或使用 dconf-editor 修改。

修复 Firefox 卡死/花屏问题

使用 firefox --same-mode 启动火狐，进入设置禁用硬件加速并进入 about:config 设置 webgl.disabled 为 true（目前看二选一就行，有待进一步测试）

安装中文输入法：

```
sudo apt install fcitx5 fctix5-chinese-addons
```

重启设备。

重启后，输入法即可使用。但是，安装输入法后，虚拟键盘将无法自动弹出，需要使用长按小横条的方法手动弹出。

在 mobile-settings 里调整虚拟键盘高度

输入法候选词数量改成 5 个，候选窗口样式改成竖排。

额外音频调整：修正默认音量过小的问题。

在 alsamixer 中提高 RX3 Digital（在很靠后的位置，慢慢翻） 注意不要过高，不然底噪就会很严重，我暂时调到 46 左右觉得比较好。（RX1 Digital 是耳机左声道，RX2 Digital 是耳机右声道，这两个也可以调整一下到 28 左右）

## 已知问题

卡。