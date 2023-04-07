FROM @@CONTAINER@@

LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

RUN set -ex \
    && savedAptMark="$(apt-mark showmanual)" \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y ca-certificates mercurial build-essential libssl-dev libpcre2-dev \
    && mkdir -p /usr/lib/unit/modules /usr/lib/unit/debug-modules \
    && hg clone -u @@VERSION@@-@@PATCHLEVEL@@ https://hg.nginx.org/unit \
    && cd unit \
    && NCPU="$(getconf _NPROCESSORS_ONLN)" \
    && DEB_HOST_MULTIARCH="$(dpkg-architecture -q DEB_HOST_MULTIARCH)" \
    && CC_OPT="$(DEB_BUILD_MAINT_OPTIONS="hardening=+all,-pie" DEB_CFLAGS_MAINT_APPEND="-Wp,-D_FORTIFY_SOURCE=2 -fPIC" dpkg-buildflags --get CFLAGS)" \
    && LD_OPT="$(DEB_BUILD_MAINT_OPTIONS="hardening=+all,-pie" DEB_LDFLAGS_MAINT_APPEND="-Wl,--as-needed -pie" dpkg-buildflags --get LDFLAGS)" \
    && CONFIGURE_ARGS="--prefix=/usr \
                --state=/var/lib/unit \
                --control=unix:/var/run/control.unit.sock \
                --pid=/var/run/unit.pid \
                --log=/var/log/unit.log \
                --tmp=/var/tmp \
                --user=unit \
                --group=unit \
                --openssl \
                --libdir=/usr/lib/$DEB_HOST_MULTIARCH" \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --ld-opt="$LD_OPT" --modules=/usr/lib/unit/debug-modules --debug \
    && make -j $NCPU unitd \
    && install -pm755 build/unitd /usr/sbin/unitd-debug \
    && make clean \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --ld-opt="$LD_OPT" --modules=/usr/lib/unit/modules \
    && make -j $NCPU unitd \
    && install -pm755 build/unitd /usr/sbin/unitd \
    && make clean \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --modules=/usr/lib/unit/debug-modules --debug \
    && ./configure @@CONFIGURE@@ \
    && make -j $NCPU @@INSTALL@@ \
    && make clean \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --modules=/usr/lib/unit/modules \
    && ./configure @@CONFIGURE@@ \
    && make -j $NCPU @@INSTALL@@ \
    && cd \
    && rm -rf unit \
    && for f in /usr/sbin/unitd /usr/lib/unit/modules/*.unit.so; do \
        ldd $f | awk '/=>/{print $(NF-1)}' | while read n; do dpkg-query -S $n; done | sed 's/^\([^:]\+\):.*$/\1/' | sort | uniq >> /requirements.apt; \
       done \
    && apt-mark showmanual | xargs apt-mark auto > /dev/null \
    && { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
    && @@RUN@@ \
    && mkdir -p /var/lib/unit/ \
    && mkdir /docker-entrypoint.d/ \
    && addgroup --system unit \
    && adduser \
         --system \
         --disabled-login \
         --ingroup unit \
         --no-create-home \
         --home /nonexistent \
         --gecos "unit user" \
         --shell /bin/false \
         unit \
    && apt-get update \
    && apt-get --no-install-recommends --no-install-suggests -y install curl $(cat /requirements.apt) \
    && apt-get purge -y --auto-remove \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && rm -f /requirements.apt \
    && ln -sf /dev/stdout /var/log/unit.log

COPY docker-entrypoint.sh /usr/local/bin/

STOPSIGNAL SIGTERM

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["unitd", "--no-daemon", "--control", "unix:/var/run/control.unit.sock"]
