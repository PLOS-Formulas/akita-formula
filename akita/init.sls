{% set ruby_ver = salt.pillar.get('akita:versions:ruby') %}
{% from 'lib/auth_keys.sls' import manage_authorized_keys %}
{% from 'lib/environment.sls' import environment %}
{% from "akita/map.jinja" import props with context %}
{% set capdeloy_host = salt['pillar.get']('environment:' ~ environment ~ ':capdeploy', 'None') %}
{% set fqdn = salt['grains.get']('fqdn', 'localhost.localdomain') -%}
{% set hostname = salt['grains.get']('host', 'localhost') -%}

include:
  - nginx
  - common.packages
  - common.repos
  - akita.memcache
  - akita.ruby
  - akita.prometheus-exporter

apt-repo-node-v6:
  pkgrepo.managed:
    - name: deb https://deb.nodesource.com/node_6.x trusty main
    - dist: trusty
    - file: /etc/apt/sources.list.d/node_v6.list
    - key_url: https://deb.nodesource.com/gpgkey/nodesource.gpg.key
    - keyid: 0x68576280
    - keyserver: keyserver.ubuntu.com

akita-install-bundler:
  cmd.run:
    - name: chruby-exec {{ ruby_ver }} -- gem install bundler
    - unless: chruby-exec {{ ruby_ver }} -- gem list | grep bundler > /dev/null 2>&1
    - cwd: /home/akita
    - runas: akita
    - require:
      - user: akita
      - pkg: plos-ruby

akita:
  group:
    - present
    - gid: {{ salt.pillar.get('uids:akita:gid') }}
  user:
    - present
    - uid: {{ salt.pillar.get('uids:akita:uid') }}
    - gid: {{ salt.pillar.get('uids:akita:gid') }}
    - gid_from_name: true
{% if fqdn == capdeloy_host %}
    - groups:
      - teamcity
{% endif %}
    - createhome: true
    - shell: /bin/bash
    - require:
      - group: akita
{% if fqdn == capdeloy_host %}
      - group: teamcity
{% endif %}

{% if grains['environment'] in ['vagrant', 'dev'] %}
{{ manage_authorized_keys('/home/akita/.ssh', 'akita', pillar['akita']['deployers'][grains['environment']], pillar['akita']['deploy_keys'][grains['environment']]) }}
{% else %}
{{ manage_authorized_keys('/home/akita/.ssh', 'akita', ssh_extra=pillar['akita']['deploy_keys'][grains['environment']]) }}
{% endif %}

# to talk from capdeploy to akita, only needed on akita box
# TODO: figure out how to remove this without breaking capdeply since its causing salt log noise
authorized_capdeploy_key:
  file.append:
    - name: /home/akita/.ssh/authorized_keys
    - text: {{ salt.pillar.get('akita:deploy_keys:akita_capdeploy_local_key') }}
    - require:
      - user: akita

extend:
  apt-repo-plos:
    pkgrepo.managed:
      - require_in:
        - pkg: akita-apt-packages

akita-apt-packages:
  pkg.installed:
    - pkgs:
      - build-essential
      - libgmp-dev
      - libsqlite3-dev
      - libssl-dev
      - nodejs  # will install the latest 6.x LTS

yarn:
  npm.installed:
  - require:
    - pkg: akita-apt-packages

node_requirements:
  pkg.installed:
    - pkgs:
      - rlwrap

/var/www/akita:
  file.directory:
    - user: akita
    - group: akita
    - require:
      - user: akita

/var/www/akita/jwt_keys:
  file.directory:
    - user: akita
    - group: akita
    - require:
      - user: akita
      - file: /var/www/akita

{% for name,key in props.get('jwt_public_keys').iteritems() %}
/var/www/akita/jwt_keys/{{ name }}.pub:
  file.managed:
    - contents: |
        {{ key }}
    - require:
      - file: /var/www/akita
{% endfor %}

/var/www/akita/.ruby-version:
  file.managed:
    - makedirs: true
    - user: akita
    - group: akita
    - require:
      - file: /var/www/akita
    - contents: ruby-{{ ruby_ver }}

/etc/sudoers.d/akita:
  file.managed:
    - template: jinja
    - source: salt://akita/etc/sudoers.d/akita

# NOTE: move envs to akita-envs.sh once PLT-268 is resolved

/home/akita/.bashrc:
  file.managed:
    - template: jinja
    - name: /home/akita/.bashrc
    - source: salt://akita/home/akita/bashrc
    - require:
      - user: akita

/home/akita/.bash_profile:
  file.managed:
    - user: akita
    - group: akita
    - require:
       - user: akita
    - contents: |
        if [ -f ~/.bashrc ]; then
          . ~/.bashrc
        fi

/usr/local/bin/rake:
  file.symlink:
    - target: /opt/rubies/ruby-{{ ruby_ver }}/bin/rake
    - force: True
    - require:
      - pkg: plos-ruby

akita-advertise:
  file.serialize:
    - name: /etc/consul.d/akita.json
    - formatter: json
    - dataset:
        service:
          name: 'akita-exporter'
          port: 9394
          tags:
            - {{ environment }}

{% if salt['file.file_exists' ]("/etc/init/akita.conf") %}
akita_restart_for_configs:
  service.running:
    - name: akita
    - watch:
      - file: /home/akita/.bashrc
{% endif %}


{# Set this grain in dewey for akita host you want to run scheduled import task #}
{% if salt.grains.get('salesforce-import') %}

/etc/cron.d/akita:
  file.managed:
    - source: salt://akita/etc/cron.d/akita

{% else %}

/etc/cron.d/akita:
  file.absent

{% endif %}

