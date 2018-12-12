
include:
  - memcache 

extend:
  /etc/memcached.conf:
    file:
      - context:
        addy_bind: 127.0.0.1,{{ salt.plosutil.get_canonical_ip() }}
