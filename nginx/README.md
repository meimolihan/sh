## Nginx

```bash
rm -f /etc/nginx/nginx.conf /etc/nginx/sites-enabled/default

cd /etc/nginx
wget -c https://gitee.com/meimolihan/sh/raw/master/nginx/nginx.conf

cd /etc/nginx/sites-enabled
wget -c https://gitee.com/meimolihan/sh/raw/master/nginx/sites-enabled/default

mkdir -pm 755 /etc/nginx/html && cd /etc/nginx/html
wget -c https://gitee.com/meimolihan/sh/raw/master/nginx/html/index.html

mkdir -pm 755 /etc/nginx/keyfile && cd /etc/nginx/keyfile
wget -c https://gitee.com/meimolihan/sh/raw/master/nginx/keyfile/mobufan.eu.org.pem
wget -c https://gitee.com/meimolihan/sh/raw/master/nginx/keyfile/mobufan.eu.org.key
```

