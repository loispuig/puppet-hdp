# == Class: hdp
#
# Full description of class dotdeb here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { 'hdp':
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2016 Your name here, unless otherwise noted.
#
class hdp (
	$hostname = $::hdp::params::hostname,
	$domain = $::hdp::params::domain,
	$aliases = $::hdp::params::aliases,

	$letsencrypt = {
		install = $::hdp::params::letsencrypt::install,
		domains = $::hdp::params::letsencrypt::domains,
		email   = $::hdp::params::letsencrypt::email,
	}
	
	$dhparam = $::hdp::params::dhparam,
	$bits = $::hdp::params::bits,
	$hash = $::hdp::params::hash,
	$country = $::hdp::params::country,
	$state = $::hdp::params::state,
	$locality = $::hdp::params::locality,
	$organization = $::hdp::params::organization,
	$unit = $::hdp::params::unit,
	$email = $::hdp::params::email,
	$commonname = $::hdp::params::commonname,
	$altnames = $::hdp::params::altnames,
) inherits hdp::params  {
	anchor { 'hdp::begin': } ->
		class { '::hdp::source': } ->
		class { '::hdp::package': }
		class { '::hdp::config': }
	anchor { 'hdp::end': }
}
