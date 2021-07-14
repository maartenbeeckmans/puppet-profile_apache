#
#
#
define profile_apache::vhost (
  Enum['present', 'absent'] $ensure                = present,
  String                    $servername            = $title,
  Array[String]             $serveraliases         = [],
  Optional                  $port                  = undef,
  Boolean                   $ssl                   = false,
  Boolean                   $manage_docroot        = true,
  String                    $docroot               = '/var/www/html',
  Optional[Array[Hash]]     $directories           = undef,
  Optional[Array[Hash]]     $aliases               = undef,
  Optional[Array[Hash]]     $proxy_pass            = undef,
  Array[String]             $setenv                = [],
  Boolean                   $manage_firewall_entry = true,
  Integer                   $priority              = 10,
  Boolean                   $manage_sd_service     = true,
  Optional[String]          $sd_service_name       = undef,
  String                    $sd_check_uri          = '',
  Array                     $sd_service_tags       = [],
  Optional[String]          $custom_fragment       = undef,
  String                    $service_name          = $::profile_apache::service_name,
) {
  $_real_port = $port ? {
    undef => $ssl ? {
      true  => 443,
      false => 80,
    },
    default => $port,
  }

  if $ensure == present {
    $_logroot_ensure = 'directory'
  } else {
    $_logroot_ensure = 'absent'
  }

  apache::vhost { "${servername}_${_real_port}":
    ensure          => $ensure,
    servername      => $servername,
    serveraliases   => $serveraliases,
    port            => $_real_port,
    docroot         => $docroot,
    priority        => $priority,
    directories     => $directories,
    aliases         => $aliases,
    proxy_pass      => $proxy_pass,
    custom_fragment => $custom_fragment,
    setenv          => $setenv,
    ssl             => $ssl,
    ssl_cert        => "/etc/ssl/certs/${servername}.crt",
    ssl_key         => "/etc/ssl/certs/${servername}.key",
    logroot         => "/var/log/${service_name}/${servername}_${_real_port}",
    logroot_ensure  => $_logroot_ensure,
    access_log_file => 'access.log',
    error_log_file  => 'error.log',
  }

  if $manage_firewall_entry {
    ensure_resource ( 'firewall',
      "000${_real_port} allow apache", {
        dport  => $_real_port,
        action => 'accept',
      }
    )
  }

  if $ssl {
    openssl::certificate::x509 { $servername:
      country      => 'BE',
      organization => $facts['networking']['domain'],
      commonname   => $servername,
      altnames     => $serveraliases,
    }
  }

  if $manage_sd_service {
    if $sd_service_name {
      $_sd_service_name = $sd_service_name
    } else {
      $_sd_service_name = "${servername}_${_real_port}"
    }
    $_service_check = $ssl ? {
      true  => {
        http            => "https://${servername}:${_real_port}/${sd_check_uri}",
        interval        => '10s',
        tls_skip_verify => true,
      },
      false => {
        http            => "http://${servername}:${_real_port}/${sd_check_uri}",
        interval        => '10s',
      },
    }
    consul::service { $_sd_service_name:
      checks => [$_service_check],
      port   => $_real_port,
      tags   => $sd_service_tags,
    }
  }
}
