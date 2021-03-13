#
#
#
class profile_apache (
  Boolean        $create_default_vhost,
  String         $service_name,
) {
  class { 'apache':
    default_vhost   => false,
    service_restart => "apachectl configtest && systemctl restart ${service_name}",
  }

  if $create_default_vhost {
    profile_apache::vhost { 'default':
      ensure            => present,
      ssl               => false,
      priority          => 15,
      manage_sd_service => false,
      custom_fragment   => "
      <Location ~ \"^(?!server-status)\">
        Deny from all
        Options None
        ErrorDocument 403 \"403 Forbidden<br>(This is the default vhost.)\"
      </Location>"
    }
  }

  class { 'openssl':
    package_ensure         => present,
    ca_certificates_ensure => present,
  }

  include apache::mod::headers
  include apache::mod::proxy
  include apache::mod::proxy_http
  include apache::mod::status
}
