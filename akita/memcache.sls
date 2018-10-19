
include:
  - memcache 

{% from 'lib/network.sls' import bind_ip0 with context %}

extend:
  /etc/memcached.conf:
    file:
      - context:
        addy_bind: 127.0.0.1,{{ bind_ip0() }}
