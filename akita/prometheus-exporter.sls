{% set ruby_ver = salt.pillar.get('akita:prometheus_exporter:ruby') %}
{% set user = 'prometheus-exporter' %}

prometheus-exporter:
  group:
    - present
    - gid: {{ salt.pillar.get('uids:prometheus_exporter:gid') }}
  user:
    - present
    - uid: {{ salt.pillar.get('uids:prometheus_exporter:uid') }}
    - gid: {{ salt.pillar.get('uids:prometheus_exporter:gid') }}
    - gid_from_name: true
    - createhome: true
    - shell: /bin/bash
    - require:
      - group: prometheus-exporter

{{ user }}-ruby-{{ ruby_ver }}:
  pkg:
    - name: plos-ruby-{{ ruby_ver }}
    - installed

{{ user }}-install-bundler-{{ ruby_ver }}:
  cmd.run:
    - name: chruby-exec {{ ruby_ver }} -- gem install bundler
    - unless: chruby-exec {{ ruby_ver }} -- gem list | grep bundler > /dev/null 2>&1
    - cwd: /home/{{ user }}
    - user: {{ user }}
    - group: {{ user }}
    - env:
      - HOME: /home/{{ user }}
    - require:
      - user: {{ user }}
      - pkg: plos-ruby-{{ ruby_ver }}

/home/prometheus-exporter/.bashrc:
  file.managed:
    - template: jinja
    - name: /home/prometheus-exporter/.bashrc
    - source: salt://akita/home/prometheus-exporter/bashrc
    - require:
      - user: prometheus-exporter

/home/prometheus-exporter/.bash_profile:
  file.managed:
    - user: prometheus-exporter
    - group: prometheus-exporter
    - require:
       - user: prometheus-exporter
    - contents: |
        if [ -f ~/.bashrc ]; then
          . ~/.bashrc
        fi
