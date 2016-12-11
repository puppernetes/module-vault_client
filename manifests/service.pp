class vault_client::service
{
  $systemd_dir = '/etc/systemd/system'
  $service_name = $::vault_client::token_service_name
  $frequency = 86400

  include ::systemd

  file { "${systemd_dir}/${service_name}.service":
    ensure  => file,
    content => template('vault_client/token-renewal.service.erb'),
    notify  => Exec['systemctl-daemon-reload'],
  } ~>
  exec { "${service_name}-trigger":
    command     => "systemctl start ${service_name}.service",
    path        => ['/bin', '/sbin', '/usr/bin', '/usr/sbin'],
    refreshonly => true,
    require     => Exec['systemctl-daemon-reload'],
  }

  file { "${systemd_dir}/${service_name}.timer":
    ensure  => file,
    content => template('vault_client/token-renewal.timer.erb'),
    notify  => Exec['systemctl-daemon-reload']
  } ~>
  service { "${service_name}.timer":
    ensure => 'running',
    enable => true,
  }

}
