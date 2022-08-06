#!/usr/bin/perl -w

use strict;
use CLI;  #get one from www.communigate.com/CGPerl/
use Net::LDAPS;
use Net::SMTP;
use Time::Local;
use POSIX qw(strftime);
use LWP::UserAgent;
use HTTP::Request ();
use Encode qw(encode_utf8 encode decode);
use JSON::MaybeXS qw(encode_json);
require "D:\\Programs\\Scripts\\deps.pl";

my $ldap_server='dc.server';
my $ldap_base_filial='OU=Filial,OU=Organisation,OU=Structure,DC=dc,DC=ru';
my $ldap_base_block='OU=Block,OU=Filial,OU=Organisation,OU=Structure,DC=dc,DC=ru';
my $ldap_user='admin@dc.ru';
my $ldap_pwd='123456';
my $mail_server = 'mail.company.ru';
my $mail_user = 'postmas@company.ru';
my $mail_pwd = '123456';
my $mailMsg = "Созданы следующие аккаунты:\n<style>table{border:1px solid black; width:100%; padding:5px;} td,th{border:1px solid black; text-align:center;}</style><table><tr><th>ФИО</th><th>Адрес</th><th>Должность</th><th>Отдел</th></tr>";
my $isGoMail = 0;
#my @names = ('Homer', 'Marge', 'Bart', 'Lisa', 'Maggie');

my $ldap = Net::LDAPS->new($ldap_server) or die "$@";
my $rc = $ldap->bind($ldap_user,password => $ldap_pwd);
die $rc->error if $rc->code;
my $cli = new CGP::CLI({ PeerAddr => $mail_server,PeerPort => 106,login => $mail_user,password => $mail_pwd,SecureLogin => 0}) || die "*** Can't login to CGPro CLI: ".$CGP::ERR_STRING."\n";

create_user($ldap, $ldap_base_filial);
create_user($ldap, $ldap_base_block);

$mailMsg .= "</table>";

if($isGoMail >0){
    my $smtp = Net::SMTP->new('mail.company.ru');
    $smtp->mail('postmas@company.ru');
    if($smtp->to('it@company.ru')){
		$smtp->data();
		$smtp->datasend("Content-Type: text/html; charset=UTF-8\n");
		$smtp->datasend("From: postmas\@company.ru\n");
		$smtp->datasend("Subject: Созданы аккаунты\n\n");
		$smtp->datasend($mailMsg."\n");
		$smtp->dataend();
    } else {
		print "Error Mail: ", $smtp->message();
    }
    $smtp->quit;
}

$ldap->unbind;
$cli->Logout();
exit;

sub passgen {
    my $passLength = 8;
    my $module = $passLength % 4;
    my $length = ($passLength / 4)-1;
    my @charsSymbols = (',', '.', '?', '<', '>', '|', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '=', '-', '{', ']', '}', ']');
    my @charsNumbers = (0 .. 9);
    my @charsLittle = ('a' .. 'z');
    my @charsBig = ('A' .. 'Z');
    my $rndSymbols = join("", @charsSymbols[ map { rand @charsSymbols } (0 .. $length) ]);
    my $rndNumbers = join("", @charsNumbers[ map { rand @charsNumbers } (0 .. $length) ]);
    my $rndLittle = join("", @charsLittle[ map { rand @charsLittle } (0 .. $length+$module) ]);
    my $rndBig = join("", @charsBig[ map { rand @charsBig } (0 .. $length) ]);
    my @chars = split("",join("",$rndSymbols,$rndNumbers,$rndLittle,$rndBig));
    for(0..$#chars) {
		my $j = rand(@chars);
		@chars[$_,$j] = @chars[$j,$_];
    }
    return join("", @chars);
}

sub create_user {
	my @deps = rgs_deps();
	my ($ldap, $ldap_base) = @_;
	my $date = strftime "%Y%m%d180000.0Z", localtime(time-864002);
	my $ldap_scope = "subtree";
	my $ldap_filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(info=Агенты))(title=*)(!(title=Водитель))(!(title=консультант))(!(mail=*\@company.ru))(|(employeeType=1)(employeeType=6)(employeeType=10))(whenCreated>=${date}))";
	
	my $search = $ldap->search ( base => $ldap_base,scope => $ldap_scope,filter => $ldap_filter);
	die $search->error if $search->code;
	
	foreach my $entry ($search->entries) {
		$isGoMail = 1;
		
		my $fullname = $entry->get_value('cn');
		my $title = $entry->get_value('title');
		my $company = $entry->get_value('company');		
		my $department = $entry->get_value('department');
		my $account = lc($entry->get_value('sAMAccountName'));
		my $pass = passgen();
		$department =~ m@((.*?)(?=\sБлок))|((.*?)(?=\sУправ))|((.*?)(?=\sДир))|((.*?)(?=\sФили))|(.*)@;
		$department = $&;
		$company =~ s@\"@\\\"@g;
		$fullname =~ s@\(\w+\s\w+\)@@g;
				
		for (my $i = 0; $i <= $#deps; $i++) {
			my $idxi = index($department, $deps[$i]->{"find"}, 0);
			if($idxi > -1){
				$department = $deps[$i]->{"name"};
			}		
		}
		
		my $UserData = {RealName => $fullname, o => $company, ou => $department, Password => $pass};
		
#		print "account - ", Encode::encode('cp866', Encode::decode('utf8', $account)), "\n";
#		print "fullname - ", Encode::encode('cp866', Encode::decode('utf8', $fullname)), "\n";
#		print "company - ", Encode::encode('cp866', Encode::decode('utf8', $company)), "\n";
#		print "department - ", Encode::encode('cp866', Encode::decode('utf8', $department)), "\n";
#		print "pass - ", Encode::encode('cp866', Encode::decode('utf8', $pass)), "\n";
		
		$cli->CreateAccount(accountName => $account, settings => $UserData) || die "Can't create account: ".$CGP::ERR_STRING."\n";;

		my $result = $ldap->modify($entry->dn, 
			replace => {
				mail => "${account}\@company.ru"
			}
		);
		die $result->error if $result->code;
		my $fn = Encode::encode('cp1251', Encode::decode('utf8', $fullname));
		my $tl = Encode::encode('cp1251', Encode::decode('utf8', $title));
		my $dp = Encode::encode('cp1251', Encode::decode('utf8', $department));
		
		my $cmd = 'KeePass2\\KPScript.exe -c:AddEntry PassBase.kdbx -keyfile:PassBase.key -Title:"' . $fn . '" -UserName:"' . $account . '@company.ru" -Password:"' . $pass . '" -GroupName:"' . $dp . '" -setx-Icon:19 -Notes:"' . $dp . '"';
		my $qwe = system($cmd);
		
		$mailMsg .= "<tr><td>" . $fullname . "</td><td>" . $account . "\@company.ru</td><td>" . $title . "</td><td>" . $department . "</td></tr>";
	}
}

__END__;