# == Class: hpinsight
#
# Manage HP Insight
#
class hpinsight(
  $snmp_manage             = false,
  $snmp_rocommunity        = undef,
  $snmp_rocommunity_allow  = undef,
  $snmp_trapcommunity      = undef,
  $snmp_trapsink_host      = undef,
  $snmp_trapsink_community = undef,
) {

# Load default parameters according to OS

  case $::osfamily {
    'RedHat', 'Suse': {
      $hpi_packages    = 'hp-health'
      $snmp_package    = 'net-snmp'
      $hp_snmp_package = 'hp-snmp-agents'
      $snmp_service    = 'snmpd'
      $snmp_config     = '/etc/snmp/snmpd.conf'
      case $::architecture {
        'x86_64': {
          $snmp_dlmod = '/usr/lib64/libcmaX64.so'
        }
        default: {
          $snmp_dlmod = '/usr/lib/libcmaX.so'
        }
      }

    }
    'Debian': {
      $hpi_packages = 'hp-health'
      $snmp_package = 'snmpd'
      $snmp_service = 'snmpd'
      $snmp_config  = '/etc/snmp/snmpd.conf'
      $snmp_dlmod   = '/usr/lib64/libcmaX64.so'
    }
    default: {
      fail("supports osfamilies RedHat, Suse and Debian. Detected osfamily <${::osfamily}>.")
    }
  }

# Validation of input, to check only bool supplied
  validate_bool($snmp_manage)
  
  
# Package Installation
# For Virtual - No HP packages
  if $::manufacturer == 'HP' and $::virtual == 'physical' {
    package {[$hpi_packages, $hp_snmp_package]:
      ensure  => present }

      # HP Storage - raid management tools, need to check HW model also
      # hpssacli HP SSA is now standard, please check for requirement of hpacucli
      # http://h20564.www2.hpe.com/hpsc/swd/public/detail?swItemId=MTX_b6a6acb9762443b182280db805#tab1
      # Site specific requirement for hpacucli
    if $::operatingsystemmajrelease < 7 {
      package { 'hpacucli':
      ensure => 'present',
     }
    } else {
      package {'hpssacli':
      ensure => 'present',
    }
    }
    # Service Configuration and Setup
    # HP Insight - Service Configuration

    service { 'hp-snmp-agents':
      ensure  => running,
      status  => 'pgrep cmahealthd',
      require => Package[$hpi_packages],
    }

    service { 'hp-health':
      ensure  => running,
      status  => 'hpasmxld || pgrep hpasmlited',
      require => Package[$hpi_packages],
    }
  }

# SNMP for all- physical or virtual
  package { $snmp_package:
    ensure => present,
  }


# SNMP  - Service configuration

  if $snmp_manage == true {
    validate_string($snmp_dlmod)
    validate_string($snmp_rocommunity)
    validate_string($snmp_rocommunity_allow)
    validate_string($snmp_trapcommunity)
    validate_string($snmp_trapsink_host)
    validate_string($snmp_trapsink_community)


    file { $snmp_config:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      backup  => true,
      content => template('hpinsight/snmpd.conf.erb'),
      require => Package[$snmp_package],
      notify  => Service[$snmp_service],
    }

    service {$snmp_service:
      ensure => running,
      enable => true,
    }
  }
}
