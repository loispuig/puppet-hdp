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

	/*openssl::certificate::x509 { 'ssl-localhost':
		#ensure      => present,
		country      => ${country},
		organization => ${organization},
		commonname   => ${fqdn},
		state        => ${state},
		locality     => ${locality},
		unit         => ${unit},
		altnames     => [ 'localhost' ],
		email        => ${email},
		days         => 3650,
		base_dir     => '/var/www/ssl',
		owner        => 'www-data',
		group        => 'www-data',
		password     => 'root',
		force        => false,
		cnf_tpl      => 'hdp/cert.cnf.erb'
	}*/

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

	apache::vhost { 'localhost-ssl':
		servername => 'localhost',
		port    => '443',
		docroot => '/var/www',
		ssl     => true,
		ssl_cert => '/etc/ssl/private/cert.pem',
		ssl_key  => '/etc/ssl/private/key.pem',
		docroot_owner => 'www-data',
		docroot_group => 'www-data',
		options => [ 'Indexes', 'FollowSymLinks', 'MultiViews' ],
		custom_fragment => '#ProxyPassMatch "^/(.*\.php(/.*)?)$" "unix:/run/php/php7.0-fpm.sock|fcgi://127.0.0.1:9000/var/www/"
<FilesMatch \.php$>
    SetHandler "proxy:unix:/run/php/php7.0-fpm.sock|fcgi://localhost"
</FilesMatch>
Protocols h2 http/1.1',
		#SSLEngine on
		#SSLCertificateFile /etc/ssl/certs/your_cert
		#SSLCertificateChainFile /etc/ssl/certs/chained_certs
		#SSLCertificateKeyFile /etc/ssl/certs/your_private_key
		#SSLCipherSuite ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4
		#SSLHonorCipherOrder on
		#SSLProtocol all -SSLv2 -SSLv3
		#SSLCompression Off
		#Header add Strict-Transport-Security "max-age=15768000"
	}

	/*apache::vhost { 'hostnames.lamp':
		vhost_name      => '*',
		port            => '80',
		virtual_docroot => '/var/www/%-2+',
		docroot         => '/var/www',
		serveraliases   => ['*.vagrant',],
		docroot_owner   => 'www-data',
		docroot_group   => 'www-data',
		error_log_file  => "localhost.vagrant_error.log",
		custom_fragment => "ProxyPassInterpolateEnv On",
		rewrites		=> [
			{ rewrite_rule => ['.* - [E=SERVER_NAME:%{SERVER_NAME}]'] },
		],
		proxy_pass_match => [
			{ 'path' => '^(/.*\.php)$', 'url' => 'fcgi://127.0.0.1:9000/var/www/${SERVER_NAME}$1', 'keywords' => [ 'nocanon', 'interpolate' ] },
		],
	}*/

	# LetsEncrypt
	exec { 'certbot':
		command => "certbot --apache --domains ${letsencrypt_domains} --email ${letsencrypt_email} --agree-tos",
		path    => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
		require => [ Package['python-certbot-apache'], Apache::Vhost['localhost-ssl'] ],
		unless  => [ "test -f /etc/letsencrypt/live/damp.kctus.fr/cert.pem" ],
	} ->

	cron { 'certbot_cron':
		command => 'certbot renew --quiet',
		user    => 'root',
		hour    => '*/12',
		minute  => 0,
		month   => '*',
		monthday => '*',
		weekday => '*',
	}

	file_line { 'cdvarwww':
		line => 'cd /var/www',
		path => '/home/vagrant/.bashrc',
	}
}