## linux-sh脚本

### 2025-02-04 初次提交

#### ⭐`linux-check.sh` 是 linux 开机脚本

🍽️ **使用方法**
```bash
wget -c -O /etc/profile.d/linux-check.sh https://raw.githubusercontent.com/meimolihan/sh/refs/heads/main/linux-check.sh && chmod +x /etc/profile.d/linux-check.sh && ln -sf /etc/profile.d/linux-check.sh /usr/local/bin/m && /etc/profile.d/linux-check.sh
```

* `/etc/profile.d` 目录是一个用于存放 shell 脚本的目录，这些脚本会在用户登录系统并启动一个交互式登录 shell 时被自动执行。

* `ln -sf /etc/profile.d/linux-check.sh /usr/local/bin/m`执行这条命令后，会在 `/usr/local/bin` 目录下创建一个名为 m 的符号链接，该符号链接指向 `/etc/profile.d/linux-check.sh` 文件。这样，当你在终端中输入 `m` 并按下回车键时，实际上就相当于执行了 `/etc/profile.d/linux-check.sh` 脚本。