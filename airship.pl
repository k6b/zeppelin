#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use LWP::UserAgent;

our $identity = LWP::UserAgent->new;
$identity->agent("AirShip - Zeppelin/0.0.1 ");

# import zeppelin config file
our %settings = do "./.zeppelin.config";

# us api endpoint
our $api_url = "https://auth.api.rackspacecloud.com/v1.0";
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
#		print "auth_token:\t", $auth_token, "\n";
#		print "stor_token:\t", $storage_token, "\n";
#		print "server_url:\t", $server_url, "\n";
#		print "cdn_mg_url:\t", $cdn_url, "\n";
#		print "storag_url:\t", $storage_url, "\n";
#		print $res->decoded_content, "\n";
	} else {
		print "Error: " . $res->status_line . "\n";
		}
	return our $auth_token;
	return our $server_url;
	}

sub MakeRequest {
	my $method = $_[0];
	my $uri = $_[1];
#	print "method____:\t$method\n";
#	print "url_______:\t$uri\n";
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
#		print "x_purge_ke:\t", $x_purge_key, "\n";
#		print "cache_cont:\t", $cache_control, "\n";
#		print "x_varnish_:\t", $x_varnish, "\n";
#		print "age_______:\t", $age, "\n";
#		print "content:\t$content\n";
	} else {
		print "Error: " . $res->status_line . "\n";
		}
	return our $content;
	}

sub GetServers {
	our $server_url;
	my $json = new JSON;
	if (!$_[0]) {
		$_[0] = 0;
		}
	if ($_[0] == 1) {
		&MakeRequest("GET", "$server_url/servers/detail");
		my $server_list = our $content;
		my $json_list = $json->decode($server_list);
		foreach my $server ( @{$json_list->{servers}} ) {
			print $server->{id}, "\t", $server->{name}, "\t", @{$server->{addresses}->{public}}, "\t", @{$server->{addresses}->{private}}, "\t", $server->{flavorId}, "\t", $server->{imageId}, "\t", $server->{status}, "\t", $server->{progress}, "\t", $server->{hostId}, "\n";
			}
	} else {
		&MakeRequest("GET", "$server_url/servers/");
		my $server_list = our $content;
		my $json_list = $json->decode($server_list);
		foreach my $server ( @{$json_list->{servers}} ) {
			print $server->{id}, "\t", $server->{name}, "\n";
			}
		}
	}

sub GetImages {
	our $server_url;
	my $json = new JSON;
	&MakeRequest("GET", "$server_url/images/");
	my $image_list = our $content;
	my $json_list = $json->decode($image_list);
	foreach my $image ( @{$json_list->{images}} ) {
		if ($image->{id} < 300) {
			print $image->{id}, "\t", $image->{name}, "\n";
			}
		}
	}

sub GetBackups {
	our $server_url;
	my $json = new JSON;
	&MakeRequest("GET", "$server_url/images/detail");
	my $backup_list = our $content;
	my $json_list = $json->decode($backup_list);
	foreach my $backup ( @{$json_list->{images}} ) {
		if ($backup->{id} > 300) {
			print $backup->{id}, "\t", $backup->{name}, "\t", $backup->{status}, "\t", $backup->{created}, "\t", $backup->{updated}, "\t", $backup->{serverId}, "\t", $backup->{progress}, "\n";
			}
		}
	}

sub GetFlavors {
	our $server_url;
	my $json = new JSON;
	if (!$_[0]) {
		$_[0] = 0;
		}
	if ($_[0] == 1) {
		&MakeRequest("GET", "$server_url/flavors/detail");
		my $flavor_list = our $content;
		my $json_list = $json->decode($flavor_list);
		foreach my $flavor ( @{$json_list->{flavors}} ) {
			print $flavor->{id}, "\t", $flavor->{name}, "\t", $flavor->{ram}, "\t", $flavor->{disk}, "\n";
			}
	} else {
		&MakeRequest("GET", "$server_url/flavors/");
		my $flavor_list = our $content;
		my $json_list = $json->decode($flavor_list);
		foreach my $flavor ( @{$json_list->{flavors}} ) {
			print $flavor->{id}, "\t", $flavor->{name}, "\n";
			}
		}
	}

sub GetLoadBalancers {
	our $load_balancer_url;
	my $json = new JSON->allow_nonref;
	&MakeRequest("GET", $load_balancer_url); 
	my $loadbalancer_list = our $content;
	my $json_list = $json->decode($loadbalancer_list);
	foreach my $loadbalancer ( @{$json_list->{loadBalancers}} ) {
		print $loadbalancer->{id}, "\t", $loadbalancer->{name}, "\t", $loadbalancer->{protocol}, "\t", $loadbalancer->{port}, "\t", $loadbalancer->{algorithm}, "\t", $loadbalancer->{status}, "\t", $loadbalancer->{created}->{time}, "\t", $loadbalancer->{updated}->{time}, "\n";
		foreach my $virt_ip (@{$loadbalancer->{virtualIps}}) {
			print $virt_ip->{address}, "\t", $virt_ip->{type}, "\t", $virt_ip->{ipVersion}, "\t", $virt_ip->{id}, "\n";
			}
		}
	}



&AuthRequest();
#&GetServers(1);
#&GetImages();
&GetBackups();
#&GetFlavors(1);
#&GetLoadBalancers();

