#!/usr/bin/perl -w

use strict;
use warnings FATAL => 'all';
use Net::LDAPS;

use constant LDAP_SERVER => 'dc.server';
use constant LDAP_FILIAL_OU => 'OU=Filial,OU=Organisation,OU=Structure,DC=dc,DC=ru';
use constant LDAP_BASE_USERS => 'OU=Organisation,OU=Structure,DC=rgs,DC=ru';
use constant LDAP_BASE_GROUPS => "OU=Рассылка,OU=Groups,".LDAP_FILIAL_OU;
use constant LDAP_BASE_CONTACTS => "OU=addressbook,".LDAP_FILIAL_OU;
use constant LDAP_AUTH_USER => 'admin@dc.ru';
use constant LDAP_AUTH_PWD => '123456';
use constant LDAP_SCOPE => "subtree";
use constant LDAP_FILTER_USERS => "(&(objectCategory=person)(objectClass=user)(mail=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(displayName=*Scan*))(!(displayName=*Агенты*))(memberOf:1.2.840.113556.1.4.1941:=CN=Users,OU=Подразделения,OU=Groups,".LDAP_FILIAL_OU."))";
use constant LDAP_FILTER_GROUPS => "(&(objectcategory=group)(mail=*))";
my $ldap = Net::LDAPS->new(LDAP_SERVER) or die "$@";
my $rc = $ldap->bind(LDAP_AUTH_USER,password => LDAP_AUTH_PWD);
die $rc->error if $rc->code;

my $search_contacts = $ldap->search ( base => LDAP_BASE_CONTACTS, scope => 'one', filter => "(objectClass=contact)", attrs => ['cn'] );
die $search_contacts->error if $search_contacts->code;
foreach my $entry ($search_contacts->entries) {
	$rc = $ldap->delete($entry->dn);
}

my $search_users = $ldap->search ( base => LDAP_BASE_USERS, scope => LDAP_SCOPE, filter => LDAP_FILTER_USERS );
die $search_users->error if $search_users->code;

foreach my $entry ($search_users->entries) {
	my $cn = $entry->get_value('cn');
	my $sn = $entry->get_value('sn');
	my $title = $entry->get_value('title');	
	my $mail = lc($entry->get_value('mail'));
	my $company = $entry->get_value('company');
	my $initials = $entry->get_value('initials');
	my $givenName = $entry->get_value('givenName');
	my $department = $entry->get_value('department');
	my $thumbnailPhoto = $entry->get_value('thumbnailPhoto');
	my $otherTelephone = $entry->get_value('otherTelephone');
	my $telephoneNumber = $entry->get_value('telephoneNumber');

	$company =~ s@\"@\\\"@g;
	$cn =~ s@\(\w+\s\w+\)@@g;

	my $dn = "cn=${cn},".LDAP_BASE_CONTACTS;
	
	my @attrs = (
		sn => $sn,
		mail => $mail,
		title => $title,
		displayName => $cn,
		company => $company,
		initials => $initials,
		givenName => $givenName,
		objectclass => 'contact'
	);
		
	if($department){
		$department =~ s/^\s+//;
		$department =~ m@((.*?)(?=\sБлок))|((.*?)(?=\sУправ))|((.*?)(?=\sДир))|((.*?)(?=\sФили))|(.*)@;
		#m@(.*?г\.\s[А-ЯЁа-яё-]+)|(.*?г\.[А-ЯЁа-яё-]+)|(.*?п\.\s[А-ЯЁа-яё-]+)|(.*?п\.[А-ЯЁа-яё-]+)|(.*?с\.\s[А-ЯЁа-яё-]+)|(.*?с\.[А-ЯЁа-яё-]+)|(.*?с\s\.\s[А-ЯЁа-яё-]+)|(.*?с\s\.[А-ЯЁа-яё-]+)|(.*?пгт\.\s[А-ЯЁа-яё-]+)|(.*?пгт\.[А-ЯЁа-яё-]+)|((.*?)(?=\sБлок))|((\s.*?)(?=\s[А-ЯЁ]))|((.*?)(?=\s[А-ЯЁ]))|(.*)@;
		push(@attrs, 'department' , $&);
	}
	if($otherTelephone){
		push(@attrs, 'otherTelephone' , $otherTelephone);
	}
	if($telephoneNumber){
		push(@attrs, 'telephoneNumber' , $telephoneNumber);
	}
	if($thumbnailPhoto){
		push(@attrs, 'thumbnailPhoto' , $thumbnailPhoto);
	}
	
	my $result = LDAPmodifyUsingArray ( $ldap, $dn, \@attrs );
 
	sub LDAPmodifyUsingArray
	{
	  my ($ldap, $dn, $whatToChange ) = @_;
	  my $result = $ldap->add ( $dn, attrs => [ @$whatToChange ]);
	  print $result->error . "\n" if $rc->code;
	  return $result;
	}
}

my $search_groups = $ldap->search ( base => LDAP_BASE_GROUPS, scope => LDAP_SCOPE, filter => LDAP_FILTER_GROUPS);
die $search_groups->error if $search_groups->code;
foreach my $entry ($search_groups->entries) {
	my $cn = $entry->get_value('description');
	my $mail = $entry->get_value('mail');
	my ($givenName, $sn) = split(/\s-\s/,$cn);
	
	my $dn = "cn=${cn},".LDAP_BASE_CONTACTS;

	$rc = $ldap->add($dn, attrs => [
		sn => $sn,
		mail => $mail,
		displayName => $cn,
		givenName => $givenName,
		objectclass => 'contact',
	]);
}

$ldap->unbind;
exit;

__END__;