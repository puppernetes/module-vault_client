# == Class vault_client::config
#
# This class is called from vault_client for service config.
#
class vault_client::config {

  file { '/etc/sysconfig/vault':
    ensure  => file,
    content => template('vault_client/vault.erb'),
  }

  file { [ '/etc/etcd', '/etc/etcd/ssl', '/etc/etcd/ssl/certs' ]:
    ensure => directory,
  }

  user { 'etcd user for vault':
    ensure => present,
    name   => 'etcd',
    uid    => 873,
    shell  => '/sbin/nologin',
    home   => '/var/lib/etcd',
  }

  if $vault_client::role == 'master' or $vault_client::role == 'worker' {

  file { [ '/etc/kubernetes', '/etc/kubernetes/ssl', '/etc/kubernetes/ssl/certs' ]:
    ensure => directory,
  }

  user { 'k8s user for vault':
      ensure => present,
      name   => 'k8s',
      uid    => 837,
      shell  => '/sbin/nologin',
      home   => '/var/lib/kubernetes',
    }
  }

  if $vault_client::role == 'master' or $vault_client::role == 'etcd' {
    exec { 'In dev mode get CA for etcd k8s':
      command => "/bin/bash -c 'source /etc/sysconfig/vault; /usr/bin/vault read -address=\$VAULT_ADDR -field=certificate \$CLUSTER_NAME/pki/etcd-k8s/cert/ca > /etc/etcd/ssl/certs/etcd-k8s.pem'",
      unless  => "/bin/bash -c 'source /etc/sysconfig/vault; /usr/bin/vault read -address=\$VAULT_ADDR -field=certificate \$CLUSTER_NAME/pki/etcd-k8s/cert/ca | diff -P /etc/etcd/ssl/certs/etcd-k8s.pem -'",
      require => File['/etc/etcd/ssl/certs'],
    }

    vault_client::etcd_cert_service { 'k8s':
      etcd_cluster => 'k8s',
      frequency    => '1d',
      role         => $vault_client::role,
      notify       => Exec['Trigger etcd k8s cert'],
      require      => [ File['/etc/etcd/ssl'], User['etcd user for vault'] ],
    }

    service { 'etcd-k8s-cert.timer':
      provider => systemd,
      enable   => true,
      require  => [ File['/usr/lib/systemd/system/etcd-k8s-cert.timer'], Exec['In dev mode get CA for etcd k8s'] ],
    }

    exec { 'Trigger etcd k8s cert':
      command => '/usr/bin/systemctl start etcd-k8s-cert.service',
      user    => 'root',
      unless  => '/usr/bin/openssl x509 -checkend 3600 -in /etc/etcd/ssl/certs/etcd-k8s-cert.pem | /usr/bin/grep "Certificate will not expire"',
  }

    exec { 'In dev mode get CA for etcd events':
      command => "/bin/bash -c 'source /etc/sysconfig/vault; /usr/bin/vault read -address=\$VAULT_ADDR -field=certificate \$CLUSTER_NAME/pki/etcd-events/cert/ca > /etc/etcd/ssl/certs/etcd-events.pem'",
      unless  => "/bin/bash -c 'source /etc/sysconfig/vault; /usr/bin/vault read -address=\$VAULT_ADDR -field=certificate \$CLUSTER_NAME/pki/etcd-events/cert/ca | diff -P /etc/etcd/ssl/certs/etcd-events.pem -'",
      require => File['/etc/etcd/ssl/certs'],
    }

    vault_client::etcd_cert_service { 'events':
      etcd_cluster => 'events',
      frequency    => '1d',
      role         => $vault_client::role,
      notify       => Exec['Trigger etcd events cert'],
      require      => [ File['/etc/etcd/ssl'], User['etcd user for vault'] ],
    }

    service { 'etcd-events-cert.timer':
      provider => systemd,
      enable   => true,
      require  => [ File['/usr/lib/systemd/system/etcd-events-cert.timer'], Exec['In dev mode get CA for etcd events'] ],
    }

    exec { 'Trigger etcd events cert':
      command => '/usr/bin/systemctl start etcd-events-cert.service',
      user    => 'root',
      unless  => '/usr/bin/openssl x509 -checkend 3600 -in /etc/etcd/ssl/certs/etcd-events-cert.pem | /usr/bin/grep "Certificate will not expire"',
    }
  }

  exec { 'In dev mode get CA for overlay':
    command => "/bin/bash -c 'source /etc/sysconfig/vault; /usr/bin/vault read -address=\$VAULT_ADDR -field=certificate \$CLUSTER_NAME/pki/etcd-overlay/cert/ca > /etc/etcd/ssl/certs/etcd-overlay.pem'",
    unless  => "/bin/bash -c 'source /etc/sysconfig/vault; /usr/bin/vault read -address=\$VAULT_ADDR -field=certificate \$CLUSTER_NAME/pki/etcd-overlay/cert/ca | diff -P /etc/etcd/ssl/certs/etcd-overlay.pem -'",
    require => File['/etc/etcd/ssl/certs'],
  }

  #not used for now
  exec { 'update CA trust':
    command     => '/usr/bin/update-ca-trust',
    refreshonly => true,
  }

  vault_client::etcd_cert_service { 'overlay':
    etcd_cluster => 'overlay',
    frequency    => '1d',
    role         => $vault_client::role,
    notify       => Exec['Trigger etcd overlay cert'],
    require      => [ File['/etc/etcd/ssl'], User['etcd user for vault'] ],
  }

  service { 'etcd-overlay-cert.timer':
    provider => systemd,
    enable   => true,
    require  => [ File['/usr/lib/systemd/system/etcd-overlay-cert.timer'], Exec['In dev mode get CA for overlay'] ],
  }

  exec { 'Trigger etcd overlay cert':
    command => '/usr/bin/systemctl start etcd-overlay-cert.service',
    user    => 'root',
    unless  => '/usr/bin/openssl x509 -checkend 3600 -in /etc/etcd/ssl/certs/etcd-overlay-cert.pem | /usr/bin/grep "Certificate will not expire"',
    require => File['/usr/lib/systemd/system/etcd-overlay-cert.service'],
  }

  if $vault_client::role == 'worker' or $vault_client::role == 'master' {
    exec { 'In dev mode get CA for k8s':
      command => "/bin/bash -c 'source /etc/sysconfig/vault; /usr/bin/vault read -address=\$VAULT_ADDR -field=certificate \$CLUSTER_NAME/pki/k8s/cert/ca > /etc/kubernetes/ssl/certs/k8s.pem'",
      unless  => "/bin/bash -c 'source /etc/sysconfig/vault; /usr/bin/vault read -address=\$VAULT_ADDR -field=certificate \$CLUSTER_NAME/pki/k8s/cert/ca | diff -P /etc/kubernetes/ssl/certs/k8s.pem -'",
      require => File['/etc/kubernetes/ssl/certs'],
    }

    vault_client::k8s_cert_service { 'kubelet':
      k8s_component => 'kubelet',
      frequency     => '1d',
      role          => $vault_client::role,
      notify        => Exec['Trigger k8s kubelet cert'],
      require       => [ File['/etc/kubernetes/ssl'], User['k8s user for vault'] ],
    }

    exec { 'Trigger k8s kubelet cert':
      command     => '/usr/bin/systemctl start k8s-kubelet-cert.service',
      user        => 'root',
      refreshonly => true,
    }

    service { 'k8s-kubelet-cert.timer':
      provider => systemd,
      enable   => true,
      require  => [ File['/usr/lib/systemd/system/k8s-kubelet-cert.timer'], Exec['In dev mode get CA for k8s'] ],
    }

    vault_client::k8s_cert_service { 'kube_proxy':
      k8s_component => 'kube-proxy',
      frequency     => '1d',
      role          => $vault_client::role,
      notify        => Exec['Trigger k8s kube proxy cert'],
      require       => [ File['/etc/kubernetes/ssl'], User['k8s user for vault'] ],
    }

    exec { 'Trigger k8s kube proxy cert':
      command     => '/usr/bin/systemctl start k8s-kube-proxy-cert.service',
      user        => 'root',
      refreshonly => true,
    }

    service { 'k8s-kube-proxy-cert.timer':
      provider => systemd,
      enable   => true,
      require  => [ File['/usr/lib/systemd/system/k8s-kube-proxy-cert.timer'], Exec['In dev mode get CA for k8s'] ],
    }
  }

  if $vault_client::role == 'master' {
    vault_client::k8s_cert_service { 'kube_apiserver':
      k8s_component => 'kube-apiserver',
      frequency     => '1d',
      role          => $vault_client::role,
      notify        => Exec['Trigger k8s kube apiserver cert'],
      require       => [ File['/etc/kubernetes/ssl'], User['k8s user for vault'] ],
    }

    exec { 'Trigger k8s kube apiserver cert':
      command     => '/usr/bin/systemctl start k8s-kube-apiserver-cert.service',
      user        => 'root',
      refreshonly => true,
    }

    service { 'k8s-kube-apiserver-cert.timer':
      provider => systemd,
      enable   => true,
      require  => [ File['/usr/lib/systemd/system/k8s-kube-apiserver-cert.timer'], Exec['In dev mode get CA for k8s'] ],
    }

    vault_client::k8s_cert_service { 'kube_scheduler':
      k8s_component => 'kube-scheduler',
      frequency     => '1d',
      role          => $vault_client::role,
      notify        => Exec['Trigger k8s kube scheduler cert'],
      require       => [ File['/etc/kubernetes/ssl'], User['k8s user for vault'] ],
    }

    exec { 'Trigger k8s kube scheduler cert':
      command     => '/usr/bin/systemctl start k8s-kube-scheduler-cert.service',
      user        => 'root',
      refreshonly => true,
    }

    service { 'k8s-kube-scheduler-cert.timer':
      provider => systemd,
      enable   => true,
      require  => [ File['/usr/lib/systemd/system/k8s-kube-scheduler-cert.timer'], Exec['In dev mode get CA for k8s'] ],
    }

    vault_client::k8s_cert_service { 'kube_controller_manager':
      k8s_component => 'kube-controller-manager',
      frequency     => '1d',
      role          => $vault_client::role,
      notify        => Exec['Trigger k8s kube controller manager cert'],
      require       => [ File['/etc/kubernetes/ssl'], User['k8s user for vault'] ],
    }

    exec { 'Trigger k8s kube controller manager cert':
      command     => '/usr/bin/systemctl start k8s-kube-controller-manager-cert.service',
      user        => 'root',
      refreshonly => true,
    }

    service { 'k8s-kube-controller-manager-cert.timer':
      provider => systemd,
      enable   => true,
      require  => [ File['/usr/lib/systemd/system/k8s-kube-controller-manager-cert.timer'], Exec['In dev mode get CA for k8s'] ],
    }
  }
}
