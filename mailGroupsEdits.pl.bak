#!/usr/bin/perl -w
#

use strict;
use CLI;  #get one from www.communigate.com/CGPerl/
use Net::LDAPS;
use Net::SMTP;

my $ldap_server='dc.server';
my $ldap_base_groups='OU=Filial,OU=Organisation,OU=Structure,DC=dc,DC=ru';
my $ldap_base_users='OU=Organisation,OU=Structure,DC=dc,DC=ru';
my $ldap_user='ldap@dc.ru';
my $ldap_pwd='123456';
my $ldap_scope = "subtree";
my $ldap_filter = "(&(objectCategory=group)(info=True))";
my $mail_server = 'mail.company.ru';
my $mail_user = 'postmas@company.ru';
my $mail_pwd = '123456';

my $ldap = Net::LDAPS->new($ldap_server) or die "$@";
my $rc = $ldap->bind($ldap_user,password => $ldap_pwd) ;
	die $rc->error if $rc->code;
my $cli = new CGP::CLI({ PeerAddr => $mail_server,PeerPort => 106,login => $mail_user,password => $mail_pwd,SecureLogin => 0}) || die "*** Can't login to CGPro CLI: ".$CGP::ERR_STRING."\n";
my $search = $ldap->search ( base => $ldap_base_groups,scope => $ldap_scope,filter => $ldap_filter);
	die $search->error if $search->code;

foreach my $entry ($search->entries) {
	my $label=$entry->get_value('mail');
	my $realname = $entry->get_value('description');
	my @users;
	my $newfilter='(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(memberOf:1.2.840.113556.1.4.1941:='.$entry->dn.')(mail=*))';
	my $newsearch = $ldap->search ( base => $ldap_base_users,scope => $ldap_scope,filter => $newfilter);	
		die $newsearch->error if $newsearch->code;
	foreach my $newentry ($newsearch->entries) {
		push @users, $newentry->get_value('mail');
	}	
	if(my $Settings=$cli->GetGroup($label)){		
		@$Settings{'Members'}=\@users;	
		$cli->SetGroup($label,\%$Settings);
	} else {
		my %Settings=(RealName =>  $realname,Members =>  \@users,Expand => 'YES',);
		$cli->CreateGroup($label,\%Settings)
	}
}

my $smtp = Net::SMTP->new('mail.company.ru');
$smtp->mail('fax@company.ru');
$smtp->to('my@company.ru');
$smtp->data();
$smtp->datasend("From: postmas\@company.ru\nSubject: Test\n\nvse OK!\n");
$smtp->dataend();
$smtp->quit;

$ldap->unbind;
$cli->Logout();
exit;

__END__;