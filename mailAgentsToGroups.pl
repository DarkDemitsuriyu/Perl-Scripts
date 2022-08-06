#!/usr/bin/perl -w
#

use strict;
use Net::LDAPS;
use Net::SMTP;
use Encode qw(encode_utf8 encode decode);
require "D:\\Programs\\Scripts\\deps.pl";

my @deps = rgs_deps();
my $ldap_server='dc.server';
my $ldap_base='OU=Filial,OU=Organisation,OU=Structure,DC=dc,DC=ru';
my $ldap_user='admin@dc.ru';
my $ldap_pwd='123456';
my $ldap_scope = "subtree";
my $ldap_filter = "(&(objectCategory=person)(objectClass=user)(info=Агенты)(mail=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(memberOf:1.2.840.113556.1.4.1941:=CN=Agents,OU=Подразделения,OU=Groups,OU=Filial,OU=Organisation,OU=Structure,DC=dc,DC=ru)))";
my $mailMsg = "Возникли проблемы со следующими агентами:\n<ol>";
my $isGoMail = 0;

my $ldap = Net::LDAPS->new($ldap_server) or die "$@";
my $rc = $ldap->bind($ldap_user,password => $ldap_pwd) ;
	die $rc->error if $rc->code;

my $search = $ldap->search ( base => $ldap_base,scope => $ldap_scope,filter => $ldap_filter);
	die $search->error if $search->code;

local $SIG{__WARN__} = sub {
	$isGoMail = 1;
	my $agent = shift;
	$agent =~ m@((.*?)(?=\sat\s))@;
	$agent = $&;
	$mailMsg .= "<li>" . $agent . "</li>";
};

foreach my $entry ($search->entries) {
	my $dn=$entry->dn;
	my $department = $entry->get_value('department');
	
	unless($department){
		$department = "Не задано";
	}
	
	for (my $i = 0; $i <= $#deps; $i++) {		
		my $idxi = index($department, $deps[$i]->{"find"}, 0);		
		if($idxi > -1){
			$department = $deps[$i]->{"name"};
		}			
	}
	
	my $agent_group_dn = "CN=Агенты ${department},OU=Агенты,OU=Подразделения,OU=Groups,OU=Filial,OU=Organisation,OU=Structure,DC=dc,DC=ru";
	
	$rc = $ldap->modify($agent_group_dn, add => {member => $dn} );
	warn $dn . " (Подразделение - " . $department . ")" if $rc->code;
}

if($isGoMail >0){
	my $smtp = Net::SMTP->new('mail.company.ru');
	$smtp->mail('postmas@company.ru');
	if($smtp->to('it@company.ru')){
		$smtp->data();
		$smtp->datasend("Content-Type: text/html; charset=UTF-8\n");
		$smtp->datasend("From: postmas\@company.ru\n");
		$smtp->datasend("Subject: Проблемы с добалением агентов в группы\n\n");
		$smtp->datasend($mailMsg."\n");
		$smtp->dataend();
	} else {
		print "Error Mail: ", $smtp->message();
	}
	$smtp->quit;
}

$ldap->unbind;
exit;

__END__;