## linux-sh脚本

### 2025-02-05
#### ⭐DnsParse.py

适合群晖系统，解决自动更新访问TMDB API的DNS写入到群晖系统hosts文件，搭配群晖任务技术实现自动更新。(用某位大佬的代码基础上结合ai修改得到的，忘记那位大佬的一下子搜索不到抱歉）

1、套件安装Python
```bash
sudo apt update && sudo apt install python3 -y
```

2、 把 `DnsParse.py` 下载下来，导入到群晖群晖的你想放的文件夹里面。
```bash
wget -c -O /mnt/mydisk/my-sh/hosts/DnsParse.py https://raw.githubusercontent.com/meimolihan/sh/refs/heads/main/DnsParse.py && chmod +x /mnt/mydisk/my-sh/hosts/DnsParse.py && /usr/bin/python3 /mnt/mydisk/my-sh/hosts/DnsParse.py
```

3、查询自己的PY目录 SHH命令查询如下
```bash
which python which python3
```

4、windows打开控制面板，任务计划新建任务，用户账户类型：Root，计划每天某个时间点就行，任务设置-运行命令用户自定义脚本写入
```bash
/usr/bin/python3 /mnt/mydisk/my-sh/hosts/DnsParse.py
```

> 其中“/bin/python3”替换自己which python which python3查询得到的目录；  
其中“/volume1/docker/DnsParse.py”修改为自己的存放的DnsParse.py文件的路径。

5、ssh命令查询是否修改成功，输入 
```bash
cat /etc/hosts
```

6、 一键加入到计划任务
```bash
{ crontab -l; echo ""; } | crontab - echo "插入空行"
{ crontab -l; echo "## 添加更新hosts文件定时任务，每天凌晨一点十分执行"; } | crontab - echo "添加注释"
{ crontab -l; echo "10 1 * * * /usr/bin/python3 /mnt/mydisk/my-sh/hosts/DnsParse.py"; } | crontab - echo "执行已完成，任务已设置。"
```

### 2025-02-04 初次提交

#### ⭐linux-check.sh

* linux 开机脚本

安装 wget

```bash
sudo apt update && sudo apt install wget -y
```

🍽️ **使用方法**
```bash
wget -c -O /etc/profile.d/linux-check.sh https://raw.githubusercontent.com/meimolihan/sh/refs/heads/main/linux-check.sh && chmod +x /etc/profile.d/linux-check.sh && ln -sf /etc/profile.d/linux-check.sh /usr/local/bin/m && /etc/profile.d/linux-check.sh
```

* `/etc/profile.d` 目录是一个用于存放 shell 脚本的目录，这些脚本会在用户登录系统并启动一个交互式登录 shell 时被自动执行。

* `ln -sf /etc/profile.d/linux-check.sh /usr/local/bin/m`执行这条命令后，会在 `/usr/local/bin` 目录下创建一个名为 m 的符号链接，该符号链接指向 `/etc/profile.d/linux-check.sh` 文件。这样，当你在终端中输入 `m` 并按下回车键时，实际上就相当于执行了 `/etc/profile.d/linux-check.sh` 脚本。