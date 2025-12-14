## fail2ban 项目说明



```bash
            cd /etc/fail2ban/filter.d
            wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/fail2ban-nginx-cc.conf
            wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-418.conf
            wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-403.conf
            wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-deny.conf
            wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-unauthorized.conf
            wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-bad-request.conf
            wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-pve.conf

            mkdir -p /var/log/nginx && touch /var/log/nginx/access.log /var/log/nginx/error.log
            mkdir -p /etc/nginx && touch /etc/nginx/nginx.conf

            cd /etc/fail2ban/jail.d/
            wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/jail.d/sshd.local
            wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/jail.d/nginx-cc.conf
            sed -i "/cloudflare/d" /etc/fail2ban/jail.d/nginx-cc.conf
```



```bash
https://gitee.com/meimolihan/sh/raw/master/f2b/centos-ssh.conf
```

