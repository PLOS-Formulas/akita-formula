{%- from "lib/git.sls" import github_setup %}
{% set ruby_ver = salt.pillar.get('akita:versions:ruby') %}
{% from 'lib/auth_keys.sls' import manage_authorized_keys %}
{% from 'lib/environment.sls' import environment %}
{% set capdeloy_host = salt['pillar.get']('environment:' ~ environment ~ ':capdeploy', 'None') %}

include:
  - nginx
  - common.packages
  - common.repos
  - akita.ruby

akita-install-bundler:
  cmd.run:
    - name: chruby-exec {{ ruby_ver }} -- gem install bundler
    - unless: chruby-exec {{ ruby_ver }} -- gem list | grep bundler > /dev/null 2>&1
    - cwd: /home/akita
    - user: akita
    - group: akita
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

/home/akita/akita-envs.sh:
  file.managed:
    - template: jinja
    - name: /home/akita/akita-envs.sh
    - source: salt://akita/home/akita/akita-envs.sh
    - require:
      - user: akita

/home/akita/.bashrc:
  file.managed:
    - template: jinja
    - name: /home/akita/.bashrc
    - require:
      - user: akita
    - contents: |
        source /usr/share/chruby/chruby.sh
        source /usr/share/chruby/auto.sh
        chruby {{ salt.pillar.get('akita:versions:ruby') }}
        source akita-envs.sh

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

{% if salt['file.file_exists' ]("/etc/init/akita.conf") %}
akita_restart_for_configs:
  service.running:
    - name: akita
    - watch:
      - file: /home/akita/.bashrc
{% endif %}
