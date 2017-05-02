description "mailcatcher"

start on started and runlevel [2345]
stop on shutdown

respawn
respawn limit 5 15

setuid akita
setgid akita

script
exec /bin/bash << EOT
  chruby-exec {{ salt.pillar.get('akita:versions:ruby') }} -- mailcatcher -f --ip 0.0.0.0
EOT
end script
