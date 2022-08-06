#!/usr/bin/perl -w

use strict;
use Net::LDAPS;
use Net::SMTP;
use Net::POP3;
use Mail::Message;

use Encode qw(encode_utf8 encode decode);

my $mail_user = 'pay@company.ru';
my $mail_pwd = 'A>Rb8"-Z';

my $ldap_server='dc.server';
my $ldap_user='admin@dc.ru';
my $ldap_pwd='123456';
my $ldap_base='OU=Filial,OU=Organisation,OU=Structure,DC=dc,DC=ru';
my $ldap_scope = "subtree";

my $ldap = Net::LDAPS->new($ldap_server) or die "$@";
my $rc = $ldap->bind($ldap_user, password => $ldap_pwd);
	die $rc->error if $rc->code;

my $pop = Net::POP3->new('mail.company.ru', Timeout => 60);
my $smtp = Net::SMTP->new('mail.company.ru');

if ($pop->login($mail_user, $mail_pwd) > 0) {
  my $msgnums = $pop->list;
  foreach my $msgnum (keys %$msgnums) {
    my $msg = $pop->get($msgnum);
    my $msg_obj = Mail::Message->read($msg);
	my $contentType = $msg_obj->contentType;
	
	if ($contentType eq "text/plain"){
		$pop->delete($msgnum);
		next;
	}

	my $subject = $msg_obj->subject;
	my $from = $msg_obj->sender;
    my $body = $msg_obj->body;
	my $part = $body->part(0);
	
	my $decoded = $part->decoded;
	$decoded =~ qr/\D(5[\d]+?)-/is;
	my $skk = $1;
	$decoded =~ s/<\/p>/<\/span><br>/igm;
	$decoded =~ s/<p/<span/igm;
	
	$smtp->mail('pay@company.ru');
	
	my $ldap_filter = '(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(memberOf:1.2.840.113556.1.4.1941:=CN='.Encode::encode('cp1251', $skk).',OU=Pay,OU=Filial,OU=Organisation,OU=Structure,DC=dc,DC=ru))';
	my $search = $ldap->search ( base => $ldap_base, scope => $ldap_scope, filter => $ldap_filter);
		die $search->error if $search->code;
		
	foreach my $entry ($search->entries) {
		my $mail = $entry->get_value('mail');
		$smtp->to($mail);
	}
	$smtp->data();
	$smtp->datasend("Content-Type: text/html; charset=UTF-8\n");
	$smtp->datasend("From: pay\@company.ru\n");
	$smtp->datasend("Subject: ".$subject."\n\n");
	$smtp->datasend("<b>Это АВТОМАТИЧЕСКАЯ рассылка, НЕ отвечайте на нее!<\/b><br><br>".Encode::encode('utf8', $decoded."<br>".$from->format));
	$smtp->dataend();
		
    $pop->delete($msgnum);
  }
}
$ldap->unbind;
$smtp->quit;
$pop->quit;

exit;

__END__;