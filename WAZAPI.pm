package WAZAPI;

use strict;
use warnings;
use JSON::RPC::Client;
use Data::Dumper;
use base 'Exporter';

our @EXPORT = qw(wz_set_debug wz_unset_debug wz_login wz_create_macro wz_create_host wz_create_item wz_get_groupid wz_get_interfaceid wz_create_trigger);

my ($apiurl, $client, $authid, $debug);

$debug = 0;
use constant JSONRPC_VERSION => '2.0';
use constant WZ_DEBUG_OFF => 0;
use constant WZ_DEBUG_ON => 1;

sub wz_set_debug
{
    $debug = WZ_DEBUG_ON;
}

sub wz_unset_debug
{
    $debug = WZ_DEBUG_OFF;
}

sub wz_login
{
    my $url = shift;
    my $user = shift;
    my $password = shift;

    $apiurl = "$url/api_jsonrpc.php";
    $client = new JSON::RPC::Client;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
	'method' => 'user.login',
	'params' => {
	    'user' => $user,
	    'password' => $password
	},
	'id' => 1
    };

    $authid = __wz_exec_json($json);
}

sub wz_create_macro
{
    my $macro = shift;
    my $value = shift;
    my $hostid = shift;
    my $force = shift;

    my $id = undef;

    if ($id = __wz_get_macroid($macro, $hostid))
    {
	return $id unless ($force);

	# force update
	__wz_update_macro($id, $value, $hostid);

	return $id;
    }

    # create
    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
	'params' => {
	    'macro' => $macro,
	    'value' => $value
	},
	'id' => 1,
	'auth' => $authid
    };

    my $output;

    if ($hostid)
    {
	$output = 'hostmacroids';
	$json->{'method'} = 'usermacro.create';
	$json->{'params'}->{'hostid'} = $hostid;
    }
    else
    {
	$output = 'globalmacroids';
	$json->{'method'} = 'usermacro.createglobal';
    }

    my $response = __wz_exec_json($json);

    return $response->{$output}[0];
}

sub wz_create_host
{
    my $host = shift;
    my $groupid = shift;
    my $ip = shift;
    my $port = shift;
    my $force = shift;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
        'params' => {
	    'host' => $host,
	    'groups' => [
		{
		    'groupid' => $groupid
		}
		]
	},
	'id' => 1,
        'auth' => $authid
    };

    my $method;
    my $id = undef;

    if ($id = __wz_get_hostid($host))
    {
	return $id unless ($force);

	# force update
	$json->{'method'} = 'host.update';
	$json->{'params'}->{'hostid'} = $id;
    }
    else
    {
	# create
	$json->{'method'} = 'host.create';
	$json->{'params'}->{'interfaces'} = [
	    {
		'ip' => $ip,
		'port' => $port,
		'type' => 1,
		'main' => 1,
		'useip' => 1,
		'dns' => ''
	    }
	    ]
    }

    my $response = __wz_exec_json($json);

    return $response->{'hostids'}[0];
}

sub wz_create_item
{
    my $name = shift;
    my $key = shift;
    my $item_type = shift;
    my $value_type = shift;
    my $delay = shift;
    my $hostid = shift;
    my $interfaceid = shift;
    my $force = shift;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
	'params' => {
	    'name' => $name,
	    'key_' => $key,
	    'interfaceid' => $interfaceid,
	    'type' => $item_type,
	    'value_type' => $value_type,
	    'delay' => $delay
	},
	'id' => 1,
        'auth' => $authid
    };

    my $method;
    my $id = undef;

    if ($id = __wz_get_itemid($key, $hostid))
    {
	return $id unless ($force);

	# force update
	$json->{'method'} = 'item.update';
	$json->{'params'}->{'itemid'} = $id;
    }
    else
    {
	# create
	$json->{'method'} = 'item.create';
	$json->{'params'}->{'hostid'} = $hostid;
    }

    my $response = __wz_exec_json($json);

    return $response->{'itemids'}[0];
}

sub wz_get_groupid
{
    my $name = shift;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
        'method' => 'hostgroup.get',
        'params' => {
	    'output' => 'groupid',
	    'filter' => {
		'name' => [
		    $name
		    ]
	    }
	},
	'id' => 1,
        'auth' => $authid
    };

    my $response = __wz_exec_json($json);

    return $response->[0]->{'groupid'};
}

sub wz_get_interfaceid
{
    my $hostid = shift;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
        'method' => 'hostinterface.get',
        'params' => {
	    'output' => 'interfaceid',
	    'hostids' => $hostid
	},
	'id' => 1,
        'auth' => $authid
    };

    my $response = __wz_exec_json($json);

    return $response->[0]->{'interfaceid'};
}

sub wz_create_trigger
{
    my $name = shift;
    my $expression = shift;
    my $hostid = shift;
    my $force = shift;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
	'method' => 'trigger.create',
        'params' => {
	    'description' => $name,
	    'expression' => $expression
	},
	'id' => 1,
        'auth' => $authid
    };

    my $method;
    my $id = undef;

    if ($id = __wz_get_triggerid($name, $hostid))
    {
	return $id unless ($force);

        # force update
	$json->{'method'} = 'trigger.update';
	$json->{'params'}->{'triggerid'} = $id;
    }

    my $response = __wz_exec_json($json);

    return $response->{'triggerids'}[0];
}

sub __wz_update_macro
{
    my $id = shift;
    my $value = shift;
    my $hostid = shift;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
	'params' => {
	    'value' => $value
	},
	'id' => 1,
	'auth' => $authid
    };

    if ($hostid)
    {
	$json->{'method'} = 'usermacro.update';
	$json->{'params'}->{'hostmacroid'} = $id;
    }
    else
    {
	$json->{'method'} = 'usermacro.updateglobal';
	$json->{'params'}->{'globalmacroid'} = $id;
    }

    __wz_exec_json($json);
}

sub __wz_get_macroid
{
    my $macro = shift;
    my $hostid = shift;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
	'method' => 'usermacro.get',
	'params' => {
	    'filter' => {'macro' => $macro}
	},
	'id' => 1,
	'auth' => $authid
    };

    my $output;

    if ($hostid)
    {
	$output = 'hostmacroid';
	$json->{'params'}->{'hostids'} = $hostid;
    }
    else
    {
	$output = 'globalmacroid';
	$json->{'params'}->{'globalmacro'} = 1;
    }

    $json->{'params'}->{'output'} = $output;

    my $response = __wz_exec_json($json);

    return $response->[0]->{$output};
}

sub __wz_get_hostid
{
    my $host = shift;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
	'method' => 'host.get',
	'params' => {
	    'output' => 'hostid',
	    'filter' => {
		'host' => [
		    $host
		    ]
	    }
	},
	'id' => 1,
        'auth' => $authid
    };

    my $response = __wz_exec_json($json);

    return $response->[0]->{'hostid'};
}

sub __wz_get_itemid
{
    my $key = shift;
    my $hostid = shift;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
	'method' => 'item.get',
	'params' => {
	    'output' => 'itemid',
	    'hostids' => $hostid,
	    'search' => {
		'key_' => $key
	    }
	},
	'id' => 1,
        'auth' => $authid
    };

    my $response = __wz_exec_json($json);

    return $response->[0]->{'itemid'};
}

sub __wz_get_triggerid
{
    my $name = shift;
    my $hostid = shift;

    my $json = {
	'jsonrpc' => JSONRPC_VERSION,
	'method' => 'trigger.get',
	'params' => {
	    'output' => 'triggerid',
	    'filter' => {
		'description' => $name,
		'hostid' => $hostid
	    }
	},
	'id' => 1,
        'auth' => $authid
    };

    my $response = __wz_exec_json($json);

    return $response->[0]->{'triggerid'};
}

sub __wz_check_response
{
    my $method = shift;
    my $response = shift;

    die("$method failed: empty response received") unless ($response);

    unless ($response->content->{'result'})
    {
	my $message = $response->content->{'error'}->{'message'} || "";
	my $data = $response->content->{'error'}->{'data'} || "";

	die("$method failed: $message $data\n");
    }
}

sub __wz_exec_json
{
    my $json = shift;

    print("REQUEST: ", Dumper($json)) if ($debug == WZ_DEBUG_ON);

    my $response = $client->call($apiurl, $json);

    print("RESPONSE: ", Dumper($response)) if ($debug == WZ_DEBUG_ON);

    __wz_check_response($json->{'method'}, $response);

    return $response->content->{'result'};
}

1;
