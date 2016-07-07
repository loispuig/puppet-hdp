class hdp::params {
	$hostname       = 'hdp'
	$domain         = 'vg'
	$aliases        = false
	# SSL
	$dhparam 		= 512
	$bits			= 4096
	$hash			= 'sha512'
	$days			= 3650
	$country		= 'US'
	$state			= 'State or Providence'
	$locality 		= 'My Town'
	$organization	= 'My Company'
	$unit 			= 'IT'
	$email 			= 'admin@localhost'
	$commonname		= '127.0.0.1'
	$altnames 		= [ 'localhost' ]
}