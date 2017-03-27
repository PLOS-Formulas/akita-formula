{%- from "lib/git.sls" import github_setup %}
{% set ruby_ver = salt.pillar.get('akita:versions:ruby') %}
{% from 'lib/auth_keys.sls' import manage_authorized_keys %}
{% from 'lib/environment.sls' import environment %}
{% set capdeloy_host = salt['pillar.get']('environment:' ~ environment ~ ':capdeploy', 'None') %}

include:
  - nginx
  - common.repos
  - akita.hosts
  - common.packages
  - common.repos

plos-ruby:
  pkg.installed:
    - name: plos-ruby-{{ ruby_ver }}

chruby:
  pkg.installed

akita-install-bundler:
  cmd.run:
    - name: chruby-exec {{ ruby_ver }} -- gem install bundler
    - unless: chruby-exec {{ ruby_ver }} -- gem list | grep bundler > /dev/null 2>&1
    - cwd: /home/akita
    - user: akita
    - group: akita
    - require:
      - user: akita
      - pkg: chruby
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
{% if grains['fqdn'] == capdeloy_host %}
      - groups:
        - teamcity
{% endif %}
      - createhome: true
      - shell: /bin/bash
      - require:
        - group: akita
{% if grains['fqdn'] == capdeloy_host %}
        - group: teamcity
{% endif %}

{% if grains['environment'] in ['vagrant', 'dev'] %}
{{ manage_authorized_keys('/home/akita/.ssh', 'akita', pillar['akita']['deployers'][grains['environment']], pillar['akita']['deploy_keys'][grains['environment']]) }}
{% else %}
{{ manage_authorized_keys('/home/akita/.ssh', 'akita', ssh_extra=pillar['akita']['deploy_keys'][grains['environment']]) }}
{% endif %}

# to talk from capdeploy to akita, only needed on akita box
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
        - chruby
        - libgmp-dev
        - libsqlite3-dev
        - libssl-dev
        - nodejs
        - plos-ruby-{{ ruby_ver }}
        - nodejs: {{ salt.pillar.get('akita:versions:nodejs') }} # from PLOS apt repo

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
    - source: salt://akita/home/akita/bash_profile
    - require:
       - user: akita

{% if grains['environment'] in ['vagrant', 'dev', 'qa'] %}

install-mailcatcher:
  cmd.run:
   - name: chruby-exec {{ ruby_ver }} -- gem install mailcatcher
   - unless: chruby-exec {{ ruby_ver }} -- mailcatcher --help
   - user: root
   - require:
     - pkg: chruby
     - pkg: plos-ruby

/etc/init/mailcatcher.conf:
  file.managed:
    - template: jinja
    - source: salt://akita/etc/init/mailcatcher.conf.sls
    - user: root
    - group: root

mailcatcher:
  service.running:
    - enable: True
    - require:
      - file: /etc/init/mailcatcher.conf

{% endif %}
