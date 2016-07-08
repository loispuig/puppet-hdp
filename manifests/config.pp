class hdp::config inherits hdp {
	file { 'remove-default-html-directory':
		ensure => absent,
		path => '/var/www/html',
		recurse => true,
		purge => true,
		force => true,
		require => Class[ 'apache' ],
	} ->

	file { '/var/www/info.php':
		content => inline_template('<%= "<?php\nphpinfo();\n" %>'),
		owner => 'www-data',
		group => 'www-data',
		require => Class[ 'apache', 'php7' ],
	}

	exec { 'ssh-keygen':
		path    => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
		command => 'ssh-keygen -t rsa -b 4096 -N "" -C "" -q -f /vagrant/.ssh/id_rsa',
		unless  => [ "test -f /vagrant/.ssh/id_rsa" ],
		require => Package['openssh-server'],
	} ->

	file { "ssh-key-perms":
		path 	=> '/vagrant/.ssh/id_rsa',
		ensure  => present,
		owner   => 'vagrant',
		group   => 'vagrant',
		mode    => '0600',
	} ->

	exec { 'ssl-dhparam':
		path    => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
		command => "openssl dhparam ${dhparam} -out /etc/ssl/private/dh${dhparam}.pem",
		unless  => [ "test -f /etc/ssl/private/dh${dhparam}.pem" ],
		require => Package['openssl'],
	} ->

	# Set file access
	file { "ssl-dhparam-perms":
		path 	=> "/etc/ssl/private/dh${dhparam}.pem",
		ensure  => present,
		owner   => 'root',
		group   => 'root',
		mode    => '0600',
		require => Exec['ssl-dhparam'],
	} ->

	file { "ssl-conf":
		path 	=> '/etc/ssl/private/openssl.cnf',
		ensure  => present,
		owner   => 'root',
		group   => 'root',
		mode    => '0600',
		content => template('hdp/cert.cnf.erb'),
	} ->

	exec { 'ssl-gen-key':
		path    => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
		command => "openssl genrsa -out /etc/ssl/private/key.pem 4096",
		require => Package['openssl'],
	} ->

	exec { 'ssl-gen-cert':
		path    => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
		command => "openssl req -new -x509 -${hash} -days 3650 -extensions v3_ca -passin pass:root -config /etc/ssl/private/openssl.cnf -key /etc/ssl/private/key.pem -out /etc/ssl/private/cert.pem",
	}

	apache::vhost { 'localhost':
		servername => 'localhost',
		serveraliases => "${aliases}",
		port    => '80',
		docroot => '/var/www',
		docroot_owner => 'www-data',
		docroot_group => 'www-data',
		options => [ 'Indexes', 'FollowSymLinks', 'MultiViews' ],
		filters => [
            'FilterDeclare  COMPRESS',
            'FilterProvider COMPRESS DEFLATE "%{Content_Type} = \'text/html\'"',
            'FilterChain    COMPRESS',
            'FilterProtocol COMPRESS DEFLATE change=yes;byteranges=no',
		],
		custom_fragment => '#ProxyPassMatch "^/(.*\.php(/.*)?)$" "unix:/run/php/php7.0-fpm.sock|fcgi://127.0.0.1:9000/var/www/"
<FilesMatch \.php$>
    SetHandler "proxy:unix:/run/php/php7.0-fpm.sock|fcgi://localhost"
</FilesMatch>
Protocols h2c http/1.1',
	}

	if $letsencrypt[install] {
		$ssl_cert = '/etc/letsencrypt/live/damp.kctus.fr/fullchain.pem'
		$ssl_key = '/etc/letsencrypt/live/damp.kctus.fr/privkey.pem'
	}
	else {
		$ssl_cert = '/etc/ssl/private/cert.pem'
		$ssl_key = '/etc/ssl/private/key.pem'
	}

	apache::vhost { 'localhost-ssl':
		servername => 'localhost',
		serveraliases => "${aliases}",
		port    => '443',
		docroot => '/var/www',
		ssl     => true,
		ssl_cert => $ssl_cert,
		ssl_key  => $ssl_key,
		docroot_owner => 'www-data',
		docroot_group => 'www-data',
		options => [ 'Indexes', 'FollowSymLinks', 'MultiViews' ],
		custom_fragment => '<FilesMatch \.php$>
    SetHandler "proxy:unix:/run/php/php7.0-fpm.sock|fcgi://localhost"
</FilesMatch>
Protocols h2 http/1.1',
	}

	# LetsEncrypt
	if $letsencrypt[install] {

		$domains = split($letsencrypt[domains], ',')
		notice($domains[0])

		package { 'python-certbot-apache':
			ensure => 'installed',
			install_options => [ '-t jessie-backports' ],
			require => [ Exec['apt_upgrade'], Package['apache2'], Apache::Vhost['localhost-ssl'] ],
		} ->

		exec { 'certbot':
			command => "certbot --apache --domains ${letsencrypt[domains]} --email ${letsencrypt[email]} --agree-tos --non-interactive",
			path    => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
			require => [ Package['python-certbot-apache'], Apache::Vhost['localhost-ssl'] ],
			unless  => [ "test -f /etc/letsencrypt/live/${domains[0]}/cert.pem" ],
		} ->

		cron { 'certbot_cron':
			command  => 'certbot renew --quiet',
			user     => 'root',
			hour     => '*/12',
			minute   => 0,
			month    => '*',
			monthday => '*',
			weekday  => '*',
		}
	}
	else {
		package { 'python-certbot-apache':
			ensure => 'purged',
		}
	}

	file_line { 'cdvarwww':
		line => 'cd /var/www',
		path => '/home/vagrant/.bashrc',
	}
}