# 安装 ModelPlan Mac 测试版

[English](mac-beta-install.md)

需要 **macOS 14 或更新版本**。已在 Apple 芯片机型上测试；Intel 尚未测试，3D 效果可能卡顿。

## 下载与安装

在 [GitHub Releases](https://github.com/modelplan/modelplan/releases) 下载 Mac 应用 ZIP 和对应的 SHA-256 校验值。先在终端检查压缩包，文件名请换成实际下载的名称：

```sh
shasum -a 256 "$HOME/Downloads/ModelPlan.app.zip"
```

将完整结果与该文件公布的校验值比较；不一致就重新下载。确认后解压，把应用拖进「应用程序」。

**TODO(M4)：** 公开测试版 ZIP、校验值和最终应用名称尚待发布确认。目前源码打包产物叫 `ModelPlan Community.app`；下文的 `ModelPlan.app` 是计划中的测试版名称。

## 第一次打开

目前还没有 Apple 开发者账号，也没有经过 Apple 公证。测试版采用 **ad-hoc 签名，未公证**，因此首次打开会被 Gatekeeper 拦截。发布时会同时提供构建文件和校验值，方便核对下载内容。

- **macOS 14：** 在「应用程序」中右键点应用 →「打开」→ 再确认「打开」。
- **macOS 15 及以后**，或右键方式无效时：先尝试打开一次，再进「系统设置 → 隐私与安全性」，找到「仍要打开」（Open Anyway）并确认。可参阅 [Apple 的操作说明](https://support.apple.com/zh-cn/102445)。

核对下载后，也可以在终端移除这个应用的隔离标记：

```sh
xattr -dr com.apple.quarantine "/Applications/ModelPlan.app"
```

如果应用名称不同，请改成实际安装名称，然后重新打开。

## 首次运行时选什么

**TODO(M4)：** 检测工具与授权页的联动尚待接入。计划只用一页列出检测到的工具，让你统一确认；默认只勾选「标准」类读取器。「浏览器会话（高级）」默认关闭，需要逐个主动开启。确认前可取消勾选。不向 ModelPlan 上传任何本机数据；启用额度读取后，只向对应工具自己的服务商验证登录。[每个读取器读取什么](clients-and-readers.md) 有详细说明。

## 更新与权限

**TODO(M4)：** Sparkle 自动更新尚待接入应用。测试版更新包将使用 ModelPlan 自己的 EdDSA 密钥签名。每次 ad-hoc 构建的签名都会变化，macOS 可能重新询问之前已授予的权限，届时按需再次授权。以后经过 Apple 公证的版本也会通过正常更新安装。

## 退出与卸载

在菜单栏菜单里选 **Quit（退出）**。如果开启过登录时启动，先在「系统设置 → 通用 → 登录项」移除该应用，再删除应用本身。**TODO(M4)：** 应用的登录项注册尚未接入。

要一并清除本机数据，可在访达用「前往 → 前往文件夹」找到并删除以下目录（存在才删；`~` 代表你的个人文件夹）：

- `~/Library/Caches/modelplan/`：CLI 共享存储。设置过 `MODELPLAN_CACHE` 的，改为清理该变量指定的目录。
- `~/.config/modelplan/`：共享授权记录和配置。
- `~/Library/Application Support/ModelPlan/Native/`：当前应用设置，包括 `settings-v1.json`。

前两个目录也供 CLI 和插件使用，删除会同时重置它们。**TODO(M4)：** 正式包的 bundle ID，以及是否增加按 bundle ID 存放的 Application Support／偏好设置，仍需确认。目前打包 ID 是 `org.modelplan.community.swift.scaffold`；应用设置存放在上述目录，尚无按 bundle ID 存放的偏好设置。

## 遇到问题

打开 **Settings… / 设置… → 关于 → 复制诊断信息（Copy diagnostics）**，将结果和复现步骤贴到 [GitHub issue](https://github.com/modelplan/modelplan/issues/new/choose)。诊断仅含应用与 CLI 版本、macOS 版本、已启用的读取器 ID 和近期错误代码，不含个人数据。**TODO(M4)：** 复制按钮已实现，实际版本、读取器和错误数据尚待接入，部分字段可能为空或显示 `unknown`。
