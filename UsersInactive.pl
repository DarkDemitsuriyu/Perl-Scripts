#!/usr/bin/perl -w

use strict;
use warnings FATAL => 'all';
use Net::LDAPS;
use Encode qw(encode_utf8 encode decode);

use constant LDAP_SERVER => 'dc.server';
use constant LDAP_FILIAL_OU => 'OU=Filial,OU=Organisation,OU=Structure,DC=dc,DC=ru';
use constant LDAP_BASE_INACTIVE => "OU=Inactive,".LDAP_FILIAL_OU;
use constant LDAP_AUTH_USER => 'admin@dc.ru';
use constant LDAP_AUTH_PWD => '123456';
use constant LDAP_SCOPE => "subtree";
use constant LDAP_FILTER => "(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=2)(!(memberOf:1.2.840.113556.1.4.1941:=CN=Inactive,OU=Разное,OU=Groups,".LDAP_FILIAL_OU.")))";
my $ldap = Net::LDAPS->new(LDAP_SERVER) or die "$@";
my $rc = $ldap->bind(LDAP_AUTH_USER, password => LDAP_AUTH_PWD);
die $rc->error if $rc->code;

my $search_users = $ldap->search ( base => LDAP_FILIAL_OU, scope => LDAP_SCOPE, filter => LDAP_FILTER );
die $search_users->error if $search_users->code;

foreach my $entry ($search_users->entries) {
	
	my $dn=$entry->dn;
	my $dn_group = "CN=Inactive,OU=Разное,OU=Groups,".LDAP_FILIAL_OU;
	my $dn_ou = "OU=Inactive,".LDAP_FILIAL_OU;

	$rc = $ldap->modify($dn_group, add => {member => $dn} );
	$rc = $ldap->modrdn($dn,
		newrdn => 'CN=' . $entry->get_value('cn'),
		newsuperior => $dn_ou,
		deleteoldrdn => 1
	);
}

$ldap->unbind;
exit;

__END__;