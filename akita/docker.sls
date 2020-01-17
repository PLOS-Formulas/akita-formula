{% from "akita/map.jinja" import props with context %}
{% from 'akita/akita_env.jinja' import akita_env with context %}
{% set environment = salt.grains.get('environment') %}
{% set docker0 = salt.network.ip_addrs('docker0') %}
{% set docker_dns = '172.17.0.1' if not docker0 else docker0[0] %}

include:
  - docker

# nginx is now run in a container instead of on the host
remove-nginx:
  pkg.removed:
    - name: nginx
    

akita-network:
  docker_network.present:
    - name: akita

# memcached container

memcached-container-running:
  docker_container.running:
    - name: memcached
    - image: memcached:1.5.20
    - networks:
      - akita

# prometheus container

prometheus-exporter-conf-file:
  file.managed:
    - name: /opt/prometheus/prometheus-exporter/akita_collector.rb
    - source: salt://akita/opt/prometheus/prometheus-exporter/akita_collector.rb
    - mode: 0644
    - makedirs: True
    
prometheus-exporter-gem-file:
  file.managed:
    - name: /opt/prometheus/prometheus-exporter/Gemfile
    - source: salt://akita/opt/prometheus/prometheus-exporter/Gemfile
    - mode: 0644
    - makedirs: True

prometheus-exporter-container-running:
  docker_container.running:
    - name: prometheus-exporter
    - image: ruby:2.3
    - dns:
      - {{ docker_dns }}
    - networks:
      - akita
    - cmd: bin/bash -c "bundle install; bundle exec prometheus_exporter -v -c akita_collector.rb --prefix akita_"
    - port_bindings:
      - 9394:9394
    - binds:
      - /opt/prometheus/prometheus-exporter/Gemfile:/Gemfile
      - /opt/prometheus/prometheus-exporter/akita_collector.rb:/akita_collector.rb
    
# akita container

{% for name,key in props.get('jwt_public_keys').iteritems() %}
/var/www/akita/jwt_keys/{{ name }}.pub:
  file.managed:
    - contents: |
        {{ key }}
    - mode: 0644
    - makedirs: True
{% endfor %}

akita-image:
  docker_image.present:
    - name: plos/akita:{{ props.get('tag') }}
    - force: true
    - require:
      - pkg: docker

containers-absent:
  docker_container.absent:
    - onchanges:
      - akita-image
    - force: True
    - names:
      - app
      - web
      
assets-volume-absent:
  docker_volume.absent:
    - onchanges:
      - akita-image
    - require:
      - containers-absent
    - name: emberassets
    
nginx-conf-volume:
  docker_volume.present:
    - name: nginxconf
    
nginx-conf-volume-absent:
  docker_volume.absent:
    - onchanges:
      - akita-image
    - require:
      - containers-absent
    - name: nginxconf
    
assets-volume:
  docker_volume.present:
    - name: emberassets
    
app-container-running:
  docker_container.running:
    - name: app
    - image: plos/akita:{{ props.get('tag') }}
    - environment: {{ akita_env | yaml }}
    - networks:
      - akita
    - dns: {{ docker_dns }}
    - binds:
      - emberassets:/code/frontend/dist
      - nginxconf:/code/docker/web/conf/nginx/conf.d
      - /var/www/akita/jwt_keys:/var/www/akita/jwt_keys
    - require:
      - akita-image
      - akita-network
      - assets-volume

# nginx container

nginx-conf-file:
  file.managed:
    - name: /opt/nginx/conf.d/default.conf
    - source: salt://akita/etc/nginx/conf.d/default.conf
    - mode: 0644
    - makedirs: True

web-container-running:
  docker_container.running:
    - name: web
    - image: nginxinc/nginx-unprivileged:1.16-alpine
    - port_bindings:
      - 80:8080
    - networks:
      - akita
    - binds:
      - emberassets:/code/frontend/dist
      - /opt/nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf
    - require:
      - app-container-running

{% if environment != 'prod' %}
  # mailcatcher container

  mailcatcher-container-running:
    docker_container.running:
      - name: mailcatcher
      - image: schickling/mailcatcher
      - port_bindings:
        - 1080:1080
      - networks:
        - akita

{% endif %}
