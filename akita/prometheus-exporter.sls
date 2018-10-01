{% set ruby_ver = salt.pillar.get('akita:prometheus_exporter:ruby') %}
{% set app  = 'prometheus-exporter' %}
{% set user = app %}
{% set home = '/home/' ~ user %}

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

/etc/sudoers.d/prometheus-exporter:
  file.managed:
    - template: jinja
    - source: salt://akita/etc/sudoers.d/prometheus-exporter

{{ home }}/.bashrc:
  file.managed:
    - template: jinja
    - source: salt://akita/home/prometheus-exporter/bashrc
    - require:
      - user: {{ user }} 

{{ home }}/.bash_profile:
  file.managed:
    - user: {{ user }}
    - group: {{ user }}
    - require:
       - user: {{ user }} 
    - contents: |
        if [ -f ~/.bashrc ]; then
          . ~/.bashrc
        fi

{{ home }}/Gemfile:
  file.managed:
    - user: {{ user }}
    - group: {{ user }}
    - source: salt://akita/home/prometheus-exporter/Gemfile
    - require:
      - user: {{ user }} 

{{ home }}/run-prometheus-exporter.sh:
  file.managed:
    - user: {{ user }}
    - group: {{ user }}
    - mode: 0755
    - source: salt://akita/home/prometheus-exporter/run-prometheus-exporter.sh
    - require:
      - user: {{ user }} 

{{ home }}/akita_collector.rb:
  file.managed:
    - user: {{ user }}
    - group: {{ user }}
    - source: salt://akita/home/prometheus-exporter/akita_collector.rb
    - require:
      - user: {{ user }} 

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
