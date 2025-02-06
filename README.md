## linux-sh脚本

### 2025-02-06
#### ⭐ssh.sh

🚀 Linux自动开启ssh服务，自动检测系统版本安装ssh。终端会有如下提示：  

```
SSH服务已启动并设置为开机自启。
内网IP地址：10.10.10.245
```

🍽️ **ssh.sh 使用方法**

* **安装 wget**

```bash
sudo apt update && sudo apt install wget -y
```

* **github下载地址**
```bash
wget -c -O ~/ssh.sh https://raw.githubusercontent.com/meimolihan/sh/refs/heads/main/ssh.sh && chmod +x ~/ssh.sh && ~/ssh.sh
```

* **cdn加速下载地址**
```bash
wget -c -O ~/ssh.sh https://cdn.jsdelivr.net/gh/meimolihan/sh@v1.0.0/ssh.sh && chmod +x ~/ssh.sh && ~/ssh.sh
```

### 2025-02-06
#### ⭐nfs.sh

🚀 Linux自动部署nfs服务，自动检测系统版本安装nfs。只需要输入：共享文件夹路径。终端会有如下提示：  

```
NFS共享已配置完成！
服务端使用sudo showmount -e查看本机NFS共享目录
共享路径：/mynfs
内网IP地址：10.10.10.245
允许访问的客户端：所有客户端（*）
在客户端上，可以使用以下命令挂载共享：
sudo mount 10.10.10.245:/mynfs /mnt/mynfs
```

🍽️ **nfs.sh 使用方法**

* **安装 wget**

```bash
sudo apt update && sudo apt install wget -y
```

* **github下载地址**
```bash
wget -c -O ~/nfs.sh https://raw.githubusercontent.com/meimolihan/sh/refs/heads/main/nfs.sh && chmod +x ~/nfs.sh && ~/nfs.sh
```

* **cdn加速下载地址**
```bash
wget -c -O ~/nfs.sh https://cdn.jsdelivr.net/gh/meimolihan/sh@v1.0.0/nfs.sh && chmod +x ~/nfs.sh && ~/nfs.sh
```

> 服务端查看本机NFS共享目录,使用 `sudo showmount -e`   
> 服务端查看取消挂载,使用 `nano /etc/exports`  
> 客户端查看本机挂载目录,使用 `sudo df -hT`   
> 客户端取消挂载,使用 `sudo umount /mnt/mynfs`


### 2025-02-05
#### ⭐samba.sh

🚀 Linux自动部署samba服务，自动检测系统版本安装samba ,默认开启root用户samba共享。只需要输入：共享文件夹路径，samba用户名和密码。终端会有如下提示：  

```
Samba共享已配置完成！
共享路径：/mysmb
内网IP地址：10.10.10.245
在资源管理器中输入：\\10.10.10.245\mysmb
访问时使用用户名：root 或 admin
```

🍽️ **samba.sh 使用方法**

* **安装 wget**

```bash
sudo apt update && sudo apt install wget -y
```

* **github下载地址**
```bash
wget -c -O ~/samba.sh https://raw.githubusercontent.com/meimolihan/sh/refs/heads/main/samba.sh && chmod +x ~/samba.sh && ~/samba.sh
```

* **cdn加速下载地址**
```bash
wget -c -O ~/samba.sh https://cdn.jsdelivr.net/gh/meimolihan/sh@v1.0.0/samba.sh && chmod +x ~/samba.sh && ~/samba.sh
```

### 2025-02-04
#### ⭐DnsParse.py

🚀 适合群晖系统，解决自动更新访问TMDB API的DNS写入到群晖系统hosts文件，搭配群晖任务技术实现自动更新。(用某位大佬的代码基础上结合ai修改得到的，忘记那位大佬的一下子搜索不到抱歉）

🍽️ **DnsParse.py 使用方法**

1、套件安装`Python` 和 `wget`
```bash
sudo apt update && sudo apt install python3 wget -y
```

2、 把 `DnsParse.py` 下载下来，导入到群晖群晖的你想放的文件夹里面。
* **github下载地址**
```bash
wget -c -O ~/DnsParse.py https://raw.githubusercontent.com/meimolihan/sh/refs/heads/main/DnsParse.py && chmod +x ~/DnsParse.py && /usr/bin/python3 ~/DnsParse.py
```

* **cdn加速下载地址**
```bash
wget -c -O ~/DnsParse.py https://cdn.jsdelivr.net/gh/meimolihan/sh@v1.0.0/DnsParse.py && chmod +x ~/DnsParse.py && /usr/bin/python3 ~/DnsParse.py
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

### 2025-02-03 初次提交
#### ⭐check.sh

🚀 linux 开机显示系统信息的脚本

🍽️ **check.sh 使用方法**

* **安装 wget**

```bash
sudo apt update && sudo apt install wget -y
```

* **github下载地址**
```bash
wget -c -O /etc/profile.d/check.sh https://raw.githubusercontent.com/meimolihan/sh/refs/heads/main/check.sh && chmod +x /etc/profile.d/check.sh && ln -sf /etc/profile.d/check.sh /usr/local/bin/m && /etc/profile.d/check.sh
```

* **cdn加速下载地址**
```bash
wget -c -O /etc/profile.d/check.sh https://cdn.jsdelivr.net/gh/meimolihan/sh@v1.0.0/check.sh && chmod +x /etc/profile.d/check.sh && ln -sf /etc/profile.d/check.sh /usr/local/bin/m && /etc/profile.d/check.sh
```

* `/etc/profile.d` 目录是一个用于存放 shell 脚本的目录，这些脚本会在用户登录系统并启动一个交互式登录 shell 时被自动执行。

* `ln -sf /etc/profile.d/check.sh /usr/local/bin/m`执行这条命令后，会在 `/usr/local/bin` 目录下创建一个名为 m 的符号链接，该符号链接指向 `/etc/profile.d/check.sh` 文件。这样，当你在终端中输入 `m` 并按下回车键时，实际上就相当于执行了 `/etc/profile.d/check.sh` 脚本。