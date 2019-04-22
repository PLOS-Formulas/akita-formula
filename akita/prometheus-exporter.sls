{% from "akita/map.jinja" import props with context %}
{% set ruby_ver  = props.get('prometheus_exporter_ruby_ver') %}
{% set user      = 'prometheus' %}
{% set user_home = '/opt/' ~ user %}
{% set app       = 'prometheus-exporter' %}
{% set app_home  = user_home ~ '/' ~ app %}
{% set oscodename = salt.grains.get('oscodename') %}

{{ app_home }}:
  file.directory:
    - user: {{ user }} 
    - group: {{ user }}
    - require:
      - user: {{ user }}

{{ user }}-ruby-{{ ruby_ver }}:
  pkg:
    - name: plos-ruby-{{ ruby_ver }}
    - installed

{{ user }}-install-bundler-{{ ruby_ver }}:
  cmd.run:
    - name: chruby-exec {{ ruby_ver }} -- gem install bundler -v 1.17.3
    - unless: chruby-exec {{ ruby_ver }} -- gem list | grep bundler > /dev/null 2>&1
    - cwd: {{ user_home }}
    - shell: /bin/bash
    - runas: {{ user }}
    - env:
      - HOME: {{ user_home }}
    - require:
      - user: {{ user }}
      - pkg: plos-ruby-{{ ruby_ver }}

{{ user_home }}/Gemfile:
  file.managed:
    - user: {{ user }}
    - group: {{ user }}
    - source: salt://akita/{{ app_home }}/Gemfile
    - require:
      - user: {{ user }} 

{{ app_home }}/.prometheus-exporter-rc:
  file.managed:
    - user: {{ user }}
    - group: {{ user }}
    - template: jinja
    - source: salt://akita/{{ app_home }}/prometheus-exporter-rc
    - require:
      - user: {{ user }} 
      - file: {{ app_home }}

{{ app_home }}/akita_collector.rb:
  file.managed:
    - user: {{ user }}
    - group: {{ user }}
    - source: salt://akita/{{ app_home }}/akita_collector.rb
    - require:
      - user: {{ user }} 
      - file: {{ app_home }}

{%- if oscodename == 'trusty' %}
/etc/init/{{ app }}.conf:
  file.managed:
    - source: salt://akita/etc/init/{{ app }}.conf
    - user: root
    - group: root

{{ app }}-upstart:
  service.running:
    - name: {{ app }}
    - enable: True
    - require:
      - file: /etc/init/{{ app }}.conf
{%- else %}
akita-exporter-unit-file:
  file.managed:
    - name: /etc/systemd/system/akita-exporter.service
    - source: salt://akita/etc/systemd/system/akita-exporter.service
    - template: jinja
    - defaults:
      home: {{ user_home }}

akita-exporter-service:
  service.running:
    - name: akita-exporter
    - enable: True
    - require:
      - akita-exporter-unit-file
      - akita-exporter-start-script

akita-exporter-start-script:
  file.managed:
    - name: {{ app_home }}/start-akita-exporter.sh
    - source: salt://akita/{{ app_home }}/start-akita-exporter.sh
    - user: {{ user }}
    - group: {{ user }}
    - mode: 744
{%- endif %}

