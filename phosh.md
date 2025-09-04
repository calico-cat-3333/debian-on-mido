# Phosh

基于 GNOME, 为触摸屏专门优化的桌面环境。

优点：

触屏友好且美观。

有自动旋屏，有自动亮度。

缺陷：

中文输入体验不佳。

性能要求高。

## 安装 Phosh：

```
sudo apt install phosh phosh-full phosh-phone
```

安装其他附加软件：

```
sudo apt install firefox-esr gnome-tweaks dconf-editor alsa-utils gnome-text-editor dconf-cli loupe nautilus
```

## 进入桌面后的配置

### 浏览器修复

修正默认浏览器（Epiphany）白屏

编辑：/usr/share/applications/org.gnome.Epiphany.desktop 将 Exec 行前的命令上加上 `env LIBGL_ALWAYS_SOFTWARE=1`

Epiphany 设置移动端 UA

```
gsettings set org.gnome.Epiphany.web:/org/gnome/epiphany/web/ user-agent 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.6167.178 Mobile Safari/537.36'
```

修复 Firefox 卡死/花屏问题

使用 firefox --same-mode 启动火狐，进入设置禁用硬件加速或进入 about:config 设置 webgl.disabled 为 true（目前看二选一就行，有待进一步测试）

### 修正默认音量过小的问题

在 alsamixer 中提高 RX3 Digital（先按 F6 进入 xiaomi-mido 声卡，然后往后翻，在很靠后的位置） 注意不要过高，不然底噪就会很严重，我暂时调到 46 左右觉得比较好。（RX1 Digital 是耳机左声道，RX2 Digital 是耳机右声道，这两个也可以调整一下到 28 左右）

### 安装中文输入法

#### 使用 squeekboard + fcitx5

```
sudo apt install fcitx5 fctix5-chinese-addons
```

重启设备。

重启后，输入法即可使用。但是，安装输入法后，虚拟键盘将无法自动弹出，需要使用长按小横条的方法手动弹出，并且由于手动弹出在鉴权窗口不可用，所以安装中文输入法后，不能使用 pkexec, 输入 wifi 密码需要点击进入 wifi 详情页面的最后一页“安全”中输入，不能直接点击条目在弹出的密码窗口中输入。

一个不太好用的解决方案：

在 ~/.local/share/fcitx5/addon/ 文件夹中创建 squeekbd.conf 内容为：

```
[Addon]
Name=Squeekboard
Comment=Squeekboard
Category=Module
Type=Lua
OnDemand=False
Configurable=False
Library=squeekbd.lua

[Addon/Dependencies]
0=luaaddonloader

```

在 ~/.local/share/fcitx5/lua/squeekbd/ 文件夹中创建 squeekbd.lua 内容为：

```
local fcitx = require("fcitx")

fcitx.watchEvent(fcitx.EventType.InputMethodActivated, "call")
fcitx.watchEvent(fcitx.EventType.InputMethodDeactivated, "decall")

function kbenable()
    local handle = io.popen("gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled 2>&1")
    local result = handle:read("*a")
    handle:close()
    result = result:gsub("^%s+", ""):gsub("%s+$", "")
    if result == "true" then
        return true
    elseif result == "false" then
        return false
    end
end

function call()
    if kbenable() then
        os.execute("busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true")
    end
end

function decall()
    if kbenable() then
        os.execute("busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false")
    end
end
```

简单的说就是利用 fcitx5 的 lua api, 在输入法活动时，自动调用 busctl 唤起虚拟键盘，不活动时隐藏虚拟键盘，可以实现输入时自动弹出键盘功能。但是此方法有两个缺点：使用 ctrl-space 切换输入法时，键盘会消失再弹出；密码窗口弹出的键盘会出现在不可点击区域，仍然不能输入密码。

输入法候选词数量改成 5 个，候选窗口样式改成竖排。

可选：

在 mobile settings 里调整虚拟键盘高度

安装两个额外的键盘配置文件（供终端使用）：复制 squeekboard-layouts/terminal 中的两个文件到 ~/.local/share/squeekboard/keyboards/terminal/ 中。

#### 使用 stevia

stevia 是 phosh 的下一代虚拟键盘，支持自定义补全引擎，所以也许可以利用这个制作一个简单的中文输入法。

// todo

## 已知问题

卡。

时不时的图形错误（字符渲染成黑色方块）。