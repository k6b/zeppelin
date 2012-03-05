#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use DBD::mysql;
use Digest::MD5 qw(md5_hex);
use JSON;
use LWP::UserAgent;
use Net::RackSpace::CloudServers;
use Net::RackSpace::CloudServers::Server;

our %settings = do "./.zeppelin.config";

if (!$settings{db}) {
	print "Database type undefined.\n";
	if ($settings{db} =~ m/mysql/) {
		if (!$settings{mysqlhost}) {
			print "MySQL host undefined.\n";
			} 
		if (!$settings{mysqluser}) {
			print "MySQL user undefined.\n";
			} 
		if (!$settings{mysqlpass}) {
			print "MySQL pass undefined.\n";
			}
	} elsif ($settings{db} =~ m/sqlite/) {
		if (!$settings{sqlitedb}) {
			print "SQLite database undefined.\n";
			}
		}
	} 
if (!$settings{apiuser}) {
	print "API user undefined.\n";
	}
if (!$settings{apikey}) {
	print "API key undefined.\n";
	}
if (!$settings{account}) {
	print "Cloud account # undefined.\n";
	}
if (!$settings{lbloc}) {
	print "Load balancer location undefined.\n";
	}

sub DBConnect {
	if ($settings{db} =~ m/sqlite/i) {
		# Connect to SQLite database:
		our $db = DBI->connect("dbi:SQLite:dbname=$settings{sqlitedb}","","")
			|| die "Cannot connect to Database!";
	} elsif ($settings{db} =~ m/mysql/i) {
		#Connect to MySQL database;
		my $da = "DBI:mysql:database=$settings{mysqldb};host=$settings{mysqlhost}";
		our $db = DBI->connect( $da, $settings{mysqluser}, $settings{mysqlpass} )
			|| die "Cannot connect to Database!";
	} else {
		print "Configuration error.\n";
		}
	return our $db;
	}

sub DBDisconnect {
	our $db->disconnect();
	}

# Cloud API Key and username:

my $cs = Net::RackSpace::CloudServers->new( user => $settings{apiuser}, key => $settings{apikey} );

our $identity = LWP::UserAgent->new;
$identity->agent("Zeppelin/$zeppelin_version");
our $zeppelin_version = "0.5.2";

# us api endpoint
our $api_url = 'https://auth.api.rackspacecloud.com/v1.0';
our $load_balancer_url = "https://$settings{lbloc}.loadbalancers.api.rackspacecloud.com/v1.0/$settings{account}/loadbalancers/";

sub AuthRequest {
	# create request
	my $req = HTTP::Request->new(
		'GET',
		$api_url,
		[
			'X-Auth-User' 	=> 	$settings{apiuser},
			'X-Auth-Key'	=>	$settings{apikey}
			]
		);
	# send request
	my $res = $identity->request($req);
	# check the outcome
	if ($res->is_success) {
		our $auth_token = $res->header( 'X-Auth-Token' );
		our $storage_token = $res->header( 'X-Storage-Token' );
		our $server_url = $res->header( 'X-Server-Management-Url' );
		our $cdn_url =  $res->header( 'X-CDN-Management-Url' );
		our $storage_url = $res->header( 'X-Storage-Url' );
	} else {
		print "Error: " . $res->status_line . "\n";
		}
	return our $auth_token;
	return our $server_url;
	}

sub MakeRequest {
	my $method = $_[0];
	my $uri = $_[1];
	my $req = HTTP::Request->new(
		$method,
		$uri,
		[
			'X-Auth-Token'	=> 	our $auth_token
			]
		);
	# send request
	my $res = $identity->request($req);
	# check the outcome
	if ($res->is_success) {
		our $x_purge_key = $res->header( 'X-PURGE-KEY' );
		our $cache_control = $res->header( 'Cache-Control' );
		our $x_varnish = $res->header( 'X-Varnish' );
		our $age =  $res->header( 'Age' );
		our $content = $res->decoded_content;
	} else {
		print "Error: " . $res->status_line . "\n";
		}
	return our $content;
	}

sub UpdateDB {
	sub UpdateServers {
		&DBConnect();
		foreach my $del_server(our @del_servers) {
			print " Removing: $del_server\n";
			my $del_old_server = our $db->prepare("DELETE FROM servers WHERE sum = '$del_server';");
			$del_old_server->execute();
			}
		&DBDisconnect();
		our $server_url;
		my $json = new JSON;
		&MakeRequest("GET", "$server_url/servers/detail");
		my $server_list = our $content;
		my $json_list = $json->decode($server_list);
		&DBConnect();
		foreach my $serverdetail ( @{$json_list->{servers}}) {
			our $server_id = $serverdetail->{id};
			our $hostname = $serverdetail->{name};
			our $status = $serverdetail->{status};
			our $public_ip = "@{$serverdetail->{addresses}->{public}}";
			our $private_ip = "@{$serverdetail->{addresses}->{private}}";
			our $distro = $serverdetail->{imageId};
			our $flavor = $serverdetail->{flavorId};
			our $hostid = $serverdetail->{hostId};
			our $server_checksum = md5_hex( "$server_id$hostname$status$public_ip$private_ip$distro$flavor" );
			my $server_check = our $db->prepare("SELECT sum, COUNT(sum) count FROM servers WHERE sum = '$server_checksum';");
			$server_check->execute();
			my $check = $server_check->fetchrow_hashref();
			if ($check->{'count'} == 0) {
				print " Adding $server_checksum\n";
				my $server_add = $db->prepare("INSERT INTO servers (id, hostname, distro, public_ip, private_ip, flavor, status, sum) VALUES ('$server_id', '$hostname', '$distro', '$public_ip', '$private_ip', '$flavor', '$status', '$server_checksum')");
				$server_add->execute();
				}
			}
		&DBDisconnect();
		}
	sub UpdateBackups {
		&DBConnect();
		foreach my $del_backup(our @del_backups) {
			print " Removing: $del_backup\n";
			my $del_old_backup = our $db->prepare("DELETE FROM backups WHERE sum = '$del_backup';");
			$del_old_backup->execute();
			}
		&DBDisconnect();
		our $server_url;
		my $json = new JSON;
		&MakeRequest("GET", "$server_url/images/detail");
		my $backup_list = our $content;
		my $json_list = $json->decode($backup_list);
		foreach my $image ( @{$json_list->{images}} ) {
			if ( $image->{id} > 300 ) {
				our $image_id = $image->{id};
				our $name = $image->{name};
				my $created = $image->{created};
				our @created = split('T', $created);
				my $updated = $image->{updated};
				our @updated = split('T', $updated);
				our $server = $image->{serverId};
				our $image_checksum = md5_hex( "$image_id$name$created$updated$server" );
				}
			&DBConnect();
			our $image_id;
			if ($image_id) {
				our ($image_checksum, $name, @created, $server);
				my $server_check = our $db->prepare("SELECT sum, COUNT(sum) count FROM backups WHERE sum = '$image_checksum';");
				$server_check->execute();
				my $check = $server_check->fetchrow_hashref();
				if ($check->{'count'} == 0) {
					print " Adding: $image_checksum\n";
					my $server_add = $db->prepare("INSERT INTO backups ( id, name, created_date, created_time, server, sum ) VALUES ('$image_id', '$name', '$created[0]', '$created[1]', '$server', '$image_checksum')");
					$server_add->execute();
					}
				}
			&DBDisconnect();
			}
		}
	sub UpdateDistros {
		&DBConnect();
		foreach my $del_distro(our @del_distros) {
			print " Removing: $del_distro\n";
			my $del_old_distro = our $db->prepare("DELETE FROM distros WHERE sum = '$del_distro';");
			$del_old_distro->execute();
			}
		&DBDisconnect();
		our $server_url;
		my $json = new JSON;
		&MakeRequest("GET", "$server_url/images/");
		my $image_list = our $content;
		my $json_list = $json->decode($image_list);
		foreach my $image ( @{$json_list->{images}} ) {
			if ( $image->{id} < 300 ) {
				our $distro_id = $image->{id};
				our $name = $image->{name};
				our $distro_checksum = md5_hex( "$distro_id$name" );
				}
			&DBConnect();
			our ($distro_id, $distro_checksum, $name);
			if ($distro_id) {
				my $server_check = our $db->prepare("SELECT sum, COUNT(sum) count FROM distros WHERE sum = '$distro_checksum';");
				$server_check->execute();
				my $check = $server_check->fetchrow_hashref();
				if ($check->{'count'} == 0) {
					print " Adding: $distro_checksum\n";
					my $server_add = $db->prepare("INSERT INTO distros ( id, distro, sum ) VALUES ('$distro_id', '$name', '$distro_checksum')");
					$server_add->execute();
					}
				}
			&DBDisconnect();
			}
		}
	sub UpdateFlavors {
		&DBConnect();
		foreach my $del_flavor(our @del_flavors) {
			print " Removing: $del_flavor\n";
			my $del_old_flavor = our $db->prepare("DELETE FROM flavors WHERE sum = '$del_flavor';");
			$del_old_flavor->execute();
			}
		&DBDisconnect();
		our $server_url;
		my $json = new JSON;
		&MakeRequest("GET", "$server_url/flavors/detail");
		my $flavor_list = our $content;
		my $json_list = $json->decode($flavor_list);
		&DBConnect();
		foreach my $flavor ( @{$json_list->{flavors}} ) {
			our $flavor_id = $flavor->{id};
			our $flavor_name = $flavor->{name};
			our $flavor_ram = $flavor->{ram};
			our $flavor_disk = $flavor->{disk};
			our $flavor_checksum = md5_hex( "$flavor_id$flavor_name$flavor_ram$flavor_disk" );
			my $flavor_check = our $db->prepare("SELECT sum, COUNT(sum) count FROM flavors WHERE sum = '$flavor_checksum';");
			$flavor_check->execute();
			my $check = $flavor_check->fetchrow_hashref();
			if ($check->{'count'} == 0) {
				print " Adding: $flavor_checksum\n";
				my $flavor_add = $db->prepare("INSERT INTO flavors ( id, flavor, ram, disk, sum ) VALUES ('$flavor_id', '$flavor_name', '$flavor_ram', '$flavor_disk', '$flavor_checksum')");
				$flavor_add->execute();
				}
			}
		&DBDisconnect();
		}
	sub FindExistingInfo {
		&DBConnect();
		our $db;
		my $existing_servers = $db->prepare("SELECT sum FROM servers;");
		$existing_servers->execute();
		while (my $ref = $existing_servers->fetchrow_arrayref) {
			push(our @existing_servers, $ref->[0]);
			}
		my $existing_backups = $db->prepare("SELECT sum FROM backups;");
		$existing_backups->execute();
		while (my $ref = $existing_backups->fetchrow_arrayref) {
			push(our @existing_backups, $ref->[0]);
			}
		my $existing_distros = $db->prepare("SELECT sum FROM distros;");
		$existing_distros->execute();
		while (my $ref = $existing_distros->fetchrow_arrayref) {
			push(our @existing_distros, $ref->[0]);
			}
		my $existing_flavors = $db->prepare("SELECT sum FROM flavors;");
		$existing_flavors->execute();
		while (my $ref = $existing_flavors->fetchrow_arrayref) {
			push(our @existing_flavors, $ref->[0]);
			}
		&DBDisconnect();
		}
	sub GetServerList {
		our $server_url;
		my $json = new JSON;
		&MakeRequest("GET", "$server_url/servers/detail");
		my $server_list = our $content;
		our $json_list = $json->decode($server_list);
		foreach my $server ( @{$json_list->{servers}} ) {
			my $new_server_sum = md5_hex( $server->{id} . $server->{name} . $server->{status} . "@{$server->{addresses}->{public}}" . "@{$server->{addresses}->{private}}" . $server->{imageId} . $server->{flavorId} );
			push(our @new_servers, $new_server_sum);
			}
		}
	sub GetBackupList {
		our $server_url;
		our $json = new JSON;
		&MakeRequest("GET", "$server_url/images/detail");
		our $backup_list = our $content;
		our $json_list = $json->decode($backup_list);
		foreach our $backup ( @{$json_list->{images}} ) {
			if (($backup->{id} > 300)) {
				my $new_backup_sum = md5_hex( $backup->{id} . $backup->{name} . $backup->{created} . $backup->{updated} . $backup->{serverId} );
				push(our @new_backups, $new_backup_sum);
				}
			}
		}
	sub GetImageList {
		our $server_url;
		my $json = new JSON;
		&MakeRequest("GET", "$server_url/images/");
		my $distro_list = our $content;
		my $json_list = $json->decode($distro_list);
		foreach my $distro ( @{$json_list->{images}} ) {
			if ($distro->{id} < 300) {
				my $new_distro_sum = md5_hex( $distro->{id} . $distro->{name} );
				push(our @new_distros, $new_distro_sum);
				}
			}
		}
	sub GetFlavorsList {
		our $server_url;
		my $json = new JSON;
		&MakeRequest("GET", "$server_url/flavors/detail");
		my $flavor_list = our $content;
		my $json_list = $json->decode($flavor_list);
		foreach my $flavor ( @{$json_list->{flavors}} ) {
			if ( $flavor->{id} ) {
				my $new_flavor_sum = md5_hex( $flavor->{id} . $flavor->{name} . $flavor->{ram} . $flavor->{disk} );
				push(our @new_flavors, $new_flavor_sum);
				}
			}
		}
	&FindExistingInfo();
	&GetServerList();
	&GetImageList();
	&GetBackupList();
	&GetFlavorsList();
	our @add_servers = grep { my $x = $_; not grep { $x =~ /\Q$_/i } our @existing_servers } our @new_servers;
	our @del_servers = grep { my $x = $_; not grep { $x =~ /\Q$_/i } @new_servers } our @existing_servers;
	my $diff_servers = @add_servers + @del_servers;
	our @add_backups = grep { my $x = $_; not grep { $x =~ /\Q$_/i } our @existing_backups } our @new_backups;
	our @del_backups = grep { my $x = $_; not grep { $x =~ /\Q$_/i } @new_backups } our @existing_backups;
	my $diff_backups = @add_backups + @del_backups;
	our @add_distros = grep { my $x = $_; not grep { $x =~ /\Q$_/i } our @existing_distros } our @new_distros;
	our @del_distros = grep { my $x = $_; not grep { $x =~ /\Q$_/i } @new_distros } our @existing_distros;
	my $diff_distros = @add_distros + @del_distros;
	our @add_flavors = grep { my $x = $_; not grep { $x =~ /\Q$_/i } our @existing_flavors } our @new_flavors;
	our @del_flavors = grep { my $x = $_; not grep { $x =~ /\Q$_/i } @new_flavors } our @existing_flavors;
	my $diff_flavors = @add_flavors + @del_flavors;
	my $diff = $diff_servers + $diff_backups + $diff_distros + $diff_flavors;
	print "Checking database...\n";
	if ( $diff > 0 ) {
		print "Updating database...\n";
		if ( $diff_servers > 0 ) {
			print ":Updating servers...\n";
			&UpdateServers();
			}
		if ( $diff_backups > 0 ) {
			print ":Updating backups...\n";
			&UpdateBackups();
			}
		if ( $diff_distros > 0 ) {
			print ":Updating distro list...\n";
			&UpdateDistros();
			}
		if ( $diff_flavors > 0 ) {
			print ":Updating flavor list...\n";
			&UpdateFlavors();
			}		
		print "Update complete.\n";
	} else {
		print "Database up to date.\n";
		}
	}

sub ListServers {
	&DBConnect();
	my $current_servers = our $db->prepare("SELECT servers.id,hostname,distros.distro,public_ip,private_ip,flavors.ram,flavors.disk,status FROM servers,distros,flavors WHERE servers.distro = distros.id AND servers.flavor = flavors.id ORDER BY distros.distro ASC, hostname ASC;");
	$current_servers->execute();
	print sprintf("%-9.9s%30.30s%30.30s%16.16s%16.16s%6.6s%7.7s\n", "id", "hostname", "distro", "public ip", "private ip", "ram", "disk");
	while (my $ref = $current_servers->fetchrow_arrayref) {
		print sprintf("%-9.9s%30.30s%30.30s%16.16s%16.16s%6.5s%4.4s GB\n", $ref->[0], $ref->[1], $ref->[2], $ref->[3], $ref->[4], $ref->[5], $ref->[6]);
		}
	&DBDisconnect();
	}

sub GetServerDetail {
	&ListServers();
	print "\nid: ";
	my $server_id = <STDIN>;
	&DBConnect();
	my $server_detail = our $db->prepare("SELECT * FROM servers WHERE id = '$server_id';");
	$server_detail->execute();
	while (my $ref = $server_detail->fetchrow_arrayref) {
		print "id:\t$ref->[0]\thostname:\t$ref->[1]\ndistro:\t$ref->[2]\tstatus:\t$ref->[7]\n";
		print "public ip:\t$ref->[3]\tRAM:\t$ref->[5] MB\n";
		print "private ip:\t$ref->[4]\tDisk:\t$ref->[6] GB\n";
		}
	&DBDisconnect();
	}
sub ListDistros {
	&DBConnect();
	my $list_distros = our $db->prepare("SELECT id,distro FROM distros WHERE id > 99 ORDER BY distro ASC;");
	$list_distros->execute();
	print sprintf("%-6.4s%6.6s\n", "id", "distro");
	while (my $list = $list_distros->fetchrow_arrayref) {
		print sprintf("%-6.4s%-29.29s\n", $list->[0], $list->[1]);
		}
	&DBDisconnect();
	}
sub ListBackupImages {
	&DBConnect();
	my $list_backups = our $db->prepare("SELECT backups.id,name,created_date,created_time, servers.hostname FROM servers,backups WHERE backups.server = servers.id ORDER BY name ASC,servers.hostname ASC, created_time ASC;");
	$list_backups->execute();
	print sprintf("%-9.9s%7.7s%11.10s%16.16s%32.32s\n", "id", "time", "date", "time", "hostname");
	while (my $list = $list_backups->fetchrow_arrayref) {
		print sprintf("%-9.9s%7.7s%11.10s%16.14s%32.32s\n", $list->[0], $list->[1], $list->[2], $list->[3], $list->[4]);
		}
	&DBDisconnect();
	}
sub ListFlavors {
	&DBConnect();
	my $list_flavors = our $db->prepare("SELECT id, flavor, ram, disk FROM flavors ORDER BY id ASC;");
	$list_flavors->execute();
	print "id\tram\t\tdisk\n";
	while (my $list = $list_flavors->fetchrow_arrayref) {
		print $list->[0], "\t", $list->[1],"\t", $list->[3], " GB\n";
		}
	&DBDisconnect();
	}

sub CreateServer {
	sub MakeServer {
		my ($create_server_hostname, $create_server_flavor, $create_server_distro);
		my $new_server = Net::RackSpace::CloudServers::Server->new(
			cloudservers	=> 	$cs,
			name		=> 	$create_server_hostname,
			flavorid	=>	$create_server_flavor,
			imageid		=>	$create_server_distro,
#			metadata	=>	[ {
#					key	 =>    'Zeppelin 0.5',
#					contents =>    'Created by Zeppelin - by k6b'} ],
			personality	=> 	[ { 
					path 	 =>    '/root/.ssh/authorized_keys', 
					contents =>    'c3NoLXJzYSBBQUFBQjNOemFDMXljMkVBQUFBREFRQUJBQUFCQVFEMGF4UHNKc1p1MHFHTWJ1cXpI
							OVYyNWZCODU5ZTYyNXdlNEtpSXdVR2kwN2tobk83bStEc3VHa3luYmlQNmhGUWNHYTRvUDdwaDIx
							VThvNkl1YTV3VlExbVlBRkRmTTJ2d2hjenRwTmkzdmdtMDhZK2dJUURFb0gwTnZvYmpKS3FXanRF
							c3RDR1FUUndLMUJySURrRjhqZzVQL05rRzZsUm8wVjZ5RFMyeDhQRDJjK1VHWmV0N0NpSmljL013
							ZDgxeVZUWFk2S0E4WFc4TjVKbmJ3TmFFWlJNWE50K1ZzQ0xyY2drenB3cnJOa1F2MFF0ODVjQ0Yy
							ZkVhRTFpNG5OMzJQRmhhZlRRRkhQR2xqZTE5T2xybDc2d3dmSmFWQ050b3dJM0ZzMTZwQ3UzQ1dM
							MjFuMmlPRnpGWG4rNjg5U2RqN0xJZW53VFVZNFg3RGdxMWEyWTMK' } ],
			);
		my $build = $new_server->create_server();
		my $root_password = $build->adminpass;
		my @build_server = $cs->get_server_detail();
		do {
			&ClearScreen();
			print "Building server id: ", $build->id, "\n\tHostname: ", $build->name, "\n";
			print "\tPublic IP: @{$build->public_address} root password: $root_password\n";
			print "\tStatus: ", $build->status // '?', " progress: ", $build->progress // '?', "%\n";
			my @build_server = $cs->get_server_detail();
			$build = ( grep { $_->name eq $create_server_hostname } @build_server )[0];
			sleep 1 if ( ( $build->status // '' ) ne 'ACTIVE' );
		} while ( ( $build->status // '' ) ne 'ACTIVE' );
		&DBConnect();
		my $create_server_distro_lookup = our $db->prepare("SELECT distro FROM distros WHERE id = '$create_server_distro'");
		my $create_server_flavor_lookup = $db->prepare("SELECT ram,disk FROM flavors WHERE id = '$create_server_flavor'");
		$create_server_distro_lookup->execute();
		$create_server_flavor_lookup->execute();
		while (my $distro_name = $create_server_distro_lookup->fetchrow_arrayref) {
			our $create_server_distro_name = $distro_name->[0];
			}
		while (my $flavor_info = $create_server_flavor_lookup->fetchrow_arrayref) {
			our $create_server_flavor_ram = $flavor_info->[0];
			our $create_server_flavor_disk = $flavor_info->[1];
			}
		my $add_new_server = $db->prepare("INSERT INTO servers (id, hostname, distro, public_ip, private_ip, flavor, status, sum) VALUES ('$build->id', '$build->name', '$create_server_distro' );");
		$add_new_server->execute();
		&DBDisconnect();
		&ClearScreen();
		my ($create_server_distro_name, $create_server_flavor_ram, $create_server_flavor_disk);
		print "New server created:\n\tHostname: ", $build->name, "\n";
		print "\tDistro: $create_server_distro_name\tID: ", $build->id, "\n";
		print "\troot pass: ", $root_password, "\n";
		print "\tRam: $create_server_flavor_ram MB\tPublic IP: @{$build->public_address}\n";
		print "\tDisk: $create_server_flavor_disk GB\tPrivate IP: @{$build->private_address}\n";
		}
	print "Choose a distro:\n\n";
	&ListDistros();
	my $create_server_distro;
	do {
		print "\nSelection #: ";
		chomp(our $create_server_distro = <>);	
	} while (!$create_server_distro);
	&ClearScreen();
	print "\nChoose the server's size\n\n";
	&ListFlavors();
	print "\nSelection #: ";
	chomp(our $create_server_flavor = <>);
	print "Hostname: ";
	chomp(our $create_server_hostname = <>);
	&ClearScreen();
	&MakeServer();
	}

sub DeleteServer {
	sub DoDeleteServer {
		&DBConnect();
		our $check_existing_servers = our $db->prepare("SELECT id FROM servers;");
		$check_existing_servers->execute();
		while (my $ref = $check_existing_servers->fetchrow_arrayref) {
			push(our @check_existing_servers, $ref->[0]);
			}
		&DBDisconnect();
		my @servers = $cs->get_server_detail;
		my $server_to_delete_id;
		my $delete_server = ( grep { $_->id == $server_to_delete_id } @servers )[0];
		if ( !defined $delete_server ) {
			print "\nNo server by that id.\n";
			sleep 1;
			&DeleteServer();
		} else { 
			print "\nDeleting server $server_to_delete_id\n";
			$delete_server->delete_server();
			&DBConnect();
			my $server_db_remove = $db->prepare("DELETE FROM servers WHERE id = '$server_to_delete_id'");
			$server_db_remove->execute();
			print "Server $server_to_delete_id deleted.\n";
			}
		sleep 1;
		&DeleteServer();
		}
	&ClearScreen();
	print "Select a server to delete(Q to go back):\n\n";
	&ListServers();
	print "\nEnter id: ";
	chomp(our $server_to_delete_id = <>);
	if ($server_to_delete_id =~ m/Q|q/) {
		&MainMenu();
		}
	&DBConnect();
	my $delete_server_lookup = our $db->prepare("SELECT hostname FROM servers WHERE id = '$server_to_delete_id'");
	$delete_server_lookup->execute();
	while (my $delete_server = $delete_server_lookup->fetchrow_arrayref) {
		chomp(our $server_to_delete_hostname = $delete_server->[0]);
		}
	&DBDisconnect();
	my $server_to_delete_hostname;
	print "\nDelete server id: $server_to_delete_id\thostname: $server_to_delete_hostname?\n\nWarning: This is irreversable and permanent!\n";
	print "\nDelete?[y/N]: ";
	chomp(my $confirmation = <>);
	if ($confirmation =~ m/Y|y/) {
		&DoDeleteServer();
	} else {
		print "\nAborting...\n";
		sleep 2;
		&DeleteServer();
		}
	}

sub Limits {
	my $api_limits = Net::RackSpace::CloudServers::Limits->new(
		cloudservers	=>	$cs,
		);
	$api_limits->refresh();
	foreach my $k ( @{ $api_limits->rate } ) {
		print $k->{verb}, ' to URI ', $k->{URI}, ' remaining: ',
		$k->{remaining}, ' per ', $k->{unit},
		' (will be reset at: ', scalar localtime $k->{resetTime}, ')',
		"\n";
		}
	print "\nTotal RAM:\t", $api_limits->totalramsize, " MB\n";
	print "\nTotal IP Grps:\t", $api_limits->maxipgroups, "\n";
	print "\nIP Grp Members:\t", $api_limits->maxipgroupmembers, "\n";
	print "\nRate:\t\t", @{$api_limits->rate}, "\n";
	my $api_limit_test = $api_limits->rate;
	print %{$api_limit_test->[0]} . "\n\n";
	while ( my ($key, $value) = each(%{$api_limit_test->[0]}) ) {
		print "$key => $value\n";
		}
	}

sub Wait {
	print "\nPress any key to continue...";
		chomp(my $key = <>);
	}

sub ClearScreen {
	print "\033[2J";
	print "\033[0;0H";
	}

sub MainMenu {
	&ClearScreen();
	print "Zeppelin - Cloud Control - by k6b\n";
	print "\n\t[1]\tCreate Server\n";
	print "\t[2]\tDelete Server\n";
	print "\t[3]\tList Servers\n";
	print "\t[4]\tList Distros\n";
	print "\t[5]\tList Backup Images\n";
	print "\t[6]\tList Flavors\n";
	print "\t[7]\tLimits\n";
	print "\t[8]\tUpdate Database\n";
	print "\t[0]\tQuit\n";
	print "\nSelection: ";
	chomp(my $choice = <>);
	print "\n";
	if ($choice =~ m/^1$/) {
		&ClearScreen();
		&CreateServer();
		&Wait();
		&MainMenu();
	} elsif ($choice =~ m/^2$/) {
		&ClearScreen();
		&DeleteServer();
		&Wait();
		&MainMenu();
	} elsif ($choice =~ m/^3$/) {
		&ClearScreen();
		&ListServers();
		#&GetServerDetail();
		&Wait();
		&MainMenu();
	} elsif ($choice =~ m/^4$/) { 
		&ClearScreen();
		&ListDistros();
		&Wait();
		&MainMenu();
	} elsif ($choice =~ m/^5$/) {
		&ClearScreen();
		&ListBackupImages();
		&Wait();
		&MainMenu();
	} elsif ($choice =~ m/^6$/) {
		&ClearScreen();
		&ListFlavors();
		&Wait();
		&MainMenu();
	} elsif ($choice =~ m/^7$/) {
		&ClearScreen();
		&Limits();
		&Wait();
		&MainMenu();
	} elsif ($choice =~ m/^8$/) {
		&UpdateDB();
		&Wait();
		&MainMenu();
	} elsif ($choice =~ m/^0$|^q$|^Q$/) {
		exit;
	} else {
		print "Try again\n";
		&MainMenu();
		}
	}

&AuthRequest();
&UpdateDB();
&MainMenu();
