FROM ubuntu:16.04

MAINTAINER Megvii
COPY . /tmp/nginx
WORKDIR /tmp/nginx

RUN locale-gen en_US.UTF-8
ENV LANG='en_US.UTF-8' LANGUAGE='en_US.UTF-8' LC_ALL='en_US.UTF-8' TZ='Asia/Shanghai'
RUN echo "nameserver 10.9.102.12" > /etc/resolv.conf \
    && sed -i s@archive.ubuntu.com@mirror.pd.megvii-inc.com:800@g /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y \
        gcc \
        make \
        libpcre3 \
        libpcre3-dev \
        libssl-dev \
    && ./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx --group=nginx --with-http_ssl_module --with-http_realip_module --with-http_addition_module \
        --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module \
        --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module \
        --with-http_secure_link_module --with-http_stub_status_module --with-http_auth_request_module \
        --with-http_xslt_module --with-http_image_filter_module --with-http_geoip_module \
        --with-http_perl_module --with-threads \
        --with-http_slice_module --with-mail --with-mail_ssl_module \
        --with-file-aio --with-ipv6 \
        --with-http_v2_module --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2' \
        --with-ld-opt='-Wl,-z,relro -Wl,—as-needed' --add-module=nginx-upload-module \
        --add-module=nginx-upload-progress-module --add-module=nginx-rtmp-module \
    && make \
    && make install \
    && make clean \
    && apt-get purge -y \
       gcc \
       make \
    && apt-get purge --auto-remove -y  \
    && apt-get autoclean -y  \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/nginx/* \
    && mkdir -p /var/cache/nginx/

EXPOSE 80 443
ENV PATH=/etc/nginx/sbin:$PATH
CMD ["nginx", "-g", "daemon off;"]